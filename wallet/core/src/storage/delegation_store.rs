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

#[derive(BorshSerialize, BorshDeserialize)]
struct StoredDelegation {
    id: u64,
    record: DelegationRecordV1,
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

pub struct DelegationStore {
    by_id: DashMap<DelegationId, DelegationRecordV1>,
    by_anchor_account: DashMap<([u8; 32], AccountId), Vec<DelegationId>>,
    next_id: AtomicU64,
}

impl Default for DelegationStore {
    fn default() -> Self {
        Self::new()
    }
}

impl DelegationStore {
    pub fn new() -> Self {
        Self { by_id: DashMap::new(), by_anchor_account: DashMap::new(), next_id: AtomicU64::new(0) }
    }

    pub fn upsert(&self, record: DelegationRecordV1) -> Result<DelegationId> {
        let key = (record.anchor, record.account_id);
        let mut list = self.by_anchor_account.entry(key).or_default();

        if let Some(last_id) = list.last() {
            if let Some(prev) = self.by_id.get(last_id) {
                if record.nonce != prev.nonce + 1 {
                    return Err(Error::Custom("delegation nonce must be monotonic".to_string()));
                }
            }
        }

        let id_val = self.next_id.fetch_add(1, Ordering::SeqCst);
        let id = DelegationId(id_val);
        self.by_id.insert(id, record);
        list.push(id);
        Ok(id)
    }

    pub fn by_id(&self, id: DelegationId) -> Option<DelegationRecordV1> {
        self.by_id.get(&id).map(|r| r.value().clone())
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

    pub async fn save_to_storage(&self, wallet_folder: &str, network_id: NetworkId, wallet_secret: &Secret) -> Result<()> {
        let path = Self::storage_path(wallet_folder, network_id);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).await?;
        }

        let entries: Vec<StoredDelegation> =
            self.by_id.iter().map(|r| StoredDelegation { id: r.key().0, record: r.value().clone() }).collect();

        let envelope = FileEnvelope::new(entries);
        let decrypted = Decrypted::new(envelope);
        let encrypted = decrypted.encrypt(wallet_secret, EncryptionKind::XChaCha20Poly1305)?;
        let bytes = borsh::to_vec(&encrypted)?;
        fs::write(&path, bytes.as_slice()).await?;
        Ok(())
    }

    pub async fn load_from_storage(&self, wallet_folder: &str, network_id: NetworkId, wallet_secret: &Secret) -> Result<usize> {
        let path = Self::storage_path(wallet_folder, network_id);
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

        let mut max_id = 0u64;
        for StoredDelegation { id, record } in envelope.entries {
            max_id = max_id.max(id);
            let key = (record.anchor, record.account_id);
            self.by_id.insert(DelegationId(id), record.clone());
            self.by_anchor_account.entry(key).or_default().push(DelegationId(id));
        }
        self.next_id.store(max_id + 1, Ordering::SeqCst);
        Ok(self.by_id.len())
    }

    fn storage_path(wallet_folder: &str, network_id: NetworkId) -> PathBuf {
        PathBuf::from(wallet_folder).join("delegations").join(network_id.to_string()).join("delegations.dlgt")
    }
}
