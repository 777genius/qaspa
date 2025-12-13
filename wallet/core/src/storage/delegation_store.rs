use crate::account::delegation::{DelegationId, DelegationRecordV1, DelegationStatus};
use crate::deterministic::AccountId;
use crate::encryption::{Decrypted, EncryptionKind};
use crate::error::Error;
use crate::result::Result;
use borsh::{BorshDeserialize, BorshSerialize};
use dashmap::DashMap;
use kaspa_consensus_core::network::NetworkId;
use kaspa_wallet_keys::secret::Secret;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use workflow_store::fs;

const STORAGE_MAGIC: u32 = 0x444C4754; // "DLGT"
const STORAGE_VERSION: u32 = 0;

struct StoredDelegation {
    id: u64,
    record: DelegationRecordV1,
    request_id: Option<[u8; 32]>,
}

impl BorshSerialize for StoredDelegation {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        BorshSerialize::serialize(&self.id, writer)?;
        BorshSerialize::serialize(&self.record, writer)?;
        BorshSerialize::serialize(&self.request_id, writer)?;
        Ok(())
    }
}

impl BorshDeserialize for StoredDelegation {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let id = BorshDeserialize::deserialize_reader(reader)?;
        let record = BorshDeserialize::deserialize_reader(reader)?;
        let request_id = match Option::<[u8; 32]>::deserialize_reader(reader) {
            Ok(value) => value,
            Err(err) if err.kind() == std::io::ErrorKind::UnexpectedEof => None,
            Err(err) => return Err(err),
        };
        Ok(Self { id, record, request_id })
    }
}

#[derive(BorshSerialize, BorshDeserialize)]
struct FileEnvelope {
    magic: u32,
    version: u32,
    entries: Vec<StoredDelegation>,
}

impl FileEnvelope {
    fn new(entries: Vec<StoredDelegation>) -> Self {
        Self { magic: STORAGE_MAGIC, version: STORAGE_VERSION, entries }
    }
}

#[derive(Clone)]
struct DelegationEntry {
    record: DelegationRecordV1,
    request_id: Option<[u8; 32]>,
}

impl DelegationEntry {
    fn new(record: DelegationRecordV1, request_id: Option<[u8; 32]>) -> Self {
        Self { record, request_id }
    }
}

pub struct DelegationStore {
    by_id: DashMap<DelegationId, DelegationEntry>,
    by_anchor_account: DashMap<([u8; 32], AccountId), Vec<DelegationId>>,
    request_index: DashMap<[u8; 32], Vec<DelegationId>>,
    next_id: AtomicU64,
}

impl Default for DelegationStore {
    fn default() -> Self {
        Self::new()
    }
}

impl DelegationStore {
    pub fn new() -> Self {
        Self { by_id: DashMap::new(), by_anchor_account: DashMap::new(), request_index: DashMap::new(), next_id: AtomicU64::new(0) }
    }

    pub fn upsert(&self, record: DelegationRecordV1, request_id: Option<[u8; 32]>) -> Result<DelegationId> {
        let key = (record.anchor, record.account_id);
        let mut list = self.by_anchor_account.entry(key).or_default();

        // Нельзя полагаться на `last()` как на "последний nonce":
        // порядок `list` может быть нарушен после загрузки из стора (dashmap итерация/сериализация не гарантирует порядок).
        // Поэтому проверяем против максимального nonce среди уже известных записей.
        let current_max = list.iter().filter_map(|id| self.by_id.get(id).map(|e| e.record.nonce)).max();
        if let Some(current) = current_max {
            if record.nonce <= current {
                return Err(Error::MasterDelegationStaleNonce { account_id: record.account_id, current, received: record.nonce });
            }
        }

        let id_val = self.next_id.fetch_add(1, Ordering::SeqCst);
        let id = DelegationId(id_val);
        self.by_id.insert(id, DelegationEntry::new(record.clone(), request_id));
        list.push(id);

        if let Some(rid) = request_id {
            self.request_index.entry(rid).or_default().push(id);
        }

        Ok(id)
    }

    pub fn by_id(&self, id: DelegationId) -> Option<DelegationRecordV1> {
        self.by_id.get(&id).map(|r| r.record.clone())
    }

    pub fn mark_warned_at(&self, id: DelegationId, warned_at_daa: u64) {
        if let Some(mut entry) = self.by_id.get_mut(&id) {
            entry.record.warned_at_daa = Some(warned_at_daa);
        }
    }

    pub fn by_anchor(&self, anchor: &[u8; 32]) -> Vec<(DelegationId, DelegationRecordV1)> {
        self.by_anchor_account
            .iter()
            .filter(|k| k.key().0 == *anchor)
            .flat_map(|entry| entry.value().iter().filter_map(|id| self.by_id(*id).map(|rec| (*id, rec))).collect::<Vec<_>>())
            .collect()
    }

    pub fn active_for_account(&self, anchor: &[u8; 32], account_id: &AccountId) -> Option<(DelegationId, DelegationRecordV1)> {
        let key = (*anchor, *account_id);
        let latest = self.by_anchor_account.get(&key).and_then(|ids| {
            ids.iter()
                .filter_map(|id| self.by_id(*id).map(|rec| (*id, rec)))
                .max_by_key(|r| (r.1.nonce, r.1.valid_from_daa, r.1.valid_until_daa.unwrap_or(u64::MAX)))
        });

        latest.and_then(|pair| match pair.1.status {
            DelegationStatus::Active => Some(pair),
            _ => None,
        })
    }

    pub fn latest_nonce(&self, anchor: &[u8; 32], account_id: &AccountId) -> Option<u64> {
        let key = (*anchor, *account_id);
        self.by_anchor_account.get(&key).and_then(|ids| ids.iter().filter_map(|id| self.by_id(*id).map(|rec| rec.nonce)).max())
    }

    pub fn active_records(&self) -> Vec<(DelegationId, DelegationRecordV1)> {
        self.by_id
            .iter()
            .filter_map(|entry| {
                let rec = entry.record.clone();
                matches!(rec.status, DelegationStatus::Active).then_some((*entry.key(), rec))
            })
            .collect()
    }

    pub fn find_by_anchor_account_nonce(&self, anchor: &[u8; 32], account_id: &AccountId, nonce: u64) -> Option<DelegationRecordV1> {
        let key = (*anchor, *account_id);
        self.by_anchor_account.get(&key).and_then(|ids| {
            ids.iter().find_map(|id| self.by_id(*id).and_then(|rec| if rec.nonce == nonce { Some(rec.clone()) } else { None }))
        })
    }

    pub fn has_request(&self, request_id: &[u8; 32]) -> bool {
        self.request_index.contains_key(request_id)
    }

    pub fn records_for_request(&self, request_id: &[u8; 32]) -> Vec<DelegationRecordV1> {
        self.request_index
            .get(request_id)
            .map(|ids| ids.iter().filter_map(|id| self.by_id(*id)).collect::<Vec<_>>())
            .unwrap_or_default()
    }

    /// Returns true if the store contains at least one record for the given account id
    /// (any anchor/status). Useful for distinguishing `NoDelegation` vs `AnchorMismatch`.
    pub fn has_any_for_account(&self, account_id: &AccountId) -> bool {
        self.by_id.iter().any(|entry| entry.record.account_id == *account_id)
    }

    pub async fn save_to_storage(&self, wallet_folder: &str, network_id: NetworkId, wallet_secret: &Secret) -> Result<()> {
        let path = Self::storage_path(wallet_folder, network_id);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).await?;
        }

        let entries: Vec<StoredDelegation> = self
            .by_id
            .iter()
            .map(|r| StoredDelegation { id: r.key().0, record: r.record.clone(), request_id: r.request_id })
            .collect();

        let envelope = FileEnvelope::new(entries);
        let decrypted = Decrypted::new(envelope);
        let encrypted = decrypted.encrypt(wallet_secret, EncryptionKind::XChaCha20Poly1305)?;
        let bytes = borsh::to_vec(&encrypted)?;
        fs::write(&path, bytes.as_slice()).await?;
        Ok(())
    }

    pub async fn load_from_storage(&self, wallet_folder: &str, network_id: NetworkId, wallet_secret: &Secret) -> Result<usize> {
        let path = Self::storage_path(wallet_folder, network_id);

        // `load_from_storage` должен отражать текущее состояние на диске.
        // Поэтому всегда сбрасываем in-memory индексы перед загрузкой, иначе при повторных
        // открытиях/перезагрузках кошелька можно получить дубликаты в `by_anchor_account`
        // и смешивание данных разных кошельков.
        self.by_id.clear();
        self.by_anchor_account.clear();
        self.request_index.clear();
        self.next_id.store(0, Ordering::SeqCst);

        if !fs::exists(&path).await? {
            return Ok(0);
        }

        let bytes = fs::read(&path).await?;
        let encrypted: crate::encryption::Encrypted = BorshDeserialize::try_from_slice(&bytes)?;
        let decrypted: Decrypted<FileEnvelope> = encrypted.decrypt(wallet_secret)?;
        let envelope = decrypted.0;

        if envelope.magic != STORAGE_MAGIC {
            return Err(Error::Custom("invalid delegation storage magic".to_string()));
        }
        if envelope.version != STORAGE_VERSION {
            return Err(Error::Custom("unsupported delegation storage version".to_string()));
        }

        let mut max_id: Option<u64> = None;
        for StoredDelegation { id, record, request_id } in envelope.entries {
            max_id = Some(max_id.map(|prev| prev.max(id)).unwrap_or(id));
            let key = (record.anchor, record.account_id);
            self.by_id.insert(DelegationId(id), DelegationEntry::new(record.clone(), request_id));
            self.by_anchor_account.entry(key).or_default().push(DelegationId(id));
            if let Some(rid) = request_id {
                self.request_index.entry(rid).or_default().push(DelegationId(id));
            }
        }
        let next = max_id.map(|m| m.saturating_add(1)).unwrap_or(0);
        self.next_id.store(next, Ordering::SeqCst);
        Ok(self.by_id.len())
    }

    fn storage_path(wallet_folder: &str, network_id: NetworkId) -> PathBuf {
        PathBuf::from(wallet_folder).join("delegations").join(network_id.to_string()).join("delegations.dlgt")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(not(target_arch = "wasm32"))]
    use kaspa_consensus_core::network::NetworkType;
    use kaspa_hashes::Hash;
    use kaspa_mldsa::MlDsaLevel;
    #[cfg(not(target_arch = "wasm32"))]
    use tempfile::tempdir;

    #[test]
    fn upsert_rejects_stale_even_when_list_order_is_unsorted() {
        let store = DelegationStore::new();
        let anchor = [7u8; 32];
        let account_id = AccountId(Hash::from_u64_word(1));

        let mut rec10 = DelegationRecordV1::new(
            MlDsaLevel::Level2,
            anchor,
            account_id,
            [1u8; 32],
            [2u8; 32],
            0,
            None,
            10,
            DelegationStatus::Active,
        );
        rec10.signature = vec![0u8; MlDsaLevel::Level2.signature_len()];

        let mut rec5 = rec10.clone();
        rec5.nonce = 5;

        // Имитация неконсистентного порядка (как после load из стора): last() != max(nonce)
        store.by_id.insert(DelegationId(0), DelegationEntry::new(rec10.clone(), None));
        store.by_id.insert(DelegationId(1), DelegationEntry::new(rec5, None));
        store.by_anchor_account.entry((anchor, account_id)).or_default().extend([DelegationId(0), DelegationId(1)]);
        store.next_id.store(2, Ordering::SeqCst);

        let mut rec6 = rec10;
        rec6.nonce = 6;

        let err = store.upsert(rec6, None).unwrap_err();
        assert!(matches!(
            err,
            Error::MasterDelegationStaleNonce { account_id: a, current: 10, received: 6 } if a == account_id
        ));
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[tokio::test]
    async fn load_from_storage_clears_and_does_not_duplicate() {
        let store = DelegationStore::new();
        let anchor = [7u8; 32];
        let account_id = AccountId(Hash::from_u64_word(1));

        let mut rec = DelegationRecordV1::new(
            MlDsaLevel::Level2,
            anchor,
            account_id,
            [1u8; 32],
            [2u8; 32],
            0,
            None,
            1,
            DelegationStatus::Active,
        );
        rec.signature = vec![0u8; MlDsaLevel::Level2.signature_len()];
        let _id = store.upsert(rec, None).expect("upsert");
        assert_eq!(store.by_anchor(&anchor).len(), 1);

        let temp_dir = tempdir().unwrap();
        let wallet_folder = temp_dir.path().to_string_lossy().to_string();
        let network_id = NetworkId::with_suffix(NetworkType::Testnet, 17);
        let wallet_secret = Secret::from("delegation-store-test");

        store.save_to_storage(&wallet_folder, network_id, &wallet_secret).await.expect("save");

        // Повторная загрузка в тот же экземпляр не должна давать дубликаты.
        store.load_from_storage(&wallet_folder, network_id, &wallet_secret).await.expect("load 1");
        assert_eq!(store.by_anchor(&anchor).len(), 1);

        store.load_from_storage(&wallet_folder, network_id, &wallet_secret).await.expect("load 2");
        assert_eq!(store.by_anchor(&anchor).len(), 1);
    }
}
