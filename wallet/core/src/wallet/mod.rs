//!
//! # Kaspa wallet runtime implementation.
//!
//! This module contains a Rust implementation of the Kaspa wallet that
//! can be used in native Rust as well as WASM32 (Browser, NodeJs, Bun)
//! environments.
//!
//! This wallet is not meant to be used directly, but rather through the
//! use of the [`WalletApi`] trait.
//!

pub mod api;
pub mod args;
pub mod maps;
pub use args::*;

use crate::account::delegation::{delegation_message_hash, DelegationId, DelegationRecordV1, DelegationStatus};
use crate::account::delegation_watch::DelegationExpiryWatcher;
use crate::account::variants::mldsa_master::{MasterStatus, MldsaMasterAccount, MldsaMasterAccountPayloadV1};
use crate::account::{Account, AccountKind, ScanNotifier};
use crate::api::message::{
    MasterAnchorInfo, MasterDelegationApplyResponse, MasterDelegationBuildRequest, MasterDelegationBuildResponse,
    MasterDelegationSignResponse,
};
use crate::api::traits::WalletApi;
use crate::compat::gen1::decrypt_mnemonic;
use crate::encryption::{encrypt_xchacha20poly1305, Decrypted};
use crate::error::Error::{self, Custom};
use crate::factory::try_load_account;
use crate::imports::*;
use crate::message::{
    calc_request_id, hash_delegation_header, DelegationRecordHeaderV1, MasterDelegationRequestBodyV1, MasterDelegationResponseBodyV1,
};
use crate::settings::{SettingsStore, WalletSettings};
use crate::storage::interface::{OpenArgs, StorageDescriptor};
use crate::storage::keydata::MlDsaMasterPayload;
use crate::storage::local::interface::LocalStore;
use crate::storage::local::Storage;
use crate::storage::{self, AccountStorage, PrvKeyDataId, PrvKeyDataInfo};
use crate::wallet::keydata::PrvKeyDataVariantKind;
use crate::wallet::maps::ActiveAccountMap;
use futures::TryStreamExt;
use kaspa_bip32::{ExtendedKey, Language, Mnemonic, Prefix as KeyPrefix, WordCount};
use kaspa_mldsa::{MasterSeed, MlDsaLevel};
use kaspa_notify::{
    listener::ListenerId,
    scope::{Scope, VirtualDaaScoreChangedScope},
};
use kaspa_utils::hex::{FromHex, ToHex};
use kaspa_wallet_keys::keypair_mldsa::{MasterAnchor, MlDsaKeypair};
use kaspa_wallet_keys::xpub::NetworkTaggedXpub;
use kaspa_wrpc_client::{KaspaRpcClient, Resolver, WrpcEncoding};
use std::collections::HashSet;
use std::path::PathBuf;
use workflow_core::task::spawn;
use workflow_store::fs;
use zeroize::Zeroizing;

pub type WalletGuard<'l> = AsyncMutexGuard<'l, ()>;

#[derive(Debug)]
pub struct EncryptedMnemonic<T: AsRef<[u8]>> {
    pub cipher: T, // raw
    pub salt: T,   // raw
}

#[derive(Debug)]
pub struct SingleWalletFileV0<'a, T: AsRef<[u8]>> {
    pub num_threads: u32,
    pub encrypted_mnemonic: EncryptedMnemonic<T>,
    pub xpublic_key: &'a str,
    pub ecdsa: bool,
}

#[derive(Debug)]
pub struct SingleWalletFileV1<'a, T: AsRef<[u8]>> {
    pub encrypted_mnemonic: EncryptedMnemonic<T>,
    pub xpublic_key: &'a str,
    pub ecdsa: bool,
}

impl<T: AsRef<[u8]>> SingleWalletFileV1<'_, T> {
    const NUM_THREADS: u32 = 8;
}

#[derive(Debug)]
pub struct MultisigWalletFileV0<'a, T: AsRef<[u8]>> {
    pub num_threads: u32,
    pub encrypted_mnemonics: Vec<EncryptedMnemonic<T>>,
    pub xpublic_keys: Vec<&'a str>, // includes pub keys from encrypted
    pub required_signatures: u16,
    pub cosigner_index: u8,
    pub ecdsa: bool,
}

#[derive(Debug)]
pub struct MultisigWalletFileV1<'a, T: AsRef<[u8]>> {
    pub encrypted_mnemonics: Vec<EncryptedMnemonic<T>>,
    pub xpublic_keys: Vec<&'a str>, // includes pub keys from encrypted
    pub required_signatures: u16,
    pub cosigner_index: u8,
    pub ecdsa: bool,
}

impl<T: AsRef<[u8]>> MultisigWalletFileV1<'_, T> {
    const NUM_THREADS: u32 = 8;
}

#[derive(Clone)]
pub enum WalletBusMessage {
    Discovery { record: TransactionRecord },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MasterAccountInfo {
    pub account_id: AccountId,
    pub anchor: [u8; 32],
    pub level: u8,
    pub status: MasterStatus,
}

/// Internal wallet state.
struct Inner {
    active_accounts: ActiveAccountMap,
    legacy_accounts: ActiveAccountMap,
    listener_id: Mutex<Option<ListenerId>>,
    task_ctl: DuplexChannel,
    selected_account: Mutex<Option<Arc<dyn Account>>>,
    store: Arc<dyn Interface>,
    settings: SettingsStore<WalletSettings>,
    utxo_processor: Arc<UtxoProcessor>,
    multiplexer: Multiplexer<Box<Events>>,
    wallet_bus: Channel<WalletBusMessage>,
    estimation_abortables: Mutex<HashMap<AccountId, Abortable>>,
    retained_contexts: Mutex<HashMap<String, Arc<Vec<u8>>>>,
    delegations: Arc<DelegationStore>,
    delegation_watcher: Mutex<Option<Arc<DelegationExpiryWatcher>>>,
    // Mutex used to protect concurrent access to accounts at the wallet api level
    guard: Arc<AsyncMutex<()>>,
    account_guard: Arc<AsyncMutex<()>>,
}

///
/// `Wallet` represents a single wallet instance.
/// It is the main data structure responsible for
/// managing a runtime wallet.
///
/// @category Wallet API
///
#[derive(Clone)]
pub struct Wallet {
    inner: Arc<Inner>,
}

impl Default for Wallet {
    fn default() -> Self {
        let storage = Wallet::local_store().expect("Unable to initialize local storage");
        Wallet::try_new(storage, None, None).unwrap()
    }
}

impl Wallet {
    pub fn local_store() -> Result<Arc<dyn Interface>> {
        Ok(Arc::new(LocalStore::try_new(false)?))
    }

    pub fn resident_store() -> Result<Arc<dyn Interface>> {
        Ok(Arc::new(LocalStore::try_new(true)?))
    }

    pub fn try_new(storage: Arc<dyn Interface>, resolver: Option<Resolver>, network_id: Option<NetworkId>) -> Result<Wallet> {
        Wallet::try_with_wrpc(storage, resolver, network_id)
    }

    pub fn try_with_wrpc(store: Arc<dyn Interface>, resolver: Option<Resolver>, network_id: Option<NetworkId>) -> Result<Wallet> {
        let rpc_client =
            Arc::new(KaspaRpcClient::new_with_args(WrpcEncoding::Borsh, Some("wrpc://127.0.0.1:17110"), resolver, network_id, None)?);

        let rpc_ctl = rpc_client.ctl().clone();
        let rpc_api: Arc<DynRpcApi> = rpc_client;
        let rpc = Rpc::new(rpc_api, rpc_ctl);
        Self::try_with_rpc(Some(rpc), store, network_id)
    }

    pub fn try_with_rpc(rpc: Option<Rpc>, store: Arc<dyn Interface>, network_id: Option<NetworkId>) -> Result<Wallet> {
        let multiplexer = Multiplexer::<Box<Events>>::new();
        let wallet_bus = Channel::unbounded();
        let utxo_processor =
            Arc::new(UtxoProcessor::new(rpc.clone(), network_id, Some(multiplexer.clone()), Some(wallet_bus.clone())));

        let wallet = Wallet {
            inner: Arc::new(Inner {
                multiplexer,
                store,
                active_accounts: ActiveAccountMap::default(),
                legacy_accounts: ActiveAccountMap::default(),
                listener_id: Mutex::new(None),
                task_ctl: DuplexChannel::oneshot(),
                selected_account: Mutex::new(None),
                settings: SettingsStore::new_with_storage(Storage::default_settings_store()),
                utxo_processor: utxo_processor.clone(),
                wallet_bus,
                estimation_abortables: Mutex::new(HashMap::new()),
                retained_contexts: Mutex::new(HashMap::new()),
                delegations: Arc::new(DelegationStore::new()),
                delegation_watcher: Mutex::new(None),
                guard: Arc::new(AsyncMutex::new(())),
                account_guard: Arc::new(AsyncMutex::new(())),
            }),
        };

        Ok(wallet)
    }

    pub fn to_arc(self) -> Arc<Self> {
        Arc::new(self)
    }

    /// Helper fn for creating the wallet using a builder pattern.
    pub fn with_network_id(self, network_id: NetworkId) -> Self {
        let _ = self.set_network_id(&network_id);
        self
    }

    pub fn with_resolver(self, resolver: Resolver) -> Self {
        if let Some(wrpc_client) = self.try_wrpc_client() {
            let _ = wrpc_client.set_resolver(resolver);
        }
        self
    }

    pub fn with_url(self, url: Option<&str>) -> Self {
        if let Some(wrpc_client) = self.try_wrpc_client() {
            let _ = wrpc_client.set_url(url);
        }
        self
    }

    //
    // Mutex used to protect concurrent access to accounts
    // at the wallet api level. This is a global lock that
    // is required by various wallet operations.
    //
    // Due to the fact that Rust Wallet API is async, it is
    // possible for clients to concurrently execute API calls
    // that can "trip over each-other", causing incorrect
    // account states.
    //
    pub fn guard(&self) -> Arc<AsyncMutex<()>> {
        self.inner.guard.clone()
    }

    pub fn is_resident(&self) -> Result<bool> {
        Ok(self.store().location()? == StorageDescriptor::Resident)
    }

    pub fn utxo_processor(&self) -> &Arc<UtxoProcessor> {
        &self.inner.utxo_processor
    }

    pub fn descriptor(&self) -> Option<WalletDescriptor> {
        self.store().descriptor()
    }

    pub fn store(&self) -> &Arc<dyn Interface> {
        &self.inner.store
    }

    pub fn delegation_store(&self) -> &Arc<DelegationStore> {
        &self.inner.delegations
    }

    pub async fn build_master_delegation_request(
        self: &Arc<Self>,
        _wallet_secret: &Secret,
        request: MasterDelegationBuildRequest,
    ) -> Result<MasterDelegationBuildResponse> {
        let MasterDelegationBuildRequest { master_anchor, master_level, network_id, targets, created_at_unixtime, .. } = request;

        if targets.is_empty() {
            return Err(Error::MasterDelegationEmptyTargets);
        }

        let wallet_network = self.network_id()?;
        let resolved_network = match network_id {
            Some(id) if id != wallet_network => {
                return Err(Error::MasterDelegationNetworkMismatch { expected: wallet_network, actual: id });
            }
            Some(id) => id,
            None => wallet_network,
        };

        let mut current_daa = self.current_daa_score();
        if current_daa.is_none() {
            if let Ok(info) = self.rpc_api().get_server_info().await {
                current_daa = Some(info.virtual_daa_score);
            }
        }
        let current_daa = current_daa.ok_or(Error::MissingDaaScore("build_master_delegation_request"))?;

        let guard_handle = self.guard();
        let guard = guard_handle.lock().await;
        let anchors = self.list_master_accounts().await?;
        let anchor_bytes = if let Some(hex) = master_anchor {
            if hex.len() != 64 {
                return Err(Error::Custom("anchor must be 32 bytes".to_string()));
            }
            let bytes = Vec::from_hex(&hex).map_err(|e| Error::Custom(format!("invalid anchor hex: {e}")))?;
            let anchor: [u8; 32] = bytes.try_into().map_err(|_| Error::Custom("anchor must be 32 bytes".to_string()))?;
            anchor
        } else if let Some(info) = anchors.first() {
            info.anchor
        } else {
            return Err(Error::Custom("no master anchors in wallet".to_string()));
        };

        let master_info = anchors
            .into_iter()
            .find(|info| info.anchor == anchor_bytes)
            .ok_or_else(|| Error::Custom("master anchor not found".to_string()))?;
        let level = master_level.unwrap_or(master_info.level);

        let delegation_store = self.delegation_store().clone();
        let mut delegations = Vec::with_capacity(targets.len());
        for target in targets {
            let account =
                self.get_account_by_id(&target.account_id, &guard).await?.ok_or(Error::AccountNotFound(target.account_id))?;
            let stealth_account = account
                .clone()
                .as_stealth_account()
                .map_err(|_| Error::Custom("delegation targets must be stealth accounts".to_string()))?;
            let Some(linked_anchor) = stealth_account.master_anchor() else {
                return Err(Error::Custom("stealth account is not attached to a master anchor".to_string()));
            };
            if linked_anchor != anchor_bytes {
                return Err(Error::Custom(format!("stealth account {} is linked to a different master anchor", target.account_id)));
            }

            let mut header = DelegationRecordHeaderV1 {
                version: 1,
                level,
                anchor: anchor_bytes,
                account_id: target.account_id,
                spend_pubkey: stealth_account.spend_pubkey()?.serialize(),
                scan_pubkey: stealth_account.scan_pubkey()?.serialize(),
                valid_from_daa: target.valid_from_daa.unwrap_or(current_daa),
                valid_until_daa: target.valid_until_daa,
                nonce: 0,
                status: target.status.unwrap_or(DelegationStatus::Active),
            };

            if let Some(until) = header.valid_until_daa {
                if until <= header.valid_from_daa {
                    return Err(Error::InvalidRange(header.valid_from_daa, until));
                }
            }

            let previous_nonce = delegation_store.latest_nonce(&anchor_bytes, &header.account_id).unwrap_or(0);
            header.nonce = target.nonce_hint.unwrap_or(previous_nonce + 1);
            if header.nonce <= previous_nonce {
                return Err(Error::MasterDelegationStaleNonce {
                    account_id: header.account_id,
                    current: previous_nonce,
                    received: header.nonce,
                });
            }

            delegations.push(header);
        }
        drop(guard);

        let created_at_unixtime = created_at_unixtime
            .unwrap_or_else(|| std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs());

        let mut body = MasterDelegationRequestBodyV1 {
            version: 1,
            master_anchor: anchor_bytes,
            master_level: level,
            network_id: resolved_network,
            delegations,
            created_at_unixtime,
            request_id: [0u8; 32],
        };
        let request_id = calc_request_id(&body)?;
        body.request_id = request_id;

        let request_json = serde_json::to_string_pretty(&body).map_err(|e| Error::Custom(format!("serialize request: {e}")))?;

        self.save_delegation_request(&body).await?;

        self.notify(Events::MasterDelegationRequestBuilt {
            master_anchor: anchor_bytes,
            request_id,
            targets: body.delegations.iter().map(|header| header.account_id).collect(),
        })
        .await?;

        MasterMetrics::global().inc_delegation_requests();
        let anchor_short = crate::account::variants::mldsa_master::format_master_anchor_short(&MasterAnchor::new(anchor_bytes));
        let request_id_short = request_id[..4].to_vec().to_hex();
        log_info!("Built master delegation request: master_anchor={} delegation_request_id={}", anchor_short, request_id_short);

        Ok(MasterDelegationBuildResponse { request: body, request_json })
    }

    pub async fn sign_master_delegation_request(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        request: MasterDelegationRequestBodyV1,
        force_network_mismatch: bool,
    ) -> Result<MasterDelegationSignResponse> {
        ensure_request_versions(&request)?;
        let checksum = calc_request_id(&request)?;
        if checksum != request.request_id {
            return Err(Error::MasterDelegationInvalidChecksum {
                expected: request.request_id.to_vec().to_hex(),
                actual: checksum.to_vec().to_hex(),
            });
        }

        if !force_network_mismatch {
            let wallet_network = self.network_id()?;
            if wallet_network != request.network_id {
                return Err(Error::MasterDelegationNetworkMismatch { expected: wallet_network, actual: request.network_id });
            }
        }

        let anchor = MasterAnchor::new(request.master_anchor);
        let master = self.find_active_master_by_anchor(&anchor).ok_or_else(|| Error::Custom("master anchor not found".to_string()))?;

        if master.level() as u8 != request.master_level {
            return Err(Error::Custom("master level mismatch".to_string()));
        }

        let prv_store = self.inner.store.as_prv_key_data_store()?;
        let prv_key_data_id = *master.prv_key_data_id()?;
        let prv_key_data = prv_store
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        let payload = prv_key_data
            .as_mldsa_master(None)?
            .ok_or_else(|| Error::Custom("Specified key is not an MLDSA master record".to_string()))?;
        let master_seed = MasterSeed::from_slice(&payload.decrypt_seed(wallet_secret)?)
            .map_err(|err| Error::Custom(format!("invalid master seed: {err}")))?;
        master.unlock_with_master_seed(&master_seed, master.level()).await?;

        let mut signed = Vec::with_capacity(request.delegations.len());
        for header in request.delegations.iter() {
            if header.anchor != *anchor.as_bytes() {
                return Err(Error::Custom("delegation anchor mismatch".to_string()));
            }
            if header.level != request.master_level {
                return Err(Error::Custom("delegation level mismatch".to_string()));
            }
            let hash = hash_delegation_header(header)?;
            let sig = master.sign_delegation_hash(&hash).await?;
            let mut record = DelegationRecordV1::from(header);
            record.signature = sig.as_bytes().to_vec();
            signed.push(record);
        }

        master.lock().await;

        let response_body = MasterDelegationResponseBodyV1 {
            version: 1,
            master_anchor: request.master_anchor,
            master_level: request.master_level,
            request_id: request.request_id,
            delegations: signed,
        };

        let response_json =
            serde_json::to_string_pretty(&response_body).map_err(|e| Error::Custom(format!("serialize response: {e}")))?;

        Ok(MasterDelegationSignResponse { response: response_body, response_json })
    }

    pub async fn apply_master_delegation_response(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        request: MasterDelegationRequestBodyV1,
        response: MasterDelegationResponseBodyV1,
        force_network_mismatch: bool,
    ) -> Result<MasterDelegationApplyResponse> {
        let master_anchor = response.master_anchor;
        let request_id = request.request_id;
        match self.apply_master_delegation_response_inner(wallet_secret, request, response, force_network_mismatch).await {
            Ok(stats) => {
                self.notify(Events::MasterDelegationResponseApplied {
                    master_anchor,
                    request_id,
                    delegations: stats.applied,
                    skipped: stats.skipped,
                })
                .await?;
                MasterMetrics::global().inc_delegation_responses();
                let anchor_short =
                    crate::account::variants::mldsa_master::format_master_anchor_short(&MasterAnchor::new(master_anchor));
                let request_id_short = request_id[..4].to_vec().to_hex();
                log_info!(
                    "Applied master delegation response: master_anchor={} delegation_request_id={} applied={} skipped={}",
                    anchor_short,
                    request_id_short,
                    stats.applied,
                    stats.skipped
                );
                Ok(stats)
            }
            Err(err) => {
                MasterMetrics::global().inc_delegation_responses_failed();
                let _ = self.notify(Events::MasterDelegationApplyFailed { master_anchor, request_id, reason: err.to_string() }).await;
                let anchor_short =
                    crate::account::variants::mldsa_master::format_master_anchor_short(&MasterAnchor::new(master_anchor));
                let request_id_short = request_id[..4].to_vec().to_hex();
                log_error!(
                    "Failed to apply master delegation response: master_anchor={} delegation_request_id={} reason={}",
                    anchor_short,
                    request_id_short,
                    err
                );
                Err(err)
            }
        }
    }

    async fn apply_master_delegation_response_inner(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        request: MasterDelegationRequestBodyV1,
        response: MasterDelegationResponseBodyV1,
        force_network_mismatch: bool,
    ) -> Result<MasterDelegationApplyResponse> {
        ensure_request_versions(&request)?;
        ensure_response_versions(&response)?;

        // Защита от подмены request между оффлайн-подписью и apply: пересчитываем checksum.
        let checksum = calc_request_id(&request)?;
        if checksum != request.request_id {
            return Err(Error::MasterDelegationInvalidChecksum {
                expected: request.request_id.to_vec().to_hex(),
                actual: checksum.to_vec().to_hex(),
            });
        }
        if response.request_id != checksum {
            return Err(Error::MasterDelegationInvalidChecksum {
                expected: checksum.to_vec().to_hex(),
                actual: response.request_id.to_vec().to_hex(),
            });
        }

        if response.master_anchor != request.master_anchor || response.master_level != request.master_level {
            return Err(Error::Custom("delegation master mismatch".to_string()));
        }

        if !force_network_mismatch {
            let wallet_network = self.network_id()?;
            if wallet_network != request.network_id {
                return Err(Error::MasterDelegationNetworkMismatch { expected: wallet_network, actual: request.network_id });
            }
        }

        let anchor = MasterAnchor::new(response.master_anchor);
        let master = self.find_active_master_by_anchor(&anchor).ok_or_else(|| Error::Custom("master anchor not found".to_string()))?;
        if master.level() as u8 != response.master_level {
            return Err(Error::Custom("delegation response level mismatch".to_string()));
        }

        let master_storage = master.to_storage()?;
        let master_payload = MldsaMasterAccountPayloadV1::try_from_slice(master_storage.serialized())?;
        let master_pubkey = master_payload.master_pubkey;

        let store = self.delegation_store().clone();

        let mut header_map = HashMap::new();
        let mut expected_keys = HashSet::new();
        for header in request.delegations.iter() {
            let key = (header.account_id, header.nonce);
            if header_map.insert(key, header).is_some() {
                return Err(Error::Custom("delegation request contains duplicate account_id/nonce".to_string()));
            }
            expected_keys.insert(key);
        }

        let guard_handle = self.guard();
        let guard = guard_handle.lock().await;
        let account_store = self.inner.store.clone().as_account_store()?;

        let mut applied = 0usize;
        let mut skipped = 0usize;
        let mut missing_accounts = Vec::new();

        // Сначала валидируем ответ целиком (полноту + сигнатуры) без изменения стора.
        // Это защищает от частичного применения при ошибках и от "полных" ответов с битой подписью/полями.
        let mut validated_keys = HashSet::new();
        let mut validated_records = Vec::new();

        for record in response.delegations.iter() {
            if record.anchor != response.master_anchor || record.level != response.master_level {
                skipped += 1;
                continue;
            }

            let key = (record.account_id, record.nonce);
            let Some(header) = header_map.get(&key) else {
                skipped += 1;
                continue;
            };

            let expected = DelegationRecordV1::from(*header);
            if expected.anchor != record.anchor
                || expected.account_id != record.account_id
                || expected.valid_from_daa != record.valid_from_daa
                || expected.valid_until_daa != record.valid_until_daa
                || expected.spend_pubkey != record.spend_pubkey
                || expected.scan_pubkey != record.scan_pubkey
                || expected.status != record.status
            {
                return Err(Error::Custom(format!(
                    "delegation response record mismatch (account_id={}, nonce={})",
                    record.account_id, record.nonce
                )));
            }

            let verified = crate::account::delegation::verify_against_anchor(&anchor, &master_pubkey, record)?;
            if !verified {
                return Err(Error::Custom(format!(
                    "delegation response signature invalid (account_id={}, nonce={})",
                    record.account_id, record.nonce
                )));
            }

            if !validated_keys.insert(key) {
                return Err(Error::Custom(format!(
                    "delegation response contains duplicate record (account_id={}, nonce={})",
                    record.account_id, record.nonce
                )));
            }
            validated_records.push(record.clone());
        }
        if validated_keys.len() != expected_keys.len() {
            return Err(Error::Custom("delegation response missing records from request".to_string()));
        }

        for record in validated_records.iter() {
            if let Some((existing_id, existing)) =
                store.find_entry_by_anchor_account_nonce(&response.master_anchor, &record.account_id, record.nonce)
            {
                // Делегации могут содержать локальные мета-поля (например, `warned_at_daa`)
                // и/или получить локальный bump `version` при сохранении. Это не должно
                // ломать идемпотентность apply для одного и того же (account_id, nonce).
                let mut existing_cmp = existing.clone();
                existing_cmp.warned_at_daa = None;
                existing_cmp.version = 1;
                let mut incoming_cmp = record.clone();
                incoming_cmp.warned_at_daa = None;
                incoming_cmp.version = 1;

                if existing_cmp == incoming_cmp {
                    // Делегация уже сохранена в store, но аккаунт мог не успеть
                    // обновить ссылку на неё (например, при частичном применении из‑за I/O ошибки).
                    if let Some(account) = self.get_account_by_id(&record.account_id, &guard).await? {
                        let stealth_account = account.as_stealth_account()?;
                        if stealth_account.master_anchor() != Some(record.anchor)
                            || stealth_account.delegation_id() != Some(existing_id)
                        {
                            stealth_account.set_delegation(record.anchor, Some(existing_id));
                            account_store.store_single(&stealth_account.to_storage()?, None).await?;
                        }
                    } else {
                        missing_accounts.push(record.account_id);
                    }
                    skipped += 1;
                    continue;
                }
                return Err(Error::MasterDelegationNonceConflict { account_id: record.account_id, nonce: record.nonce });
            }

            if let Some(current_nonce) = store.latest_nonce(&response.master_anchor, &record.account_id) {
                if record.nonce <= current_nonce {
                    skipped += 1;
                    continue;
                }
            }

            let Some(account) = self.get_account_by_id(&record.account_id, &guard).await? else {
                missing_accounts.push(record.account_id);
                skipped += 1;
                continue;
            };
            let stealth_account = account.as_stealth_account()?;

            let delegation_id = match store.upsert(record.clone(), Some(response.request_id)) {
                Ok(id) => {
                    match record.status {
                        DelegationStatus::Active => MasterMetrics::global().inc_delegations_issued(),
                        DelegationStatus::Revoked { .. } => MasterMetrics::global().inc_delegations_revoked(),
                        DelegationStatus::Expired { .. } => {}
                    }
                    id
                }
                Err(Error::MasterDelegationStaleNonce { .. }) => {
                    skipped += 1;
                    continue;
                }
                Err(err) => return Err(err),
            };
            stealth_account.set_delegation(record.anchor, Some(delegation_id));
            account_store.store_single(&stealth_account.to_storage()?, None).await?;

            applied += 1;
        }
        drop(guard);

        self.save_delegations(wallet_secret).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(MasterDelegationApplyResponse { applied, skipped, missing_accounts })
    }

    async fn save_delegations(&self, wallet_secret: &Secret) -> Result<()> {
        if let Ok(descriptor) = self.store().location() {
            if let Some(wallet_folder) = descriptor.data_root() {
                if let Ok(network_id) = self.network_id() {
                    self.delegation_store().save_to_storage(&wallet_folder, network_id, wallet_secret).await?;
                }
            }
        }
        Ok(())
    }

    fn delegation_request_path(wallet_folder: &str, network_id: NetworkId, request_id: &[u8; 32]) -> PathBuf {
        PathBuf::from(wallet_folder)
            .join("delegations")
            .join(network_id.to_string())
            .join("requests")
            .join(format!("{}.json", request_id.to_vec().to_hex()))
    }

    async fn save_delegation_request(&self, request: &MasterDelegationRequestBodyV1) -> Result<()> {
        if let Ok(descriptor) = self.store().location() {
            if let Some(wallet_folder) = descriptor.data_root() {
                if let Ok(network_id) = self.network_id() {
                    let path = Self::delegation_request_path(&wallet_folder, network_id, &request.request_id);
                    if let Some(parent) = path.parent() {
                        fs::create_dir_all(parent).await?;
                    }
                    let json =
                        serde_json::to_vec_pretty(request).map_err(|e| Error::Custom(format!("serialize delegation request: {e}")))?;
                    fs::write(&path, json.as_slice()).await?;
                }
            }
        }
        Ok(())
    }

    pub async fn load_cached_master_delegation_request(&self, request_id: &[u8; 32]) -> Result<Option<MasterDelegationRequestBodyV1>> {
        if let Ok(descriptor) = self.store().location() {
            if let Some(wallet_folder) = descriptor.data_root() {
                if let Ok(network_id) = self.network_id() {
                    let path = Self::delegation_request_path(&wallet_folder, network_id, request_id);
                    if fs::exists(&path).await? {
                        let data = fs::read(&path).await?;
                        let request = serde_json::from_slice(&data)
                            .map_err(|e| Error::Custom(format!("read cached delegation request: {e}")))?;
                        return Ok(Some(request));
                    }
                }
            }
        }
        Ok(None)
    }

    pub fn active_accounts(&self) -> &ActiveAccountMap {
        &self.inner.active_accounts
    }
    pub fn legacy_accounts(&self) -> &ActiveAccountMap {
        &self.inner.legacy_accounts
    }

    pub async fn reset(self: &Arc<Self>, clear_legacy_cache: bool) -> Result<()> {
        self.utxo_processor().cleanup().await?;

        self.select(None).await?;

        let accounts = self.active_accounts().collect();
        let futures = accounts.into_iter().map(|account| account.stop());
        join_all(futures).await.into_iter().collect::<Result<Vec<_>>>()?;

        if clear_legacy_cache {
            self.legacy_accounts().clear();
        }

        Ok(())
    }

    pub async fn reload(self: &Arc<Self>, reactivate: bool, _guard: &WalletGuard<'_>) -> Result<()> {
        if self.is_open() {
            // similar to reset(), but effectively reboots the wallet

            // let _guard = self.inner.guard.lock().await;

            let accounts = self.active_accounts().collect();
            let account_descriptors = Some(accounts.iter().map(|account| account.descriptor()).collect::<Result<Vec<_>>>()?);
            let wallet_descriptor = self.store().descriptor();

            // shutdown all accounts
            let futures = accounts.iter().map(|account| account.clone().stop());
            join_all(futures).await.into_iter().collect::<Result<Vec<_>>>()?;

            // reset utxo processor
            self.utxo_processor().cleanup().await?;

            // notify reload event
            self.notify(Events::WalletReload { wallet_descriptor, account_descriptors }).await?;

            // if `reactivate` is false, it is the responsibility of the client
            // to re-activate accounts. just like with WalletOpen, the client
            // should fetch transaction history and only then re-activate the accounts.

            if reactivate {
                // restarting accounts will post discovery and balance events
                let futures = accounts.into_iter().map(|account| account.start());
                join_all(futures).await.into_iter().collect::<Result<Vec<_>>>()?;
            }
        }

        Ok(())
    }

    pub async fn close(self: &Arc<Wallet>) -> Result<()> {
        if self.is_open() {
            self.reset(true).await?;
            self.store().close().await?;
            self.notify(Events::WalletClose).await?;
        }

        Ok(())
    }

    cfg_if! {
        if #[cfg(not(feature = "multi-user"))] {

            fn default_active_account(&self) -> Option<Arc<dyn Account>> {
                self.active_accounts().first()
            }

            /// For end-user wallets only - selects an account only if there
            /// is only a single account currently active in the wallet.
            /// Can be used to automatically select the default account.
            pub async fn autoselect_default_account_if_single(self: &Arc<Wallet>) -> Result<()> {
                if self.active_accounts().len() == 1 {
                    self.select(self.default_active_account().as_ref()).await?;
                }
                Ok(())
            }

            /// Select an account as 'active'. Supply `None` to remove active selection.
            pub async fn select(self: &Arc<Self>, account: Option<&Arc<dyn Account>>) -> Result<()> {
                *self.inner.selected_account.lock().unwrap() = account.cloned();
                if let Some(account) = account {
                    // log_info!("selecting account: {}", account.name_or_id());
                    account.clone().start().await?;
                    self.notify(Events::AccountSelection{ id : Some(*account.id()) }).await?;
                } else {
                    self.notify(Events::AccountSelection{ id : None }).await?;
                }
                Ok(())
            }

            /// Get currently selected account
            pub fn account(&self) -> Result<Arc<dyn Account>> {
                self.inner.selected_account.lock().unwrap().clone().ok_or_else(|| Error::AccountSelection)
            }



        }
        else {
            fn default_active_account(&self) -> Option<Arc<dyn Account>> {
                self.active_accounts().first()
            }

            pub async fn autoselect_default_account_if_single(self: &Arc<Wallet>) -> Result<()> {
                if self.active_accounts().len() == 1 {
                    self.select(self.default_active_account().as_ref()).await?;
                }
                Ok(())
            }

            pub async fn select(self: &Arc<Self>, account: Option<&Arc<dyn Account>>) -> Result<()> {
                *self.inner.selected_account.lock().unwrap() = account.cloned();
                if let Some(account) = account {
                    account.clone().start().await?;
                    self.notify(Events::AccountSelection { id: Some(*account.id()) }).await?;
                } else {
                    self.notify(Events::AccountSelection { id: None }).await?;
                }
                Ok(())
            }

            pub fn account(&self) -> Result<Arc<dyn Account>> {
                self.inner.selected_account.lock().unwrap().clone().ok_or_else(|| Error::AccountSelection)
            }
        }
    }

    /// Loads a wallet from storage. Accounts are not activated by this call.
    async fn open_impl(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        filename: Option<String>,
        args: WalletOpenArgs,
    ) -> Result<Option<Vec<AccountDescriptor>>> {
        // let _guard = self.inner.guard.lock().await;

        let filename = filename.or_else(|| self.settings().get(WalletSettings::Wallet));
        // let name = Some(make_filename(&name, &None));

        let was_open = self.is_open();

        self.store().open(wallet_secret, OpenArgs::new(filename)).await?;
        let masters_created = self.hydrate_mldsa_masters(wallet_secret).await?;
        if masters_created {
            self.inner.store.commit(wallet_secret).await?;
        }

        // Load delegations storage (best-effort; ignore if storage is non-internal)
        if let Ok(descriptor) = self.store().location() {
            if let Some(wallet_folder) = descriptor.data_root() {
                if let Ok(network_id) = self.network_id() {
                    let _ = self.delegation_store().load_from_storage(&wallet_folder, network_id, wallet_secret).await;
                }
            }
        }

        let wallet_name = self.store().descriptor();

        if was_open {
            self.notify(Events::WalletClose).await?;
        }

        // reset current state only after we have successfully opened another wallet
        self.reset(true).await?;

        let accounts: Option<Vec<Arc<dyn Account>>> = if args.load_account_descriptors() {
            let stored_accounts = self.inner.store.as_account_store()?.iter(None).await?.try_collect::<Vec<_>>().await?;
            let stored_accounts = if !args.is_legacy_only() {
                stored_accounts
            } else {
                stored_accounts
                    .into_iter()
                    .filter(|(account_storage, _)| account_storage.kind.as_ref() == LEGACY_ACCOUNT_KIND)
                    .collect::<Vec<_>>()
            };
            Some(
                futures::stream::iter(stored_accounts.into_iter())
                    .then(|(account, meta)| try_load_account(self, account, meta))
                    .try_collect::<Vec<_>>()
                    // .try_collect::<Result<Vec<_>>>()
                    .await?,
            )
        } else {
            None
        };

        if let Some(accounts) = &accounts {
            for account in accounts.iter() {
                if let Ok(legacy_account) = account.clone().as_legacy_account() {
                    legacy_account.create_private_context(wallet_secret, None, None).await?;
                    log_info!("create_private_context, open_impl: receive_address: {:?}", account.receive_address());
                    self.legacy_accounts().insert(account.clone());
                }
                // Auto-unlock stealth accounts on wallet open
                if account.account_kind().as_ref() == stealth::STEALTH_ACCOUNT_KIND {
                    if let Ok(stealth_account) = account.clone().as_stealth_account() {
                        stealth_account.unlock(wallet_secret, None).await?;
                    }
                }
            }
        }

        let account_descriptors = accounts
            .as_ref()
            .map(|accounts| accounts.iter().map(|account| account.descriptor()).collect::<Result<Vec<_>>>())
            .transpose()?;

        self.notify(Events::WalletOpen { wallet_descriptor: wallet_name, account_descriptors: account_descriptors.clone() }).await?;

        let hint = self.store().get_user_hint().await?;
        self.notify(Events::WalletHint { hint }).await?;

        Ok(account_descriptors)
    }

    /// Loads a wallet from storage. Accounts are not activated by this call.
    pub async fn open(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        filename: Option<String>,
        args: WalletOpenArgs,
        _guard: &WalletGuard<'_>,
    ) -> Result<Option<Vec<AccountDescriptor>>> {
        // This is a wrapper of open_impl() that catches errors and notifies the UI
        match self.open_impl(wallet_secret, filename, args).await {
            Ok(account_descriptors) => Ok(account_descriptors),
            Err(err) => {
                self.notify(Events::WalletError { message: err.to_string() }).await?;
                Err(err)
            }
        }
    }

    async fn activate_accounts_impl(self: &Arc<Wallet>, account_ids: Option<&[AccountId]>) -> Result<Vec<AccountId>> {
        // let _guard = self.inner.guard.lock().await;

        let stored_accounts = if let Some(ids) = account_ids {
            self.inner.store.as_account_store()?.load_multiple(ids).await?
        } else {
            self.inner.store.as_account_store()?.iter(None).await?.try_collect::<Vec<_>>().await?
        };

        let ids = stored_accounts.iter().map(|(account, _)| *account.id()).collect::<Vec<_>>();

        for (account_storage, meta) in stored_accounts.into_iter() {
            if account_storage.kind.as_ref() == LEGACY_ACCOUNT_KIND {
                let legacy_account = self
                    .legacy_accounts()
                    .get(account_storage.id())
                    .ok_or_else(|| Error::LegacyAccountNotInitialized)?
                    .clone()
                    .as_legacy_account()?;
                legacy_account.clone().start().await?;
                legacy_account.clear_private_context().await?;
            } else if self.active_accounts().get(account_storage.id()).is_none() {
                let account = try_load_account(self, account_storage, meta).await?;
                account.clone().start().await?;
            }
        }

        self.notify(Events::AccountActivation { ids: ids.clone() }).await?;

        Ok(ids)
    }

    /// Activates accounts (performs account address space counts, initializes balance tracking, etc.)
    pub async fn activate_accounts(self: &Arc<Wallet>, account_ids: Option<&[AccountId]>, _guard: &WalletGuard<'_>) -> Result<()> {
        // This is a wrapper of activate_accounts_impl() that catches errors and notifies the UI
        if let Err(err) = self.activate_accounts_impl(account_ids).await {
            self.notify(Events::WalletError { message: err.to_string() }).await?;
            Err(err)
        } else {
            Ok(())
        }
    }

    pub async fn deactivate_accounts(self: &Arc<Wallet>, ids: Option<&[AccountId]>, _guard: &WalletGuard<'_>) -> Result<()> {
        let _guard = self.inner.guard.lock().await;

        let (ids, futures) = if let Some(ids) = ids {
            let accounts =
                ids.iter().map(|id| self.active_accounts().get(id).ok_or(Error::AccountNotFound(*id))).collect::<Result<Vec<_>>>()?;
            (ids.to_vec(), accounts.into_iter().map(|account| account.stop()).collect::<Vec<_>>())
        } else {
            self.active_accounts().collect().iter().map(|account| (account.id(), account.clone().stop())).unzip()
        };

        join_all(futures).await.into_iter().collect::<Result<Vec<_>>>()?;
        self.notify(Events::AccountDeactivation { ids }).await?;

        Ok(())
    }

    pub async fn account_descriptors(self: Arc<Self>, _guard: &WalletGuard<'_>) -> Result<Vec<AccountDescriptor>> {
        // let _guard = self.inner.guard.lock().await;

        let iter = self.inner.store.as_account_store()?.iter(None).await?;
        let wallet = self.clone();

        let stream = iter.then(move |stored| {
            let wallet = wallet.clone();

            async move {
                let (stored_account, stored_metadata) = stored?;
                if let Some(account) = wallet.legacy_accounts().get(&stored_account.id) {
                    account.descriptor()
                } else if let Some(account) = wallet.active_accounts().get(&stored_account.id) {
                    account.descriptor()
                } else {
                    try_load_account(&wallet, stored_account, stored_metadata).await?.descriptor()
                }
            }
        });

        stream.try_collect::<Vec<_>>().await
    }

    pub async fn get_prv_key_data(&self, wallet_secret: &Secret, id: &PrvKeyDataId) -> Result<Option<PrvKeyData>> {
        self.inner.store.as_prv_key_data_store()?.load_key_data(wallet_secret, id).await
    }

    pub async fn get_prv_key_info(&self, account: &Arc<dyn Account>) -> Result<Option<Arc<PrvKeyDataInfo>>> {
        self.inner.store.as_prv_key_data_store()?.load_key_info(account.prv_key_data_id()?).await
    }

    pub async fn is_account_key_encrypted(&self, account: &Arc<dyn Account>) -> Result<Option<bool>> {
        Ok(self.get_prv_key_info(account).await?.map(|info| info.is_encrypted()))
    }

    pub fn try_wrpc_client(&self) -> Option<Arc<KaspaRpcClient>> {
        self.try_rpc_api().and_then(|api| api.clone().downcast_arc::<KaspaRpcClient>().ok())
    }

    pub fn wrpc_client(&self) -> Arc<KaspaRpcClient> {
        self.try_rpc_api().and_then(|api| api.clone().downcast_arc::<KaspaRpcClient>().ok()).unwrap()
    }

    pub fn rpc_api(&self) -> Arc<DynRpcApi> {
        self.utxo_processor().rpc_api()
    }

    pub fn try_rpc_api(&self) -> Option<Arc<DynRpcApi>> {
        self.utxo_processor().try_rpc_api()
    }

    pub fn rpc_ctl(&self) -> RpcCtl {
        self.utxo_processor().rpc_ctl()
    }

    pub fn try_rpc_ctl(&self) -> Option<RpcCtl> {
        self.utxo_processor().try_rpc_ctl()
    }

    pub fn has_rpc(&self) -> bool {
        self.utxo_processor().has_rpc()
    }

    pub async fn bind_rpc(self: &Arc<Self>, rpc: Option<Rpc>) -> Result<()> {
        self.utxo_processor().bind_rpc(rpc).await?;
        Ok(())
    }

    pub fn as_api(self: &Arc<Self>) -> Arc<dyn WalletApi> {
        self.clone()
    }

    pub fn to_api(self) -> Arc<dyn WalletApi> {
        Arc::new(self)
    }

    pub fn multiplexer(&self) -> &Multiplexer<Box<Events>> {
        &self.inner.multiplexer
    }

    pub(crate) fn wallet_bus(&self) -> &Channel<WalletBusMessage> {
        &self.inner.wallet_bus
    }

    pub fn settings(&self) -> &SettingsStore<WalletSettings> {
        &self.inner.settings
    }

    pub fn current_daa_score(&self) -> Option<u64> {
        self.utxo_processor().current_daa_score()
    }

    pub async fn load_settings(&self) -> Result<()> {
        self.settings().try_load().await?;

        let settings = self.settings();

        if let Some(network_id) = settings.get(WalletSettings::Network) {
            self.set_network_id(&network_id).unwrap_or_else(|_| log_error!("Unable to select network type: `{}`", network_id));
        }

        if let Some(url) = settings.get::<String>(WalletSettings::Server) {
            if let Some(wrpc_client) = self.try_wrpc_client() {
                wrpc_client.set_url(Some(url.as_str())).unwrap_or_else(|_| log_error!("Unable to set rpc url: `{}`", url));
            }
        }

        Ok(())
    }

    // intended for starting async management tasks
    pub async fn start(self: &Arc<Self>) -> Result<()> {
        // self.load_settings().await.unwrap_or_else(|_| log_error!("Unable to load settings, discarding..."));

        // internal event loop
        self.start_task().await?;
        self.utxo_processor().start().await?;
        // rpc services (notifier)
        if let Some(rpc_client) = self.try_wrpc_client() {
            rpc_client.start().await?;
        }

        Ok(())
    }

    // intended for stopping async management task
    pub async fn stop(&self) -> Result<()> {
        self.utxo_processor().stop().await?;
        self.stop_task().await?;
        Ok(())
    }

    pub fn listener_id(&self) -> Result<ListenerId> {
        self.inner.listener_id.lock().unwrap().ok_or(Error::ListenerId)
    }

    pub async fn get_info(&self) -> Result<String> {
        let v = self.rpc_api().get_info().await?;
        Ok(format!("{v:#?}").replace('\n', "\r\n"))
    }

    pub async fn subscribe_daa_score(&self) -> Result<()> {
        self.rpc_api().start_notify(self.listener_id()?, Scope::VirtualDaaScoreChanged(VirtualDaaScoreChangedScope {})).await?;
        Ok(())
    }

    pub async fn unsubscribe_daa_score(&self) -> Result<()> {
        self.rpc_api().stop_notify(self.listener_id()?, Scope::VirtualDaaScoreChanged(VirtualDaaScoreChangedScope {})).await?;
        Ok(())
    }

    pub async fn broadcast(&self) -> Result<()> {
        Ok(())
    }

    pub fn set_network_id(&self, network_id: &NetworkId) -> Result<()> {
        if self.is_connected() {
            return Err(Error::NetworkTypeConnected);
        }
        self.utxo_processor().set_network_id(network_id);

        if let Some(wrpc_client) = self.try_wrpc_client() {
            wrpc_client.set_network_id(network_id)?;
        }
        Ok(())
    }

    pub fn network_id(&self) -> Result<NetworkId> {
        self.utxo_processor().network_id()
    }

    pub fn address_prefix(&self) -> Result<kaspa_addresses::Prefix> {
        Ok(self.network_id()?.into())
    }

    pub fn default_port(&self) -> Result<Option<u16>> {
        let network_type = self.network_id()?;
        if let Some(wrpc_client) = self.try_wrpc_client() {
            let port = match wrpc_client.encoding() {
                WrpcEncoding::Borsh => network_type.default_borsh_rpc_port(),
                WrpcEncoding::SerdeJson => network_type.default_json_rpc_port(),
            };
            Ok(Some(port))
        } else {
            Ok(None)
        }
    }

    pub async fn create_account(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        account_create_args: AccountCreateArgs,
        notify: bool,
        _guard: &WalletGuard<'_>,
    ) -> Result<Arc<dyn Account>> {
        let account = match account_create_args {
            AccountCreateArgs::Bip32 { prv_key_data_args, account_args } => {
                let PrvKeyDataArgs { prv_key_data_id, payment_secret } = prv_key_data_args;
                self.create_account_bip32(wallet_secret, prv_key_data_id, payment_secret.as_ref(), account_args).await?
            }
            AccountCreateArgs::Legacy { prv_key_data_id, account_name } => {
                self.create_account_legacy(wallet_secret, prv_key_data_id, account_name).await?
            }
            AccountCreateArgs::Multisig { prv_key_data_args, additional_xpub_keys, name, minimum_signatures } => {
                self.create_account_multisig(wallet_secret, prv_key_data_args, additional_xpub_keys, name, minimum_signatures).await?
            }
            AccountCreateArgs::Bip32Watch { account_args } => self.create_account_bip32_watch(wallet_secret, account_args).await?,
            AccountCreateArgs::Keypair { prv_key_data_id, account_name, ecdsa } => {
                self.create_account_keypair(wallet_secret, None, prv_key_data_id, account_name, ecdsa).await?
            }
            AccountCreateArgs::Stealth { prv_key_data_args, account_name, account_index } => {
                let PrvKeyDataArgs { prv_key_data_id, payment_secret } = prv_key_data_args;
                self.create_account_stealth(wallet_secret, prv_key_data_id, payment_secret.as_ref(), account_name, account_index)
                    .await?
            }
            AccountCreateArgs::MldsaMaster { prv_key_data_id, level, account_name } => {
                self.create_account_mldsa_master(wallet_secret, prv_key_data_id, level, account_name).await?
            }
        };

        if notify {
            let account_descriptor = account.descriptor()?;
            self.notify(Events::AccountCreate { account_descriptor }).await?;
        }

        Ok(account)
    }

    pub async fn create_account_multisig(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        prv_key_data_args: Vec<PrvKeyDataArgs>,
        mut xpub_keys: Vec<String>,
        account_name: Option<String>,
        minimum_signatures: u16,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let account: Arc<dyn Account> = if prv_key_data_args.is_not_empty() {
            let mut generated_xpubs = Vec::with_capacity(prv_key_data_args.len());
            let mut prv_key_data_ids = Vec::with_capacity(prv_key_data_args.len());
            for prv_key_data_arg in prv_key_data_args.into_iter() {
                let PrvKeyDataArgs { prv_key_data_id, payment_secret } = prv_key_data_arg;
                let prv_key_data = self
                    .inner
                    .store
                    .as_prv_key_data_store()?
                    .load_key_data(wallet_secret, &prv_key_data_id)
                    .await?
                    .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;
                let xpub_key = prv_key_data.create_xpub(payment_secret.as_ref(), MULTISIG_ACCOUNT_KIND.into(), 0).await?; // todo it can be done concurrently
                generated_xpubs.push(xpub_key.to_string(Some(KeyPrefix::XPUB)));
                prv_key_data_ids.push(prv_key_data_id);
            }

            generated_xpubs.sort_unstable();
            xpub_keys.extend_from_slice(generated_xpubs.as_slice());
            xpub_keys.sort_unstable();

            let min_cosigner_index =
                generated_xpubs.first().and_then(|first_generated| xpub_keys.binary_search(first_generated).ok()).map(|v| v as u8);

            let xpub_keys = xpub_keys
                .into_iter()
                .map(|xpub_key| {
                    ExtendedPublicKeySecp256k1::from_str(&xpub_key).map_err(|err| Error::InvalidExtendedPublicKey(xpub_key, err))
                })
                .collect::<Result<Vec<_>>>()?;

            Arc::new(
                multisig::MultiSig::try_new(
                    self,
                    account_name,
                    Arc::new(xpub_keys),
                    Some(Arc::new(prv_key_data_ids)),
                    min_cosigner_index,
                    minimum_signatures,
                    false,
                )
                .await?,
            )
        } else {
            let xpub_keys = xpub_keys
                .into_iter()
                .map(|xpub_key| {
                    ExtendedPublicKeySecp256k1::from_str(&xpub_key).map_err(|err| Error::InvalidExtendedPublicKey(xpub_key, err))
                })
                .collect::<Result<Vec<_>>>()?;

            Arc::new(
                multisig::MultiSig::try_new(self, account_name, Arc::new(xpub_keys), None, None, minimum_signatures, false).await?,
            )
        };

        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }

    pub async fn create_account_bip32(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        prv_key_data_id: PrvKeyDataId,
        payment_secret: Option<&Secret>,
        account_args: AccountCreateArgsBip32,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let prv_key_data = self
            .inner
            .store
            .as_prv_key_data_store()?
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        let AccountCreateArgsBip32 { account_name, account_index } = account_args;

        let account_index = if let Some(account_index) = account_index {
            account_index
        } else {
            let accounts = account_store.clone().iter(Some(prv_key_data_id)).await?.collect::<Vec<_>>().await;

            accounts
                .into_iter()
                .filter(|a| a.as_ref().ok().and_then(|(a, _)| (a.kind == BIP32_ACCOUNT_KIND).then_some(true)).unwrap_or(false))
                .collect::<Vec<_>>()
                .len() as u64
        };

        let xpub_key = prv_key_data.create_xpub(payment_secret, BIP32_ACCOUNT_KIND.into(), account_index).await?;
        let xpub_keys = Arc::new(vec![xpub_key]);

        let account: Arc<dyn Account> =
            Arc::new(bip32::Bip32::try_new(self, account_name, prv_key_data.id, account_index, xpub_keys, false).await?);

        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }

    /// Creates a new stealth account for privacy-preserving transactions.
    ///
    /// Stealth accounts use ECDH to generate one-time destination addresses,
    /// providing unlinkable payments.
    pub async fn create_account_stealth(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        prv_key_data_id: PrvKeyDataId,
        payment_secret: Option<&Secret>,
        account_name: Option<String>,
        account_index: Option<u64>,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let prv_key_data = self
            .inner
            .store
            .as_prv_key_data_store()?
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        // Determine account index
        let account_index = if let Some(index) = account_index {
            index
        } else {
            // Count existing stealth accounts for this prv_key_data_id
            let accounts = account_store.clone().iter(Some(prv_key_data_id)).await?.collect::<Vec<_>>().await;
            accounts
                .into_iter()
                .filter(|a| {
                    a.as_ref().ok().and_then(|(a, _)| (a.kind == stealth::STEALTH_ACCOUNT_KIND).then_some(true)).unwrap_or(false)
                })
                .count() as u64
        };

        // Derive stealth keys
        let payload = prv_key_data.payload.decrypt(payment_secret)?;
        let xprv = payload.get_xprv(payment_secret)?;
        let derivation = stealth::StealthKeyDerivation::from_xprv(&xprv, account_index)?;

        // Get current DAA score for account creation timestamp
        let mut creation_daa_score = self.utxo_processor().current_daa_score();
        if creation_daa_score.is_none() {
            if let Some(rpc) = self.utxo_processor().try_rpc_api() {
                if let Ok(info) = rpc.get_server_info().await {
                    creation_daa_score = Some(info.virtual_daa_score);
                }
            }
        }

        // Create account
        let account: Arc<dyn Account> = Arc::new(
            stealth::StealthAccount::try_new(
                self,
                account_name,
                prv_key_data.id,
                account_index,
                derivation.scan_pubkey,
                derivation.spend_pubkey,
                creation_daa_score,
            )
            .await?,
        );

        // Check for duplicates
        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        // Store account
        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }

    pub async fn create_account_bip32_watch(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        account_args: AccountCreateArgsBip32Watch,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let AccountCreateArgsBip32Watch { account_name, xpub_keys } = account_args;

        let xpub_keys = Arc::new(
            xpub_keys
                .into_iter()
                .map(|xpub_key| {
                    ExtendedPublicKeySecp256k1::from_str(&xpub_key).map_err(|err| Error::InvalidExtendedPublicKey(xpub_key, err))
                })
                .collect::<Result<Vec<_>>>()?,
        );

        let account: Arc<dyn Account> = Arc::new(bip32watch::Bip32Watch::try_new(self, account_name, xpub_keys, false).await?);

        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }

    async fn create_account_legacy(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        prv_key_data_id: PrvKeyDataId,
        account_name: Option<String>,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let prv_key_data = self
            .inner
            .store
            .as_prv_key_data_store()?
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        let account: Arc<dyn Account> = Arc::new(legacy::Legacy::try_new(self, account_name, prv_key_data.id).await?);
        if let Ok(legacy_account) = account.clone().as_legacy_account() {
            legacy_account.create_private_context(wallet_secret, None, None).await?;
            log_info!("create_private_context: create_account_legacy, receive_address: {:?}", account.receive_address());
            self.legacy_accounts().insert(account.clone());
            //legacy_account.clear_private_context().await?;
        }

        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }

    pub async fn create_account_keypair(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        prv_key_data_id: PrvKeyDataId,
        account_name: Option<String>,
        ecdsa: bool,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let prv_key_data = self
            .inner
            .store
            .as_prv_key_data_store()?
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        let secret_key = prv_key_data
            .as_secret_key(payment_secret)
            .map_err(|_| Error::custom("Invalid private key"))?
            .ok_or(Error::custom("Sectet key is required"))?;

        let secp = secp256k1::Secp256k1::new();
        let public_key = secret_key.public_key(&secp);
        let prv_key_data_id = prv_key_data.id;
        let account: Arc<dyn Account> =
            Arc::new(keypair::Keypair::try_new(self, account_name, public_key, prv_key_data_id, ecdsa).await?);

        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }

    pub async fn create_account_mldsa_master(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        prv_key_data_id: PrvKeyDataId,
        level: MlDsaLevel,
        account_name: Option<String>,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        let prv_key_data = self
            .inner
            .store
            .as_prv_key_data_store()?
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        let payload = prv_key_data
            .as_mldsa_master(None)?
            .ok_or_else(|| Error::Custom("Specified key is not an MLDSA master record".to_string()))?;

        let payload_level = payload.level().ok_or_else(|| Error::Custom("Invalid MLDSA level in stored payload".to_string()))?;
        if payload_level != level {
            return Err(Error::Custom("Requested MLDSA level does not match stored master payload".to_string()));
        }

        let master_seed =
            MasterSeed::from_slice(&payload.decrypt_seed(wallet_secret)?).map_err(|err| Error::Custom(format!("{err}")))?;
        let (pair, anchor) = MlDsaKeypair::from_master_seed(&master_seed, level)?;

        let created_at_daa = self.current_daa_score();
        let account: Arc<dyn Account> = Arc::new(
            MldsaMasterAccount::try_new(
                self,
                account_name,
                prv_key_data_id,
                anchor,
                pair.public_key_bytes().to_vec(),
                level,
                created_at_daa.unwrap_or_default(),
                MasterStatus::Active,
                vec![],
            )
            .await?,
        );

        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;
        self.notify(Events::MasterAccountCreated { account_id: *account.id(), anchor: *anchor.as_bytes(), level: level as u8 })
            .await?;

        log_info!(
            "Created MLDSA master account: master_anchor={} level={:?} account_id={}",
            crate::account::variants::mldsa_master::format_master_anchor_short(&anchor),
            level,
            account.id()
        );

        Ok(account)
    }

    pub async fn list_master_accounts(&self) -> Result<Vec<MasterAccountInfo>> {
        let account_store = self.inner.store.clone().as_account_store()?;
        let stored_accounts = account_store.iter(None).await?.try_collect::<Vec<_>>().await?;
        let mut masters = vec![];

        for (account_storage, _) in stored_accounts.into_iter() {
            if account_storage.kind.as_ref() != MLDSA_MASTER_ACCOUNT_KIND {
                continue;
            }
            let payload = MldsaMasterAccountPayloadV1::try_from_slice(account_storage.serialized.as_slice())?;
            masters.push(MasterAccountInfo {
                account_id: account_storage.id,
                anchor: *payload.anchor.as_bytes(),
                level: payload.level as u8,
                status: payload.status.clone(),
            });
        }

        Ok(masters)
    }

    pub async fn get_master_by_anchor(&self, anchor: &MasterAnchor) -> Result<Option<MasterAccountInfo>> {
        let masters = self.list_master_accounts().await?;
        Ok(masters.into_iter().find(|info| info.anchor == *anchor.as_bytes()))
    }

    fn find_active_master_by_anchor(&self, anchor: &MasterAnchor) -> Option<Arc<MldsaMasterAccount>> {
        self.active_accounts()
            .collect()
            .into_iter()
            .find_map(|acc| acc.clone().downcast_arc::<MldsaMasterAccount>().ok().filter(|m| m.anchor() == anchor))
    }

    pub async fn rotate_master_account(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        account_id: &AccountId,
        new_level: Option<MlDsaLevel>,
        new_master_seed: Option<MasterSeed>,
    ) -> Result<()> {
        use crate::encryption::encrypt_xchacha20poly1305;
        use crate::storage::keydata::data::{MlDsaMasterPayload, PrvKeyDataPayload};
        use crate::storage::keydata::PrvKeyData;

        let account_store = self.inner.store.clone().as_account_store()?;
        let (stored_account, _meta) = account_store.load_single(account_id).await?.ok_or(Error::AccountNotFound(*account_id))?;
        if stored_account.kind.as_ref() != MLDSA_MASTER_ACCOUNT_KIND {
            return Err(Error::InvalidAccountKind);
        }

        let mut account_payload = MldsaMasterAccountPayloadV1::try_from_slice(stored_account.serialized())?;
        let old_anchor = *account_payload.anchor.as_bytes();
        let level_before = account_payload.level;
        let level = new_level.unwrap_or(level_before);

        let master_id: PrvKeyDataId = stored_account.prv_key_data_ids.clone().try_into()?;
        let prv_store = self.inner.store.as_prv_key_data_store()?;
        let mut prv_key_data: PrvKeyData =
            prv_store.load_key_data(wallet_secret, &master_id).await?.ok_or_else(|| Error::PrivateKeyNotFound(master_id))?;

        let master_payload = prv_key_data
            .as_mldsa_master(None)?
            .ok_or_else(|| Error::Custom("Specified key is not an MLDSA master record".to_string()))?;

        let master_seed = match new_master_seed {
            Some(ref seed) => seed.clone(),
            None => {
                MasterSeed::from_slice(&master_payload.decrypt_seed(wallet_secret)?).map_err(|err| Error::Custom(format!("{err}")))?
            }
        };

        let (pair, new_anchor) = MlDsaKeypair::from_master_seed(&master_seed, level)?;

        let seed_cipher = if new_master_seed.is_some() {
            encrypt_xchacha20poly1305(master_seed.as_bytes(), wallet_secret)?
        } else {
            master_payload.seed_cipher().to_vec()
        };

        let updated_master_payload = MlDsaMasterPayload::new(level, new_anchor, seed_cipher);
        let updated_prv_payload = PrvKeyDataPayload::try_new_with_mldsa_master(updated_master_payload)?;

        prv_key_data.payload = match &prv_key_data.payload {
            crate::encryption::Encryptable::Plain(_) => crate::encryption::Encryptable::Plain(updated_prv_payload),
            crate::encryption::Encryptable::XChaCha20Poly1305(enc) => {
                let kind = enc.kind();
                let encrypted = Decrypted::new(updated_prv_payload.clone()).encrypt(wallet_secret, kind)?;
                crate::encryption::Encryptable::XChaCha20Poly1305(encrypted)
            }
        };

        account_payload.level = level;
        account_payload.anchor = new_anchor;
        account_payload.master_pubkey = pair.public_key_bytes().to_vec();
        account_payload.status =
            MasterStatus::Rotated { rotated_at_daa: self.current_daa_score().unwrap_or_default(), new_anchor: Some(new_anchor) };

        let updated_account_storage = AccountStorage::try_new(
            stored_account.kind,
            stored_account.id(),
            stored_account.storage_key(),
            stored_account.prv_key_data_ids.clone(),
            stored_account.settings.clone(),
            account_payload,
        )?;

        prv_store.store(wallet_secret, prv_key_data).await?;
        account_store.store_single(&updated_account_storage, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        self.notify(Events::MasterAccountRotated { account_id: *account_id, old_anchor, new_anchor: *new_anchor.as_bytes() }).await?;

        MasterMetrics::global().inc_rotations();
        log_info!(
            "Rotated MLDSA master: master_anchor={} level_before={:?} level_after={:?}",
            crate::account::variants::mldsa_master::format_master_anchor_short(&new_anchor),
            level_before,
            level
        );

        Ok(())
    }

    // ========================================================================
    // STEALTH ACCOUNT OPERATIONS
    // ========================================================================

    pub async fn link_stealth_to_master(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        stealth_id: AccountId,
        master_anchor: [u8; 32],
        window_daa: u64,
        valid_for_daa: Option<u64>,
    ) -> Result<DelegationId> {
        if !self.is_mldsa_master_enabled() {
            return Err(Error::Custom("MLDSA master mode is disabled in settings".to_string()));
        }

        let guard = self.guard();
        let guard = guard.lock().await;

        let anchor = MasterAnchor::new(master_anchor);
        let stealth_account = self.get_account_by_id(&stealth_id, &guard).await?.ok_or(Error::AccountNotFound(stealth_id))?;
        let stealth = stealth_account.as_stealth_account()?;

        if let Some(existing_anchor) = stealth.master_anchor() {
            if existing_anchor != master_anchor {
                return Err(Error::Custom("stealth already attached to another master anchor".to_string()));
            }
        }

        let master = self.find_active_master_by_anchor(&anchor).ok_or_else(|| Error::Custom("master anchor not found".to_string()))?;
        let level = master.level();

        let current_daa_opt = self.current_daa_score();
        if current_daa_opt.is_none() && window_daa > 0 {
            return Err(Error::Custom("window_daa requires current DAA score (connect wallet to a node first)".to_string()));
        }
        let current_daa = current_daa_opt.unwrap_or(0);
        let valid_from = current_daa.saturating_sub(window_daa);
        let valid_until = match (current_daa_opt, valid_for_daa) {
            (Some(current), Some(v)) => Some(current.saturating_add(v)),
            (None, Some(_)) => {
                return Err(Error::Custom("valid_for_daa requires current DAA score (connect wallet to a node first)".to_string()));
            }
            (_, None) => None,
        };

        let next_nonce = self
            .delegation_store()
            .by_anchor(anchor.as_bytes())
            .into_iter()
            .filter(|(_, rec)| rec.account_id == stealth_id)
            .map(|(_, rec)| rec.nonce)
            .max()
            .unwrap_or(0)
            .saturating_add(1);

        let mut record = DelegationRecordV1::new(
            level,
            master_anchor,
            *stealth.id(),
            stealth.spend_pubkey()?.serialize(),
            stealth.scan_pubkey()?.serialize(),
            valid_from,
            valid_until,
            next_nonce,
            DelegationStatus::Active,
        );

        let hash = delegation_message_hash(&record)?;
        let signature = master.sign_delegation_hash(&hash).await?;
        record.signature = signature.as_bytes().to_vec();

        let id = self.delegation_store().upsert(record, None)?;
        MasterMetrics::global().inc_delegations_issued();
        log_info!(
            "Created master delegation: master_anchor={} delegation_id={} valid_until_daa={:?}",
            crate::account::variants::mldsa_master::format_master_anchor_short(&MasterAnchor::new(master_anchor)),
            id.0,
            valid_until
        );
        self.save_delegations(wallet_secret).await?;

        // Update stealth payload
        stealth.set_delegation(master_anchor, Some(id));

        // Persist stealth account
        let account_store = self.inner.store.clone().as_account_store()?;
        account_store.store_single(&stealth.to_storage()?, None).await?;

        // Update master payload delegations list (best-effort)
        let master_storage = master.to_storage()?;
        let mut master_payload = MldsaMasterAccountPayloadV1::try_from_slice(master_storage.serialized())?;
        if !master_payload.delegations.contains(&id.0) {
            master_payload.delegations.push(id.0);
            let updated = AccountStorage::try_new(
                master_storage.kind,
                master_storage.id(),
                master_storage.storage_key(),
                master_storage.prv_key_data_ids.clone(),
                master_storage.settings.clone(),
                master_payload,
            )?;
            account_store.store_single(&updated, None).await?;
        }

        self.inner.store.commit(wallet_secret).await?;

        Ok(id)
    }

    pub async fn list_delegations_for_master(&self, anchor: [u8; 32]) -> Result<Vec<(DelegationId, DelegationRecordV1)>> {
        Ok(self.delegation_store().by_anchor(&anchor))
    }

    pub async fn revoke_delegation(self: &Arc<Self>, wallet_secret: &Secret, delegation_id: DelegationId) -> Result<()> {
        let record = self.delegation_store().by_id(delegation_id).ok_or(Error::Custom("delegation not found".to_string()))?;
        let anchor = MasterAnchor::new(record.anchor);
        let master = self.find_active_master_by_anchor(&anchor).ok_or_else(|| Error::Custom("master anchor not found".to_string()))?;

        let current_daa = self.current_daa_score().unwrap_or(0);
        let mut new_record = record.clone();
        new_record.nonce = record.nonce + 1;
        new_record.status = DelegationStatus::Revoked { revoked_daa: current_daa };
        new_record.signature.clear();

        let hash = delegation_message_hash(&new_record)?;
        let signature = master.sign_delegation_hash(&hash).await?;
        new_record.signature = signature.as_bytes().to_vec();

        self.delegation_store().upsert(new_record, None)?;
        MasterMetrics::global().inc_delegations_revoked();
        log_info!(
            "Revoked master delegation: master_anchor={} delegation_id={}",
            crate::account::variants::mldsa_master::format_master_anchor_short(&anchor),
            delegation_id.0
        );

        // Очистить ссылку на делегацию в самом stealth-аккаунте, чтобы UI/метаданные не оставались активными.
        let guard_handle = self.guard();
        let guard = guard_handle.lock().await;
        if let Some(account) = self.get_account_by_id(&record.account_id, &guard).await? {
            let stealth = account.as_stealth_account()?;
            stealth.set_delegation(record.anchor, None);
            let account_store = self.inner.store.clone().as_account_store()?;
            account_store.store_single(&stealth.to_storage()?, None).await?;
        }

        self.save_delegations(wallet_secret).await?;
        self.inner.store.commit(wallet_secret).await?;

        self.notify(Events::MasterDelegationRevoked {
            account_id: record.account_id,
            delegation_id: delegation_id.0,
            anchor: record.anchor,
        })
        .await?;
        Ok(())
    }

    /// Unlocks a stealth account by decrypting and caching the stealth keys.
    /// Returns the stealth address on success.
    pub async fn stealth_account_unlock(
        self: &Arc<Self>,
        account_id: &AccountId,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
    ) -> Result<String> {
        let guard = self.guard();
        let guard = guard.lock().await;
        let account = self.get_account_by_id(account_id, &guard).await?.ok_or(Error::AccountNotFound(*account_id))?;
        let stealth = account.as_stealth_account()?;
        stealth.unlock(wallet_secret, payment_secret).await?;
        Ok(stealth.receive_address()?.to_string())
    }

    /// Locks a stealth account by clearing cached keys from memory.
    pub async fn stealth_account_lock(self: &Arc<Self>, account_id: &AccountId) -> Result<()> {
        let guard = self.guard();
        let guard = guard.lock().await;
        let account = self.get_account_by_id(account_id, &guard).await?.ok_or(Error::AccountNotFound(*account_id))?;
        let stealth = account.as_stealth_account()?;
        stealth.lock().await;
        Ok(())
    }

    pub async fn attach_stealth_to_master(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        stealth_id: &AccountId,
        master_account_id: &AccountId,
        guard: &WalletGuard<'_>,
    ) -> Result<()> {
        let master_account =
            self.get_account_by_id(master_account_id, guard).await?.ok_or(Error::AccountNotFound(*master_account_id))?;
        if master_account.account_kind() != AccountKind::from(MLDSA_MASTER_ACCOUNT_KIND) {
            return Err(Error::InvalidAccountKind);
        }

        let master_storage = master_account.to_storage()?;
        let master_payload = MldsaMasterAccountPayloadV1::try_from_slice(master_storage.serialized.as_slice())?;

        let stealth_account = self.get_account_by_id(stealth_id, guard).await?.ok_or(Error::AccountNotFound(*stealth_id))?;
        let stealth = stealth_account.as_stealth_account()?;

        stealth.attach_to_master(*master_payload.anchor.as_bytes());

        self.inner.store.clone().as_account_store()?.store_single(&stealth.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;
        self.notify(Events::StealthAttachedToMaster {
            stealth_id: *stealth_id,
            master_id: *master_account_id,
            anchor: *master_payload.anchor.as_bytes(),
        })
        .await?;

        Ok(())
    }

    pub async fn detach_stealth_from_master(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        stealth_id: &AccountId,
        guard: &WalletGuard<'_>,
    ) -> Result<()> {
        let stealth_account = self.get_account_by_id(stealth_id, guard).await?.ok_or(Error::AccountNotFound(*stealth_id))?;
        let stealth = stealth_account.as_stealth_account()?;

        stealth.detach_master();

        self.inner.store.clone().as_account_store()?.store_single(&stealth.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;
        self.notify(Events::StealthDetachedFromMaster { stealth_id: *stealth_id }).await?;

        Ok(())
    }

    /// Scans the blockchain for stealth UTXOs belonging to this account.
    /// Returns the number of mature UTXOs found.
    pub async fn stealth_account_scan(self: &Arc<Self>, account_id: &AccountId) -> Result<usize> {
        let guard = self.guard();
        let guard = guard.lock().await;
        let account = self.get_account_by_id(account_id, &guard).await?.ok_or(Error::AccountNotFound(*account_id))?;
        let stealth = account.clone().as_stealth_account()?;
        stealth.clone().scan(None, None).await?;
        Ok(stealth.utxo_context().mature_utxo_size())
    }

    pub async fn create_wallet(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        args: WalletCreateArgs,
    ) -> Result<(WalletDescriptor, StorageDescriptor)> {
        self.close().await?;

        let wallet_descriptor = self.inner.store.create(wallet_secret, args.into()).await?;
        let storage_descriptor = self.inner.store.location()?;
        self.inner.store.commit(wallet_secret).await?;

        self.notify(Events::WalletCreate {
            wallet_descriptor: wallet_descriptor.clone(),
            storage_descriptor: storage_descriptor.clone(),
        })
        .await?;

        Ok((wallet_descriptor, storage_descriptor))
    }

    pub async fn create_prv_key_data(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        prv_key_data_create_args: PrvKeyDataCreateArgs,
    ) -> Result<PrvKeyDataId> {
        let PrvKeyDataCreateArgs { secret, payment_secret, kind, name } = prv_key_data_create_args;
        let (prv_key_data, master_mnemonic) = match kind {
            PrvKeyDataVariantKind::Mnemonic => {
                let mnemonic = Mnemonic::new(secret.as_str()?, Language::default())?;
                let prv =
                    PrvKeyData::try_from_mnemonic(mnemonic.clone(), payment_secret.as_ref(), self.store().encryption_kind()?, name)?;
                (prv, Some(mnemonic))
            }
            PrvKeyDataVariantKind::SecretKey => {
                let secret_key = secp256k1::SecretKey::from_slice(secret.as_ref())?;
                let prv = PrvKeyData::try_from_secret_key(secret_key, payment_secret.as_ref(), self.store().encryption_kind()?, name)?;
                (prv, None)
            }
            _ => {
                return Err(Error::Custom("Invalid prv key data kind, supported types are Mnemonic and SecretKey".to_string()));
            }
        };

        let prv_key_data_info = PrvKeyDataInfo::from(prv_key_data.as_ref());
        let prv_key_data_id = prv_key_data.id;
        let prv_key_data_store = self.inner.store.as_prv_key_data_store()?;
        prv_key_data_store.store(wallet_secret, prv_key_data).await?;

        if let Some(mnemonic) = master_mnemonic.as_ref() {
            if let Err(err) = self.maybe_create_mldsa_master_from_mnemonic(wallet_secret, mnemonic, payment_secret.as_ref()).await {
                log_error!("Unable to derive MLDSA master seed: {err}");
            }
        }

        self.inner.store.commit(wallet_secret).await?;

        self.notify(Events::PrvKeyDataCreate { prv_key_data_info }).await?;

        Ok(prv_key_data_id)
    }

    pub async fn create_wallet_with_accounts(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        wallet_args: WalletCreateArgs,
        account_name: Option<String>,
        account_kind: Option<AccountKind>,
        mnemonic_phrase_word_count: WordCount,
        payment_secret: Option<Secret>,
    ) -> Result<(WalletDescriptor, StorageDescriptor, Mnemonic, Arc<dyn Account>)> {
        self.close().await?;

        let encryption_kind = wallet_args.encryption_kind;
        let wallet_descriptor = self.inner.store.create(wallet_secret, wallet_args.into()).await?;
        let storage_descriptor = self.inner.store.location()?;
        let mnemonic = Mnemonic::random(mnemonic_phrase_word_count, Default::default())?;
        let account_index = 0;
        let prv_key_data = PrvKeyData::try_from_mnemonic(mnemonic.clone(), payment_secret.as_ref(), encryption_kind, None)?;
        let xpub_key = prv_key_data
            .create_xpub(payment_secret.as_ref(), account_kind.unwrap_or(BIP32_ACCOUNT_KIND.into()), account_index)
            .await?;
        let xpub_keys = Arc::new(vec![xpub_key]);

        let account: Arc<dyn Account> =
            Arc::new(bip32::Bip32::try_new(self, account_name, prv_key_data.id, account_index, xpub_keys, false).await?);

        let prv_key_data_store = self.inner.store.as_prv_key_data_store()?;
        prv_key_data_store.store(wallet_secret, prv_key_data).await?;

        if self.is_mldsa_master_enabled() {
            if let Err(err) = self.maybe_create_mldsa_master_from_mnemonic(wallet_secret, &mnemonic, payment_secret.as_ref()).await {
                log_error!("Unable to derive MLDSA master seed: {err}");
            }
        }
        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        self.select(Some(&account)).await?;
        Ok((wallet_descriptor, storage_descriptor, mnemonic, account))
    }

    pub async fn get_account_by_id(
        self: &Arc<Self>,
        account_id: &AccountId,
        _guard: &WalletGuard<'_>,
    ) -> Result<Option<Arc<dyn Account>>> {
        let _guard = self.inner.account_guard.lock().await;

        if let Some(account) = self.active_accounts().get(account_id) {
            Ok(Some(account.clone()))
        } else {
            let account_storage = self.inner.store.as_account_store()?;
            let stored = account_storage.load_single(account_id).await?;
            if let Some((stored_account, stored_metadata)) = stored {
                let account = try_load_account(self, stored_account, stored_metadata).await?;
                Ok(Some(account))
            } else {
                Ok(None)
            }
        }
    }

    pub async fn notify(&self, event: Events) -> Result<()> {
        self.multiplexer()
            .try_broadcast(Box::new(event))
            .map_err(|_| Error::Custom("multiplexer channel error during update_balance".to_string()))?;
        Ok(())
    }

    pub fn is_synced(&self) -> bool {
        self.utxo_processor().is_synced()
    }

    pub fn is_connected(&self) -> bool {
        self.utxo_processor().is_connected()
    }

    pub(crate) async fn handle_discovery(&self, record: TransactionRecord) -> Result<()> {
        let transaction_store = self.store().as_transaction_record_store()?;

        if let Err(_err) = transaction_store.load_single(record.binding(), &self.network_id()?, record.id()).await {
            let transaction_daa_score = record.block_daa_score();
            match self.rpc_api().get_daa_score_timestamp_estimate(vec![transaction_daa_score]).await {
                Ok(timestamps) => {
                    if let Some(timestamp) = timestamps.first() {
                        let mut record = record.clone();
                        record.set_unixtime(*timestamp);

                        transaction_store.store(&[&record]).await?;

                        self.notify(Events::Discovery { record }).await?;
                    } else {
                        self.notify(Events::Error {
                            message: format!(
                                "Unable to obtain DAA to unixtime for DAA {transaction_daa_score}, timestamp data is empty"
                            ),
                        })
                        .await?;
                    }
                }
                Err(err) => {
                    self.notify(Events::Error { message: format!("Unable to resolve DAA to unixtime: {err}") }).await?;
                }
            }
        }

        Ok(())
    }

    async fn handle_wallet_bus(self: &Arc<Self>, message: WalletBusMessage) -> Result<()> {
        match message {
            WalletBusMessage::Discovery { record } => {
                self.handle_discovery(record).await?;
            }
        }
        Ok(())
    }

    async fn handle_event(self: &Arc<Self>, event: Box<Events>) -> Result<()> {
        match &*event {
            Events::Pending { record } | Events::Maturity { record } | Events::Reorg { record } => {
                if !record.is_change() {
                    self.store().as_transaction_record_store()?.store(&[record]).await?;
                }
            }

            _ => {}
        }

        Ok(())
    }

    async fn start_task(self: &Arc<Self>) -> Result<()> {
        let this = self.clone();
        let task_ctl_receiver = self.inner.task_ctl.request.receiver.clone();
        let task_ctl_sender = self.inner.task_ctl.response.sender.clone();
        let events = self.multiplexer().channel();
        let wallet_bus_receiver = self.wallet_bus().receiver.clone();
        let watcher = Arc::new(DelegationExpiryWatcher::new(self.clone()));
        {
            let mut slot = self.inner.delegation_watcher.lock().unwrap();
            *slot = Some(watcher.clone());
        }
        let watcher_events = self.multiplexer().channel();
        let watcher_task_ctl = task_ctl_receiver.clone();
        spawn(async move {
            loop {
                select! {
                    _ = watcher_task_ctl.recv().fuse() => {
                        break;
                    },
                    msg = watcher_events.receiver.recv().fuse() => {
                        match msg {
                            Ok(event) => {
                                if let Events::DaaScoreChange { current_daa_score } = *event {
                                    if let Err(e) = watcher.on_daa_score_change(current_daa_score).await {
                                        log_error!("DelegationExpiryWatcher error: {}", e);
                                    }
                                }
                            }
                            Err(_) => break,
                        }
                    }
                }
            }
        });

        // let this_clone = self.clone();
        // spawn(async move {
        //     loop {
        //         log_info!("Wallet broadcasting ping...");
        //         this_clone.notify(Events::WalletPing).await.expect("Wallet::start_task() `notify` error");
        //         sleep(Duration::from_secs(5)).await;
        //     }
        // });

        spawn(async move {
            loop {
                select! {
                    _ = task_ctl_receiver.recv().fuse() => {
                        break;
                    },

                    msg = events.receiver.recv().fuse() => {
                        match msg {
                            Ok(event) => {
                                this.handle_event(event).await.unwrap_or_else(|e| log_error!("Wallet::handle_event() error: {}", e));
                            },
                            Err(err) => {
                                log_error!("Wallet: error while receiving multiplexer message: {err}");
                                log_error!("Suspending Wallet processing...");

                                break;
                            }
                        }
                    },

                    msg = wallet_bus_receiver.recv().fuse() => {
                        match msg {
                            Ok(message) => {
                                this.handle_wallet_bus(message).await.unwrap_or_else(|e| log_error!("Wallet::handle_wallet_bus() error: {}", e));
                            },
                            Err(err) => {
                                log_error!("Wallet: error while receiving wallet bus message: {err}");
                                log_error!("Suspending Wallet processing...");

                                break;
                            }
                        }
                    }
                }
            }

            let _ = task_ctl_sender.send(()).await;
        });
        Ok(())
    }

    async fn stop_task(&self) -> Result<()> {
        let _ = self.inner.task_ctl.signal(()).await;
        Ok(())
    }

    pub fn enable_metrics_kinds(&self, kinds: &[MetricsUpdateKind]) {
        self.utxo_processor().enable_metrics_kinds(kinds);
    }

    pub fn enable_master_metrics(&self) {
        self.utxo_processor().add_metrics_kinds(&[MetricsUpdateKind::WalletMetrics, MetricsUpdateKind::MasterMetrics]);
    }

    pub async fn start_metrics(&self) -> Result<()> {
        // Всегда публикуем базовые метрики кошелька; при включённом master режиме добавляем и master-метрики.
        self.utxo_processor().add_metrics_kinds(&[MetricsUpdateKind::WalletMetrics]);
        if self.is_mldsa_master_enabled() {
            self.utxo_processor().add_metrics_kinds(&[MetricsUpdateKind::MasterMetrics]);
        }
        self.utxo_processor().start_metrics().await?;
        Ok(())
    }

    pub async fn stop_metrics(&self) -> Result<()> {
        self.utxo_processor().stop_metrics().await?;
        Ok(())
    }

    pub fn is_open(&self) -> bool {
        self.inner.store.is_open()
    }

    pub fn location(&self) -> Result<StorageDescriptor> {
        self.inner.store.location()
    }

    pub async fn exists(&self, name: Option<&str>) -> Result<bool> {
        self.inner.store.exists(name).await
    }

    pub async fn keys(&self) -> Result<impl Stream<Item = Result<Arc<PrvKeyDataInfo>>>> {
        self.inner.store.as_prv_key_data_store()?.iter().await
    }

    pub async fn find_accounts_by_name_or_id(&self, pat: &str) -> Result<Vec<Arc<dyn Account>>> {
        let active_accounts = self.active_accounts().inner().values().cloned().collect::<Vec<_>>();
        let matches = active_accounts
            .into_iter()
            .filter(|account| {
                account.name().map(|name| name.starts_with(pat)).unwrap_or(false) || account.id().to_hex().starts_with(pat)
            })
            .collect::<Vec<_>>();
        Ok(matches)
    }

    pub async fn accounts(
        self: &Arc<Self>,
        filter: Option<PrvKeyDataId>,
        _guard: &WalletGuard<'_>,
    ) -> Result<impl Stream<Item = Result<Arc<dyn Account>>>> {
        let iter = self.inner.store.as_account_store()?.iter(filter).await?;
        let wallet = self.clone();

        let stream = iter.then(move |stored| {
            let wallet = wallet.clone();

            async move {
                let (stored_account, stored_metadata) = stored?;
                if let Some(account) = wallet.legacy_accounts().get(&stored_account.id) {
                    if !wallet.active_accounts().contains(account.id()) {
                        account.clone().start().await?;
                    }
                    Ok(account)
                } else if let Some(account) = wallet.active_accounts().get(&stored_account.id) {
                    Ok(account)
                } else {
                    let account = try_load_account(&wallet, stored_account, stored_metadata).await?;
                    account.clone().start().await?;
                    Ok(account)
                }
            }
        });

        Ok(Box::pin(stream))
    }

    // TODO - remove these comments (these functions are a part of
    // a major refactoring and are temporarily kept here for reference)

    // pub async fn initialize_legacy_accounts(
    //     self: &Arc<Self>,
    //     filter: Option<PrvKeyDataId>,
    //     secret: Secret,
    // ) -> Result<()> {
    //     let mut iter = self.inner.store.as_account_store().unwrap().iter(filter).await.unwrap();
    //     let wallet = self.clone();

    //     while let Some((stored_account, stored_metadata)) = iter.try_next().await? {
    //         if matches!(stored_account.data, AccountData::Legacy { .. }) {

    //             let account = try_from_storage(&wallet, stored_account, stored_metadata).await?;

    //                 account.clone().initialize_private_data(secret.clone(), None, None).await?;
    //                 wallet.legacy_accounts().insert(account.clone());
    //                 // account.clone().start().await?;

    //             // if is_legacy {
    //                 // let derivation = account.clone().as_derivation_capable()?.derivation();
    //                 // let m = derivation.receive_address_manager();
    //                 // m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
    //                 // let m = derivation.change_address_manager();
    //                 // m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;

    //                 // - TODO - consider two-phase approach
    //                 // account.clone().clear_private_data().await?;
    //             // }
    //         }
    //     }

    //     Ok(())

    // // let stream = iter.then(move |stored| {
    //     let wallet = wallet.clone();
    //     let secret = secret.clone();

    //     // async move {
    //         let (stored_account, stored_metadata) = stored.unwrap();
    //         // if let Some(account) = wallet.active_accounts().get(&stored_account.id) {
    //             // Ok(account)
    //         // } else {
    //             if matches!(stored_account.data, AccountData::Legacy { .. }) {

    //                 let account = try_from_storage(&wallet, stored_account, stored_metadata).await?;

    //                 // if is_legacy {
    //                     account.clone().initialize_private_data(secret, None, None).await?;
    //                     wallet.legacy_accounts().insert(account.clone());
    //                 // }

    //                 // account.clone().start().await?;

    //                 // if is_legacy {
    //                     let derivation = account.clone().as_derivation_capable()?.derivation();
    //                     let m = derivation.receive_address_manager();
    //                     m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
    //                     let m = derivation.change_address_manager();
    //                     m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
    //                     account.clone().clear_private_data().await?;
    //                 // }
    //             }

    // Ok(account)
    // }
    // }
    // });
    // Ok(Box::pin(stream))
    // }

    // pub async fn initialize_accounts(
    //     self: &Arc<Self>,
    //     filter: Option<PrvKeyDataId>,
    //     secret: Secret,
    // ) -> Result<impl Stream<Item = Result<Arc<dyn Account>>>> {
    //     let iter = self.inner.store.as_account_store().unwrap().iter(filter).await.unwrap();
    //     let wallet = self.clone();

    //     let stream = iter.then(move |stored| {
    //         let wallet = wallet.clone();
    //         let secret = secret.clone();

    //         async move {
    //             let (stored_account, stored_metadata) = stored.unwrap();
    //             if let Some(account) = wallet.active_accounts().get(&stored_account.id) {
    //                 Ok(account)
    //             } else {
    //                 let is_legacy = matches!(stored_account.data, AccountData::Legacy { .. });
    //                 let account = try_from_storage(&wallet, stored_account, stored_metadata).await?;

    //                 if is_legacy {
    //                     account.clone().initialize_private_data(secret, None, None).await?;
    //                     wallet.legacy_accounts().insert(account.clone());
    //                 }

    //                 // account.clone().start().await?;

    //                 if is_legacy {
    //                     let derivation = account.clone().as_derivation_capable()?.derivation();
    //                     let m = derivation.receive_address_manager();
    //                     m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
    //                     let m = derivation.change_address_manager();
    //                     m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
    //                     account.clone().clear_private_data().await?;
    //                 }

    //                 Ok(account)
    //             }
    //         }
    //     });

    //     Ok(Box::pin(stream))
    // }

    pub async fn import_kaspawallet_golang_single_v1<T: AsRef<[u8]>>(
        self: &Arc<Wallet>,
        import_secret: &Secret,
        wallet_secret: &Secret,
        file: SingleWalletFileV1<'_, T>,
    ) -> Result<Arc<dyn Account>> {
        if file.ecdsa {
            return Err(Error::Custom("ecdsa currently not suppoerted".to_owned()));
            // todo import_with_mnemonic should accept both
        }
        let mnemonic = decrypt_mnemonic(SingleWalletFileV1::<T>::NUM_THREADS, file.encrypted_mnemonic, import_secret.as_ref())?;
        let mnemonic = Mnemonic::new(mnemonic.trim(), Language::English)?;
        let prv_key_data = storage::PrvKeyData::try_new_from_mnemonic(mnemonic.clone(), None, self.store().encryption_kind()?)?;
        let prefix = file
            .xpublic_key
            .get(..kaspa_bip32::Prefix::LENGTH)
            .ok_or_else(|| Error::Custom("invalid xpublic_key prefix".to_owned()))?;
        let prefix = kaspa_bip32::Prefix::try_from(prefix)?;

        if prv_key_data.create_xpub(None, BIP32_ACCOUNT_KIND.into(), 0).await?.to_string(Some(prefix)) != file.xpublic_key {
            return Err(Custom("imported xpub does not equal derived one".to_owned()));
        }
        self.import_with_mnemonic(wallet_secret, None, mnemonic, BIP32_ACCOUNT_KIND.into()).await
    }

    pub async fn import_kaspawallet_golang_single_v0<T: AsRef<[u8]>>(
        self: &Arc<Wallet>,
        import_secret: &Secret,
        wallet_secret: &Secret,
        file: SingleWalletFileV0<'_, T>,
    ) -> Result<Arc<dyn Account>> {
        if file.ecdsa {
            return Err(Error::Custom("ecdsa currently not suppoerted".to_owned()));
            // todo import_with_mnemonic should accept both
        }
        let mnemonic = decrypt_mnemonic(file.num_threads, file.encrypted_mnemonic, import_secret.as_ref())?;
        let mnemonic = Mnemonic::new(mnemonic.trim(), Language::English)?;
        let prv_key_data = storage::PrvKeyData::try_new_from_mnemonic(mnemonic.clone(), None, self.store().encryption_kind()?)?;
        let prefix = file
            .xpublic_key
            .get(..kaspa_bip32::Prefix::LENGTH)
            .ok_or_else(|| Error::Custom("invalid xpublic_key prefix".to_owned()))?;
        let prefix = kaspa_bip32::Prefix::try_from(prefix)?;
        if prv_key_data.create_xpub(None, BIP32_ACCOUNT_KIND.into(), 0).await?.to_string(Some(prefix)) != file.xpublic_key {
            return Err(Custom("imported xpub does not equal derived one".to_owned()));
        }
        self.import_with_mnemonic(wallet_secret, None, mnemonic, BIP32_ACCOUNT_KIND.into()).await
    }

    pub async fn import_kaspawallet_golang_multisig_v0<T: AsRef<[u8]>>(
        self: &Arc<Wallet>,
        import_secret: &Secret,
        wallet_secret: &Secret,
        file: MultisigWalletFileV0<'_, T>,
    ) -> Result<Arc<dyn Account>> {
        if file.ecdsa {
            return Err(Error::Custom("ecdsa currently not suppoerted".to_owned()));
            // todo import_with_mnemonic should accept both
        }
        let Some(first_pub_key) = file.xpublic_keys.first() else {
            return Err(Error::Custom("no public keys".to_owned()));
        };
        if first_pub_key.get(..kaspa_bip32::Prefix::LENGTH).is_none() {
            return Err(Error::Custom("invalid xpublic_key prefix".to_owned()));
        }
        if file.xpublic_keys.iter().any(|k| k.get(..kaspa_bip32::Prefix::LENGTH).is_none()) {
            return Err(Error::Custom("invalid xpublic_key prefix".to_owned()));
        }
        let prefix =
            first_pub_key.get(..kaspa_bip32::Prefix::LENGTH).ok_or_else(|| Error::Custom("invalid xpublic_key prefix".to_owned()))?;
        let prefix = kaspa_bip32::Prefix::try_from(prefix)?;

        let mnemonics_and_secrets: Vec<(Mnemonic, Option<Secret>)> = file
            .encrypted_mnemonics
            .into_iter()
            .map(|mnemonic| {
                decrypt_mnemonic(file.num_threads, mnemonic, import_secret.as_ref())
                    .and_then(|decrypted| Mnemonic::new(decrypted.trim(), Language::English).map_err(Error::from))
            })
            .map(|r| r.map(|m| (m, <Option<Secret>>::None)))
            .collect::<Result<Vec<(Mnemonic, Option<Secret>)>>>()?;

        let mut all_pub_keys = file.xpublic_keys;
        all_pub_keys.sort_unstable();

        let mut pubkeys_from_mnemonics = Vec::with_capacity(mnemonics_and_secrets.len());
        for (mnemonic, _) in mnemonics_and_secrets.iter() {
            let priv_key = storage::PrvKeyData::try_new_from_mnemonic(mnemonic.clone(), None, self.store().encryption_kind()?)?;
            let xpub_key = priv_key.create_xpub(None, BIP32_ACCOUNT_KIND.into(), 0).await?.to_string(Some(prefix));
            pubkeys_from_mnemonics.push(xpub_key);
        }
        pubkeys_from_mnemonics.sort_unstable();
        all_pub_keys.retain(|v| pubkeys_from_mnemonics.binary_search_by_key(v, |xpub| xpub.as_str()).is_err());
        let additional_pub_keys = all_pub_keys.into_iter().map(String::from).collect();
        self.import_multisig_with_mnemonic(wallet_secret, mnemonics_and_secrets, file.required_signatures, additional_pub_keys).await
    }

    pub async fn import_kaspawallet_golang_multisig_v1<T: AsRef<[u8]>>(
        self: &Arc<Wallet>,
        import_secret: &Secret,
        wallet_secret: &Secret,
        file: MultisigWalletFileV1<'_, T>,
    ) -> Result<Arc<dyn Account>> {
        if file.ecdsa {
            return Err(Error::Custom("ecdsa currently not suppoerted".to_owned()));
            // todo import_with_mnemonic should accept both
        }
        let Some(first_pub_key) = file.xpublic_keys.first() else {
            return Err(Error::Custom("no public keys".to_owned()));
        };
        if first_pub_key.get(..kaspa_bip32::Prefix::LENGTH).is_none() {
            return Err(Error::Custom("invalid xpublic_key prefix".to_owned()));
        }
        if file.xpublic_keys.iter().any(|k| k.get(..kaspa_bip32::Prefix::LENGTH).is_none()) {
            return Err(Error::Custom("invalid xpublic_key prefix".to_owned()));
        }
        let prefix =
            first_pub_key.get(..kaspa_bip32::Prefix::LENGTH).ok_or_else(|| Error::Custom("invalid xpublic_key prefix".to_owned()))?;
        let prefix = kaspa_bip32::Prefix::try_from(prefix)?;

        let mnemonics_and_secrets: Vec<(Mnemonic, Option<Secret>)> = file
            .encrypted_mnemonics
            .into_iter()
            .map(|mnemonic| {
                decrypt_mnemonic(MultisigWalletFileV1::<T>::NUM_THREADS, mnemonic, import_secret.as_ref())
                    .and_then(|decrypted| Mnemonic::new(decrypted.trim(), Language::English).map_err(Error::from))
            })
            .map(|r| r.map(|m| (m, <Option<Secret>>::None)))
            .collect::<Result<Vec<(Mnemonic, Option<Secret>)>>>()?;

        let mut all_pub_keys = file.xpublic_keys;
        all_pub_keys.sort_unstable_by(|left, right| {
            left.get(kaspa_bip32::Prefix::LENGTH..)
                .unwrap_or_default()
                .cmp(right.get(kaspa_bip32::Prefix::LENGTH..).unwrap_or_default())
        });

        let mut pubkeys_from_mnemonics = Vec::with_capacity(mnemonics_and_secrets.len());
        for (mnemonic, _) in mnemonics_and_secrets.iter() {
            let priv_key = storage::PrvKeyData::try_new_from_mnemonic(mnemonic.clone(), None, self.store().encryption_kind()?)?;
            let xpub_key = priv_key.create_xpub(None, MULTISIG_ACCOUNT_KIND.into(), 0).await?.to_string(Some(prefix));
            pubkeys_from_mnemonics.push(xpub_key);
        }
        pubkeys_from_mnemonics.sort_unstable_by(|left, right| {
            left.get(kaspa_bip32::Prefix::LENGTH..)
                .unwrap_or_default()
                .cmp(right.get(kaspa_bip32::Prefix::LENGTH..).unwrap_or_default())
        });
        all_pub_keys.retain(|v| {
            let found = pubkeys_from_mnemonics.binary_search_by_key(v, |xpub| xpub.as_str());
            found.is_err()
        });
        let additional_pub_keys = all_pub_keys.into_iter().map(String::from).collect();
        let acc = self
            .import_multisig_with_mnemonic(wallet_secret, mnemonics_and_secrets, file.required_signatures, additional_pub_keys)
            .await?;
        Ok(acc)
    }

    pub async fn import_legacy_keydata(
        self: &Arc<Wallet>,
        import_secret: &Secret,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        notifier: Option<ScanNotifier>,
    ) -> Result<Arc<dyn Account>> {
        use crate::compat::gen0::load_v0_keydata;

        let notifier = notifier.as_ref();
        let keydata = load_v0_keydata(import_secret).await?;

        let mnemonic = Mnemonic::new(keydata.mnemonic.trim(), Language::English)?;
        let prv_key_data = PrvKeyData::try_new_from_mnemonic(mnemonic, payment_secret, self.store().encryption_kind()?)?;
        let prv_key_data_store = self.inner.store.as_prv_key_data_store()?;
        if prv_key_data_store.load_key_data(wallet_secret, &prv_key_data.id).await?.is_some() {
            return Err(Error::PrivateKeyAlreadyExists(prv_key_data.id));
        }

        let account: Arc<dyn Account> = Arc::new(legacy::Legacy::try_new(self, None, prv_key_data.id).await?);

        // activate account (add it to wallet active account list)
        self.active_accounts().insert(account.clone().as_dyn_arc());
        self.legacy_accounts().insert(account.clone().as_dyn_arc());

        // store private key and account
        self.inner.store.batch().await?;
        prv_key_data_store.store(wallet_secret, prv_key_data).await?;
        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        self.inner.store.flush(wallet_secret).await?;

        let legacy_account = account.clone().as_legacy_account()?;
        legacy_account.create_private_context(wallet_secret, payment_secret, None).await?;

        if self.is_connected() {
            if let Some(notifier) = notifier {
                notifier(0, 0, 0, None);
            }
            account.clone().scan(Some(100), Some(5000)).await?;
        }

        legacy_account.clear_private_context().await?;

        Ok(account)
    }

    pub async fn import_gen1_keydata(self: &Arc<Wallet>, _secret: Secret) -> Result<()> {
        // use crate::derivation::gen1::import::load_v1_keydata;

        // let _keydata = load_v1_keydata(&secret).await?;
        todo!();
        // Ok(())
    }

    pub async fn import_with_mnemonic(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        mnemonic: Mnemonic,
        account_kind: AccountKind,
    ) -> Result<Arc<dyn Account>> {
        let mnemonic_for_master = mnemonic.clone();
        let prv_key_data = storage::PrvKeyData::try_new_from_mnemonic(mnemonic, payment_secret, self.store().encryption_kind()?)?;
        let prv_key_data_store = self.store().as_prv_key_data_store()?;
        if prv_key_data_store.load_key_data(wallet_secret, &prv_key_data.id).await?.is_some() {
            return Err(Error::PrivateKeyAlreadyExists(prv_key_data.id));
        }
        // let mut is_legacy = false;
        let account: Arc<dyn Account> = match account_kind.as_ref() {
            BIP32_ACCOUNT_KIND => {
                let account_index = 0;
                let xpub_key = prv_key_data.create_xpub(payment_secret, account_kind, account_index).await?;
                let xpub_keys = Arc::new(vec![xpub_key]);
                let ecdsa = false;
                // ---
                Arc::new(bip32::Bip32::try_new(self, None, prv_key_data.id, account_index, xpub_keys, ecdsa).await?)
            }
            LEGACY_ACCOUNT_KIND => Arc::new(legacy::Legacy::try_new(self, None, prv_key_data.id).await?),
            _ => {
                return Err(Error::AccountKindFeature);
            }
        };

        let account_store = self.inner.store.as_account_store()?;
        self.inner.store.batch().await?;
        account_store.store_single(&account.to_storage()?, None).await?;
        self.inner.store.flush(wallet_secret).await?;

        if let Err(err) = self.maybe_create_mldsa_master_from_mnemonic(wallet_secret, &mnemonic_for_master, payment_secret).await {
            log_error!("Unable to derive MLDSA master seed: {err}");
        }

        if let Ok(legacy_account) = account.clone().as_legacy_account() {
            self.legacy_accounts().insert(account.clone());
            legacy_account.create_private_context(wallet_secret, None, None).await?;
            legacy_account.clone().start().await?;
            legacy_account.clear_private_context().await?;
        } else {
            account.clone().start().await?;
        }

        // if is_legacy {
        //     account.clone().initialize_private_data(wallet_secret, None, None).await?;
        //     self.legacy_accounts().insert(account.clone());
        // }
        // account.clone().start().await?;
        // if is_legacy {
        //     let derivation = account.clone().as_derivation_capable()?.derivation();
        //     let m = derivation.receive_address_manager();
        //     m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
        //     let m = derivation.change_address_manager();
        //     m.get_range(0..(m.index() + CACHE_ADDRESS_OFFSET))?;
        //     account.clone().clear_private_data().await?;
        // }

        Ok(account)
    }

    /// Perform a "2d" scan of account derivations while scanning addresses
    /// in each account (UTXOs up to `address_scan_extent` address derivation).
    /// Report back the last account index that has UTXOs. The scan is performed
    /// until we have encountered at least `account_scan_extent` of empty
    /// accounts.
    pub async fn scan_bip44_accounts(
        self: &Arc<Self>,
        bip39_mnemonic: Secret,
        bip39_passphrase: Option<Secret>,
        address_scan_extent: u32,
        account_scan_extent: u32,
    ) -> Result<u32> {
        let bip39_mnemonic = std::str::from_utf8(bip39_mnemonic.as_ref()).map_err(|_| Error::InvalidMnemonicPhrase)?;
        let mnemonic = Mnemonic::new(bip39_mnemonic, Language::English)?;

        // TODO @aspect - this is not efficient, we need to scan without encrypting prv_key_data
        let prv_key_data =
            storage::PrvKeyData::try_new_from_mnemonic(mnemonic, bip39_passphrase.as_ref(), EncryptionKind::XChaCha20Poly1305)?;

        let mut last_account_index = 0;
        let mut account_index = 0;

        while account_index < last_account_index + account_scan_extent {
            let xpub_key =
                prv_key_data.create_xpub(bip39_passphrase.as_ref(), BIP32_ACCOUNT_KIND.into(), account_index as u64).await?;
            let xpub_keys = Arc::new(vec![xpub_key]);
            let ecdsa = false;
            // ---

            let addresses = bip32::Bip32::try_new(self, None, prv_key_data.id, account_index as u64, xpub_keys, ecdsa)
                .await?
                .get_address_range_for_scan(0..address_scan_extent)?;
            if self.rpc_api().get_utxos_by_addresses(addresses).await?.is_not_empty() {
                last_account_index = account_index;
            }
            account_index += 1;
        }

        Ok(last_account_index)
    }

    pub async fn import_multisig_with_mnemonic(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        mnemonics_secrets: Vec<(Mnemonic, Option<Secret>)>,
        minimum_signatures: u16,
        additional_xpub_keys: Vec<String>,
    ) -> Result<Arc<dyn Account>> {
        let mut additional_xpub_keys = additional_xpub_keys
            .into_iter()
            .map(|xpub| {
                ExtendedKey::from_str(&xpub).map(|mut xpub| {
                    xpub.prefix = KeyPrefix::XPUB;
                    xpub.to_string()
                })
            })
            .collect::<Result<Vec<_>, kaspa_bip32::Error>>()?;

        let mut generated_xpubs = Vec::with_capacity(mnemonics_secrets.len());
        let mut prv_key_data_ids = Vec::with_capacity(mnemonics_secrets.len());
        let prv_key_data_store = self.store().as_prv_key_data_store()?;

        for (mnemonic, payment_secret) in mnemonics_secrets {
            let mnemonic_for_master = mnemonic.clone();
            let prv_key_data =
                storage::PrvKeyData::try_new_from_mnemonic(mnemonic, payment_secret.as_ref(), self.store().encryption_kind()?)?;
            if prv_key_data_store.load_key_data(wallet_secret, &prv_key_data.id).await?.is_some() {
                return Err(Error::PrivateKeyAlreadyExists(prv_key_data.id));
            }
            let xpub_key = prv_key_data.create_xpub(payment_secret.as_ref(), MULTISIG_ACCOUNT_KIND.into(), 0).await?; // todo it can be done concurrently
            generated_xpubs.push(xpub_key.to_string(Some(KeyPrefix::XPUB)));
            prv_key_data_ids.push(prv_key_data.id);
            prv_key_data_store.store(wallet_secret, prv_key_data).await?;

            if let Err(err) =
                self.maybe_create_mldsa_master_from_mnemonic(wallet_secret, &mnemonic_for_master, payment_secret.as_ref()).await
            {
                log_error!("Unable to derive MLDSA master seed: {err}");
            }
        }

        generated_xpubs.sort_unstable();
        additional_xpub_keys.extend_from_slice(generated_xpubs.as_slice());
        let mut xpub_keys = additional_xpub_keys;
        xpub_keys.sort_unstable();

        let min_cosigner_index =
            generated_xpubs.first().and_then(|first_generated| xpub_keys.binary_search(first_generated).ok()).map(|v| v as u8);

        let xpub_keys = xpub_keys
            .into_iter()
            .map(|xpub_key| {
                ExtendedPublicKeySecp256k1::from_str(&xpub_key).map_err(|err| Error::InvalidExtendedPublicKey(xpub_key, err))
            })
            .collect::<Result<Vec<_>>>()?;

        let account: Arc<dyn Account> = Arc::new(
            multisig::MultiSig::try_new(
                self,
                None,
                Arc::new(xpub_keys),
                Some(Arc::new(prv_key_data_ids)),
                min_cosigner_index,
                minimum_signatures,
                false,
            )
            .await?,
        );

        self.inner.store.clone().as_account_store()?.store_single(&account.to_storage()?, None).await?;
        account.clone().start().await?;

        Ok(account)
    }

    fn is_mldsa_master_enabled(&self) -> bool {
        self.settings().get(WalletSettings::EnableMldsaMaster).unwrap_or(true)
    }

    async fn maybe_create_mldsa_master_from_mnemonic(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        mnemonic: &Mnemonic,
        payment_secret: Option<&Secret>,
    ) -> Result<Option<PrvKeyDataId>> {
        if !self.is_mldsa_master_enabled() {
            return Ok(None);
        }

        if let Some((network_enabled, activation_daa)) = self.fetch_mldsa_master_network_status().await? {
            self.observe_mldsa_master_network_status(network_enabled, activation_daa).await?;
            if !network_enabled {
                log_warn!(
                    "Skipping automatic MLDSA master derivation: network master flag is disabled (activation_daa={activation_daa:?})"
                );
                return Ok(None);
            }
        }

        let passphrase = payment_secret
            .map(|secret| std::str::from_utf8(secret.as_ref()).map(|s| s.to_owned()))
            .transpose()
            .map_err(|_| Error::Custom("Invalid BIP39 passphrase encoding".to_string()))?;
        let passphrase_ref = passphrase.as_deref().unwrap_or("");
        let seed = mnemonic.to_seed(passphrase_ref);
        let mut root_seed = Zeroizing::new(seed.as_bytes().to_vec());
        drop(seed);

        let level = MlDsaLevel::Level2;
        let (_pair, anchor, master_seed) = MlDsaKeypair::from_bip39_root_seed(root_seed.as_slice(), 0, level)
            .map_err(|err| Error::Custom(format!("Failed to derive MLDSA master seed: {err}")))?;
        root_seed.zeroize();

        let mut master_seed_bytes = master_seed.into_bytes();
        let seed_cipher = encrypt_xchacha20poly1305(&master_seed_bytes, wallet_secret)?;
        master_seed_bytes.zeroize();

        let mut master_prv = storage::PrvKeyData::try_new_mldsa_master(MlDsaMasterPayload::new(level, anchor, seed_cipher))?;
        master_prv.name = Some(format!("mldsa-master:{}", anchor));
        let master_id = master_prv.id;

        let prv_key_data_store = self.inner.store.as_prv_key_data_store()?;
        if prv_key_data_store.load_key_data(wallet_secret, &master_id).await?.is_some() {
            return Ok(None);
        }

        let master_info = PrvKeyDataInfo::from(master_prv.as_ref());
        let anchor_hex = master_info.anchor.as_ref().map(|anchor| anchor.to_vec().to_hex());
        let anchor_info = MasterAnchorInfo {
            id: master_info.id,
            anchor: anchor_hex,
            level: master_info.level,
            is_encrypted: master_info.is_encrypted,
        };
        prv_key_data_store.store(wallet_secret, master_prv).await?;
        self.notify(Events::PrvKeyDataCreate { prv_key_data_info: master_info }).await?;
        self.notify(Events::MasterAnchorCreated { info: anchor_info }).await?;

        Ok(Some(master_id))
    }

    async fn hydrate_mldsa_masters(self: &Arc<Self>, wallet_secret: &Secret) -> Result<bool> {
        if !self.is_mldsa_master_enabled() {
            return Ok(false);
        }

        let prv_key_data_store = self.inner.store.as_prv_key_data_store()?;
        let prv_key_data_list = prv_key_data_store.iter().await?.try_collect::<Vec<_>>().await?;
        let mut created = false;

        for info in prv_key_data_list {
            if info.kind == PrvKeyDataVariantKind::MlDsaMaster {
                continue;
            }

            let Some(prv_key_data) = prv_key_data_store.load_key_data(wallet_secret, &info.id).await? else {
                continue;
            };

            if prv_key_data.is_payload_encrypted() {
                continue;
            }

            if let Some(mnemonic) = prv_key_data.as_mnemonic(None)? {
                match self.maybe_create_mldsa_master_from_mnemonic(wallet_secret, &mnemonic, None).await {
                    Ok(Some(_)) => created = true,
                    Ok(None) => (),
                    Err(err) => log_error!("Unable to derive MLDSA master seed: {err}"),
                }
            }
        }

        Ok(created)
    }

    async fn fetch_mldsa_master_network_status(&self) -> Result<Option<(bool, Option<u64>)>> {
        let Some(rpc) = self.utxo_processor().try_rpc_api() else {
            return Ok(None);
        };

        match rpc.get_server_info().await {
            Ok(info) => Ok(Some((info.mldsa_master_enabled, info.mldsa_master_activation_daa))),
            Err(err) => {
                log_warn!("Unable to read mldsa_master status from RPC: {err}");
                Ok(None)
            }
        }
    }

    async fn observe_mldsa_master_network_status(&self, network_enabled: bool, activation_daa: Option<u64>) -> Result<()> {
        self.notify(Events::MasterNetworkStatus { enabled: network_enabled, activation_daa }).await?;

        let local_enabled = self.is_mldsa_master_enabled();
        if local_enabled && !network_enabled {
            self.notify(Events::MasterNetworkMismatch { local_enabled, network_enabled }).await?;
        }

        Ok(())
    }

    pub async fn master_anchor_infos(&self) -> Result<Vec<MasterAnchorInfo>> {
        let store = self.inner.store.as_prv_key_data_store()?;
        let infos = store.iter().await?.try_collect::<Vec<_>>().await?;
        let anchors = infos
            .into_iter()
            .filter(|info| info.kind == PrvKeyDataVariantKind::MlDsaMaster)
            .map(|info| MasterAnchorInfo {
                id: info.id,
                anchor: info.anchor.map(|anchor| anchor.to_vec().to_hex()),
                level: info.level,
                is_encrypted: info.is_encrypted,
            })
            .collect();
        Ok(anchors)
    }

    pub async fn export_master_seed_hex(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        master_id: &PrvKeyDataId,
        confirmation: &str,
    ) -> Result<String> {
        if confirmation.trim().to_uppercase() != "EXPORT" {
            return Err(Error::Custom("Master seed export requires typing 'EXPORT' as confirmation".to_string()));
        }

        let store = self.inner.store.as_prv_key_data_store()?;
        let master = store.load_key_data(wallet_secret, master_id).await?.ok_or(Error::PrivateKeyNotFound(*master_id))?;
        let payload =
            master.as_mldsa_master(None)?.ok_or_else(|| Error::Custom("Specified key is not an MLDSA master record".to_string()))?;

        let anchor_hex = payload.anchor().to_string();
        let seed = payload.decrypt_seed(wallet_secret)?;
        let seed_hex = seed.to_hex();

        self.notify(Events::MasterSeedExported { master_id: *master_id, anchor: Some(anchor_hex) }).await?;

        Ok(seed_hex)
    }

    async fn rename(&self, title: Option<String>, filename: Option<String>, wallet_secret: &Secret) -> Result<()> {
        let store = self.store();
        store.rename(wallet_secret, title.as_deref(), filename.as_deref()).await?;
        Ok(())
    }

    async fn ensure_default_account_impl(
        self: Arc<Self>,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        kind: AccountKind,
        mnemonic_phrase: Option<&Secret>,
        guard: &WalletGuard<'_>,
    ) -> Result<AccountDescriptor> {
        if kind != BIP32_ACCOUNT_KIND {
            return Err(Error::custom("Account kind is not supported"));
        }

        let account = self.store().as_account_store()?.iter(None).await?.next().await;

        if let Some(Ok((stored_account, stored_metadata))) = account {
            let account_descriptor = try_load_account(&self, stored_account, stored_metadata).await?.descriptor()?;
            Ok(account_descriptor)
        } else {
            let mnemonic_phrase_string = if let Some(phrase) = mnemonic_phrase.cloned() {
                phrase
            } else {
                let mnemonic = Mnemonic::random(WordCount::Words24, Language::English)?;
                Secret::from(mnemonic.phrase_string())
            };

            let prv_key_data_args =
                PrvKeyDataCreateArgs::new(None, payment_secret.cloned(), mnemonic_phrase_string, PrvKeyDataVariantKind::Mnemonic);

            self.store().batch().await?;
            let prv_key_data_id = self.clone().create_prv_key_data(wallet_secret, prv_key_data_args).await?;

            let account_create_args = AccountCreateArgs::new_bip32(prv_key_data_id, payment_secret.cloned(), None, None);

            let account = self.clone().create_account(wallet_secret, account_create_args, false, guard).await?;

            self.store().flush(wallet_secret).await?;

            Ok(account.descriptor()?)
        }
    }

    pub fn network_format_xpub(&self, xpub_key: &ExtendedPublicKeySecp256k1) -> String {
        NetworkTaggedXpub::from((xpub_key.clone(), self.network_id().unwrap())).to_string()
    }
}

fn ensure_request_versions(request: &MasterDelegationRequestBodyV1) -> Result<()> {
    if request.version != 1 && request.version != 2 {
        return Err(Error::MasterDelegationUnsupportedVersion { context: "request", expected: 1, found: request.version });
    }
    for header in &request.delegations {
        if header.version != 1 && header.version != 2 {
            return Err(Error::MasterDelegationUnsupportedVersion { context: "header", expected: 1, found: header.version });
        }
    }
    Ok(())
}

fn ensure_response_versions(response: &MasterDelegationResponseBodyV1) -> Result<()> {
    if response.version != 1 && response.version != 2 {
        return Err(Error::MasterDelegationUnsupportedVersion { context: "response", expected: 1, found: response.version });
    }
    for record in &response.delegations {
        if record.version != 1 && record.version != 2 {
            return Err(Error::MasterDelegationUnsupportedVersion { context: "delegation", expected: 1, found: record.version });
        }
    }
    Ok(())
}

// fn decrypt_mnemonic<T: AsRef<[u8]>>(
//     num_threads: u32,
//     EncryptedMnemonic { cipher, salt }: EncryptedMnemonic<T>,
//     pass: &[u8],
// ) -> Result<String> {
//     let params = argon2::ParamsBuilder::new().t_cost(1).m_cost(64 * 1024).p_cost(num_threads).output_len(32).build().unwrap();
//     let mut key = [0u8; 32];
//     argon2::Argon2::new(argon2::Algorithm::Argon2id, Default::default(), params)
//         .hash_password_into(pass, salt.as_ref(), &mut key[..])
//         .unwrap();
//     let mut aead = chacha20poly1305::XChaCha20Poly1305::new(Key::from_slice(&key));
//     let (nonce, ciphertext) = cipher.as_ref().split_at(24);

//     let decrypted = aead.decrypt(nonce.into(), ciphertext).unwrap();
//     Ok(unsafe { String::from_utf8_unchecked(decrypted) })
// }

#[cfg(not(target_arch = "wasm32"))]
#[cfg(test)]
mod test {
    // use hex_literal::hex;

    // use super::*;
    // use kaspa_addresses::Address;

    /*
    use workflow_rpc::client::ConnectOptions;
    use std::{str::FromStr, thread::sleep, time};
    use crate::derivation::gen1;
    use crate::utxo::{UtxoContext, UtxoContextBinding, UtxoIterator};
    use kaspa_addresses::{Prefix, Version};
    use kaspa_bip32::{ChildNumber, ExtendedPrivateKey, SecretKey};
    use kaspa_consensus_core::subnets::SUBNETWORK_ID_NATIVE;
    use kaspa_consensus_wasm::{sign_transaction, SignableTransaction, Transaction, TransactionInput, TransactionOutput};
    use kaspa_txscript::pay_to_address_script;

    async fn create_utxos_context_with_addresses(
        rpc: Arc<DynRpcApi>,
        addresses: Vec<Address>,
        current_daa_score: u64,
        core: &UtxoProcessor,
    ) -> Result<UtxoContext> {
        let utxos = rpc.get_utxos_by_addresses(addresses).await?;
        let utxo_context = UtxoContext::new(core, UtxoContextBinding::default());
        let entries = utxos.into_iter().map(|entry| entry.into()).collect::<Vec<_>>();
        for entry in entries.into_iter() {
            utxo_context.insert(entry, current_daa_score, false).await?;
        }
        Ok(utxo_context)
    }

    #[allow(dead_code)]
    // #[tokio::test]
    async fn wallet_test() -> Result<()> {
        println!("Creating wallet...");
        let resident_store = Wallet::resident_store()?;
        let wallet = Arc::new(Wallet::try_new(resident_store, None)?);

        let rpc_api = wallet.rpc_api();
        let utxo_processor = wallet.utxo_processor();

        let wrpc_client = wallet.wrpc_client().expect("Unable to obtain wRPC client");

        let info = rpc_api.get_block_dag_info().await?;
        let current_daa_score = info.virtual_daa_score;

        let _connect_result = wrpc_client.connect(ConnectOptions::fallback()).await;
        //println!("connect_result: {_connect_result:?}");

        let _result = wallet.start().await;
        //println!("wallet.task(): {_result:?}");
        let result = wallet.get_info().await;
        println!("wallet.get_info(): {result:#?}");

        let address = Address::try_from("kaspatest:qz7ulu4c25dh7fzec9zjyrmlhnkzrg4wmf89q7gzr3gfrsj3uz6xjceef60sd")?;

        let utxo_context =
            self::create_utxos_context_with_addresses(rpc_api.clone(), vec![address.clone()], current_daa_score, utxo_processor)
                .await?;

        let utxo_set_balance = utxo_context.calculate_balance().await;
        println!("get_utxos_by_addresses: {utxo_set_balance:?}");

        let to_address = Address::try_from("kaspatest:qpakxqlesqywgkq7rg4wyhjd93kmw7trkl3gpa3vd5flyt59a43yyn8vu0w8c")?;
        let mut iter = UtxoIterator::new(&utxo_context);
        let utxo = iter.next().unwrap();
        let utxo = (*utxo.utxo).clone();
        let selected_entries = vec![utxo];

        let entries = &selected_entries;

        let inputs = selected_entries
            .iter()
            .enumerate()
            .map(|(sequence, utxo)| TransactionInput::new(utxo.outpoint.clone(), vec![], sequence as u64, 0))
            .collect::<Vec<TransactionInput>>();

        let tx = Transaction::new(
            0,
            inputs,
            vec![TransactionOutput::new(1000, &pay_to_address_script(&to_address))],
            0,
            SUBNETWORK_ID_NATIVE,
            0,
            vec![],
        )?;

        let mtx = SignableTransaction::new(tx, (*entries).clone().into());

        let derivation_path =
            gen1::WalletDerivationManager::build_derivate_path(false, 0, None, Some(kaspa_bip32::AddressType::Receive))?;

        let xprv = "kprv5y2qurMHCsXYrNfU3GCihuwG3vMqFji7PZXajMEqyBkNh9UZUJgoHYBLTKu1eM4MvUtomcXPQ3Sw9HZ5ebbM4byoUciHo1zrPJBQfqpLorQ";

        let xkey = ExtendedPrivateKey::<SecretKey>::from_str(xprv)?.derive_path(derivation_path)?;

        let xkey = xkey.derive_child(ChildNumber::new(0, false)?)?;

        // address test
        let address_test = Address::new(Prefix::Testnet, Version::PubKey, &xkey.public_key().to_bytes()[1..]);
        let address_str: String = address_test.clone().into();
        assert_eq!(address, address_test, "Addresses don't match");
        println!("address: {address_str}");

        let private_keys = vec![xkey.to_bytes()];

        println!("mtx: {mtx:?}");

        let mtx = sign_transaction(mtx, private_keys, true)?;

        let utxo_context =
            self::create_utxos_context_with_addresses(rpc_api.clone(), vec![to_address.clone()], current_daa_score, utxo_processor)
                .await?;
        let to_balance = utxo_context.calculate_balance().await;
        println!("to address balance before tx submit: {to_balance:?}");

        let result = rpc_api.submit_transaction(mtx.into(), false).await?;

        println!("tx submit result, {:?}", result);
        println!("sleep for 5s...");
        sleep(time::Duration::from_millis(5000));
        let utxo_context =
            self::create_utxos_context_with_addresses(rpc_api.clone(), vec![to_address.clone()], current_daa_score, utxo_processor)
                .await?;
        let to_balance = utxo_context.calculate_balance().await;
        println!("to address balance after tx submit: {to_balance:?}");

        Ok(())
    }
    */
}
