//!
//! Address scanner implementation, responsible for
//! aggregating UTXOs from multiple addresses and
//! building corresponding balances.
//!

use crate::derivation::AddressManager;
use crate::imports::*;
use crate::utxo::balance::AtomicBalance;
use crate::utxo::{UtxoContext, UtxoEntryReference, UtxoEntryReferenceExtension};
use std::cmp::max;

pub const DEFAULT_WINDOW_SIZE: usize = 8;

#[derive(Default, Clone, Copy)]
pub enum ScanExtent {
    /// Scan until an empty range is found
    #[default]
    EmptyWindow,
    /// Scan until a specific depth (a particular derivation index)
    Depth(u32),
}

enum Provider {
    AddressManager(Arc<AddressManager>),
    AddressSet(HashSet<Address>),
}

fn filter_scan_window_utxos<T>(
    entries: Vec<T>,
    local_address_to_index_map: &HashMap<Address, u32>,
    last_address_index: &mut u32,
    first: u32,
    last: u32,
) -> Vec<UtxoEntryReference>
where
    T: Into<UtxoEntryReference>,
{
    let mut refs = Vec::with_capacity(entries.len());
    for entry in entries {
        let utxo_ref: UtxoEntryReference = entry.into();
        let Some(address) = utxo_ref.utxo.address.as_ref() else {
            log_warn!(
                "scan_with_address_manager(): rpc returned UTXO without address for derivation window {}..{} (outpoint={:?})",
                first,
                last,
                utxo_ref.utxo.outpoint
            );
            continue;
        };

        let Some(utxo_address_index) = local_address_to_index_map.get(address) else {
            log_warn!(
                "scan_with_address_manager(): rpc returned UTXO for unknown address `{}` (outpoint={:?})",
                address,
                utxo_ref.utxo.outpoint
            );
            continue;
        };

        if *last_address_index < *utxo_address_index {
            *last_address_index = *utxo_address_index;
        }
        refs.push(utxo_ref);
    }
    refs
}

pub struct Scan {
    provider: Provider,
    window_size: Option<usize>,
    extent: Option<ScanExtent>,
    balance: Arc<AtomicBalance>,
    current_daa_score: u64,
}

impl Scan {
    pub fn new_with_address_manager(
        address_manager: Arc<AddressManager>,
        balance: &Arc<AtomicBalance>,
        current_daa_score: u64,
        window_size: Option<usize>,
        extent: Option<ScanExtent>,
    ) -> Scan {
        Scan { provider: Provider::AddressManager(address_manager), window_size, extent, balance: balance.clone(), current_daa_score }
    }
    pub fn new_with_address_set(addresses: HashSet<Address>, balance: &Arc<AtomicBalance>, current_daa_score: u64) -> Scan {
        Scan {
            provider: Provider::AddressSet(addresses),
            window_size: None,
            extent: None,
            balance: balance.clone(),
            current_daa_score,
        }
    }

    pub async fn scan(&self, utxo_context: &UtxoContext) -> Result<()> {
        // block notifications while scanning...
        let _lock = utxo_context.processor().notification_lock().await;

        match &self.provider {
            Provider::AddressManager(address_manager) => self.scan_with_address_manager(address_manager, utxo_context).await,
            Provider::AddressSet(addresses) => self.scan_with_address_set(addresses, utxo_context).await,
        }
    }

    pub async fn scan_with_address_manager(&self, address_manager: &Arc<AddressManager>, utxo_context: &UtxoContext) -> Result<()> {
        let window_size = self.window_size.unwrap_or(DEFAULT_WINDOW_SIZE) as u32;
        let extent = self.extent.ok_or_else(|| Error::Custom("scan_with_address_manager requires an extent".to_string()))?;

        let params = utxo_context.processor().network_params()?;

        let mut cursor: u32 = 0;
        let mut last_address_index = address_manager.index();

        'scan: loop {
            // scan first up to address index, then in window chunks
            let first = cursor;
            let last = if cursor == 0 { max(last_address_index + 1, window_size) } else { cursor + window_size };
            cursor = last;

            // generate address derivations
            let addresses = address_manager.get_range(first..last)?;
            let mut local_address_to_index_map = HashMap::with_capacity(addresses.len());
            for (offset, address) in addresses.iter().enumerate() {
                local_address_to_index_map.insert(address.clone(), first + offset as u32);
            }
            // register address in the utxo context; NOTE:  during the scan,
            // before `get_utxos_by_addresses()` is complete we may receive
            // new transactions  as such utxo context should be aware of the
            // addresses used before we start interacting with them.
            utxo_context.register_addresses(&addresses).await?;

            let ts = Instant::now();
            let resp = utxo_context.processor().rpc_api().get_utxos_by_addresses(addresses).await?;
            let elapsed_sec = ts.elapsed().as_secs_f32();
            if elapsed_sec > 1.0 {
                log_warn!("get_utxos_by_address() fetched {} entries in: {} msec", resp.len(), elapsed_sec);
            }
            yield_executor().await;

            let refs = filter_scan_window_utxos(resp, &local_address_to_index_map, &mut last_address_index, first, last);

            if !refs.is_empty() {
                let balance: Balance = refs.iter().fold(Balance::default(), |mut balance, r| {
                    let entry_balance = r.balance(params, self.current_daa_score);
                    balance.mature += entry_balance.mature;
                    balance.pending += entry_balance.pending;
                    balance.mature_utxo_count += entry_balance.mature_utxo_count;
                    balance.pending_utxo_count += entry_balance.pending_utxo_count;
                    balance.stasis_utxo_count += entry_balance.stasis_utxo_count;
                    balance
                });

                utxo_context.extend_from_scan(refs, self.current_daa_score).await?;

                self.balance.add(balance);
            } else {
                match &extent {
                    ScanExtent::EmptyWindow => {
                        if cursor > last_address_index + window_size {
                            break 'scan;
                        }
                    }
                    ScanExtent::Depth(depth) => {
                        if &cursor > depth {
                            break 'scan;
                        }
                    }
                }
            }
            yield_executor().await;
        }

        // update address manager with the last used index
        address_manager.set_index(last_address_index)?;

        Ok(())
    }

    pub async fn scan_with_address_set(&self, address_set: &HashSet<Address>, utxo_context: &UtxoContext) -> Result<()> {
        let params = utxo_context.processor().network_params()?;
        let address_vec = address_set.iter().cloned().collect::<Vec<_>>();

        utxo_context.register_addresses(&address_vec).await?;
        let resp = utxo_context.processor().rpc_api().get_utxos_by_addresses(address_vec).await?;
        let refs: Vec<UtxoEntryReference> = resp.into_iter().map(UtxoEntryReference::from).collect();

        let balance: Balance = refs.iter().fold(Balance::default(), |mut balance, r| {
            let entry_balance = r.balance(params, self.current_daa_score);
            balance.mature += entry_balance.mature;
            balance.pending += entry_balance.pending;
            balance.mature_utxo_count += entry_balance.mature_utxo_count;
            balance.pending_utxo_count += entry_balance.pending_utxo_count;
            balance.stasis_utxo_count += entry_balance.stasis_utxo_count;
            balance
        });
        yield_executor().await;

        utxo_context.extend_from_scan(refs, self.current_daa_score).await?;

        if !balance.is_empty() {
            self.balance.add(balance);
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::utxo::UtxoContextBinding;
    use kaspa_addresses::Version;
    use kaspa_rpc_core::{RpcTransactionOutpoint, RpcUtxoEntry, RpcUtxosByAddressesEntry};
    use std::sync::Arc;

    #[test]
    fn filter_scan_window_utxos_skips_unknown_addresses_instead_of_panicking() {
        let known_0 = Address::new(Prefix::Testnet, Version::PubKey, &[1u8; 32]);
        let known_1 = Address::new(Prefix::Testnet, Version::PubKey, &[2u8; 32]);
        let unknown = Address::new(Prefix::Testnet, Version::PubKey, &[3u8; 32]);

        let mut local_address_to_index_map = HashMap::new();
        local_address_to_index_map.insert(known_0.clone(), 10);
        local_address_to_index_map.insert(known_1.clone(), 12);

        let spk = ScriptPublicKey::from_vec(0u16, vec![]);
        let mk_entry = |address: Option<Address>, txid_byte: u8, index: u32| RpcUtxosByAddressesEntry {
            address,
            outpoint: RpcTransactionOutpoint { transaction_id: TransactionId::from_bytes([txid_byte; 32]), index },
            utxo_entry: RpcUtxoEntry::new(100, spk.clone(), 0, false),
        };

        let mut last_index = 0;
        let refs = filter_scan_window_utxos(
            vec![
                mk_entry(Some(known_0.clone()), 1, 0),
                mk_entry(Some(unknown), 2, 0),
                mk_entry(None, 3, 0),
                mk_entry(Some(known_1.clone()), 4, 0),
            ],
            &local_address_to_index_map,
            &mut last_index,
            10,
            13,
        );

        assert_eq!(refs.len(), 2);
        assert_eq!(last_index, 12);
        let addresses: Vec<Address> = refs.iter().filter_map(|r| r.utxo.address.clone()).collect();
        assert!(addresses.contains(&known_0));
        assert!(addresses.contains(&known_1));
    }

    #[tokio::test]
    async fn scan_with_address_manager_returns_error_when_extent_missing() -> Result<()> {
        let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);

        // Minimal wallet + derivation manager to obtain an AddressManager instance.
        let store = crate::wallet::Wallet::resident_store()?;
        let wallet = Arc::new(crate::wallet::Wallet::try_with_rpc(None, store, Some(network_id))?);
        let derivation = crate::derivation::AddressDerivationManager::create_legacy_pubkey_managers(
            &wallet,
            0,
            crate::derivation::AddressDerivationMeta::new(0, 0),
        )?;
        let address_manager = derivation.receive_address_manager();

        // Minimal UTXO context (RPC is mocked, but we should fail before any RPC call anyway).
        let rpc_api_mock = Arc::new(crate::tests::RpcCoreMock::new());
        let processor = UtxoProcessor::new(Some(rpc_api_mock.into()), Some(network_id), None, None);
        let utxo_context = UtxoContext::new(&processor, UtxoContextBinding::default());

        let balance = Arc::new(AtomicBalance::default());
        let scan = Scan::new_with_address_manager(address_manager.clone(), &balance, 0, None, None);

        let err = scan.scan_with_address_manager(&address_manager, &utxo_context).await.expect_err("must error without extent");
        assert!(err.to_string().contains("requires an extent"));

        Ok(())
    }
}
