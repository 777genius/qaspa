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

        if let Some(last_id) = list.last() {
            if let Some(prev) = self.by_id.get(last_id) {
                if record.nonce <= prev.record.nonce {
                    return Err(Error::MasterDelegationStaleNonce {
                        account_id: record.account_id,
                        current: prev.record.nonce,
                        received: record.nonce,
                    });
                }
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
        for StoredDelegation { id, record, request_id } in envelope.entries {
            max_id = max_id.max(id);
            let key = (record.anchor, record.account_id);
            self.by_id.insert(DelegationId(id), DelegationEntry::new(record.clone(), request_id));
            self.by_anchor_account.entry(key).or_default().push(DelegationId(id));
            if let Some(rid) = request_id {
                self.request_index.entry(rid).or_default().push(DelegationId(id));
            }
        }
        self.next_id.store(max_id + 1, Ordering::SeqCst);
        Ok(self.by_id.len())
    }

    fn storage_path(wallet_folder: &str, network_id: NetworkId) -> PathBuf {
        PathBuf::from(wallet_folder).join("delegations").join(network_id.to_string()).join("delegations.dlgt")
    }
}
