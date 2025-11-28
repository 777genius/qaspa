//!
//! Ephemeral key storage for stealth transactions.
//!
//! Stores the pre-computed spending keys for received stealth UTXOs.
//! Keys are encrypted at rest using the wallet secret.
//!

use crate::deterministic::AccountId;
use crate::encryption::{Decrypted, EncryptionKind};
use crate::result::Result;
use borsh::{BorshDeserialize, BorshSerialize};
use dashmap::DashMap;
use kaspa_consensus_core::network::NetworkId;
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_keys::secret::Secret;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use workflow_log::log_debug;
use workflow_store::fs;
use zeroize::Zeroize;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Status of an ephemeral key
#[derive(Clone, Debug, BorshSerialize, BorshDeserialize, Serialize, Deserialize, PartialEq, Eq)]
pub enum EphemeralKeyStatus {
    /// UTXO is in mempool or recently added (not yet confirmed)
    Pending { added_daa_score: u64 },
    /// UTXO has sufficient confirmations
    Confirmed { confirmed_daa_score: u64 },
}

impl Default for EphemeralKeyStatus {
    fn default() -> Self {
        Self::Pending { added_daa_score: 0 }
    }
}

/// Data needed to spend a stealth UTXO
#[derive(Clone, BorshSerialize, BorshDeserialize, Serialize, Deserialize)]
pub struct EphemeralKeyData {
    /// Pre-computed spending secret key (32 bytes)
    #[serde(with = "kaspa_utils::serde_bytes")]
    pub spending_secret: Vec<u8>,
    /// Blinding factor used in derivation (32 bytes)
    #[serde(with = "kaspa_utils::serde_bytes")]
    pub blinding_factor: Vec<u8>,
    /// Destination public key P_dest (33 bytes compressed)
    #[serde(with = "kaspa_utils::serde_bytes")]
    pub destination_pubkey: Vec<u8>,
}

impl EphemeralKeyData {
    /// Creates a new EphemeralKeyData from fixed-size arrays (compressed pubkey 33 bytes)
    pub fn new(spending_secret: [u8; 32], blinding_factor: [u8; 32], destination_pubkey: [u8; 33]) -> Self {
        Self {
            spending_secret: spending_secret.to_vec(),
            blinding_factor: blinding_factor.to_vec(),
            destination_pubkey: destination_pubkey.to_vec(),
        }
    }

    /// Creates a new EphemeralKeyData with x-only pubkey (32 bytes)
    pub fn new_xonly(spending_secret: [u8; 32], blinding_factor: [u8; 32], destination_pubkey: [u8; 32]) -> Self {
        Self {
            spending_secret: spending_secret.to_vec(),
            blinding_factor: blinding_factor.to_vec(),
            destination_pubkey: destination_pubkey.to_vec(),
        }
    }

    /// Returns the spending secret as a fixed-size array
    pub fn spending_secret_bytes(&self) -> Option<[u8; 32]> {
        self.spending_secret.as_slice().try_into().ok()
    }

    /// Returns the blinding factor as a fixed-size array
    pub fn blinding_factor_bytes(&self) -> Option<[u8; 32]> {
        self.blinding_factor.as_slice().try_into().ok()
    }

    /// Returns the destination pubkey as a fixed-size array (compressed, 33 bytes)
    pub fn destination_pubkey_bytes(&self) -> Option<[u8; 33]> {
        self.destination_pubkey.as_slice().try_into().ok()
    }

    /// Returns the destination pubkey as a fixed-size array (x-only, 32 bytes)
    pub fn destination_pubkey_xonly_bytes(&self) -> Option<[u8; 32]> {
        self.destination_pubkey.as_slice().try_into().ok()
    }
}

impl Zeroize for EphemeralKeyData {
    fn zeroize(&mut self) {
        self.spending_secret.zeroize();
        self.blinding_factor.zeroize();
    }
}

impl Drop for EphemeralKeyData {
    fn drop(&mut self) {
        self.zeroize();
    }
}

impl std::fmt::Debug for EphemeralKeyData {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EphemeralKeyData")
            .field("spending_secret", &"[REDACTED]")
            .field("blinding_factor", &"[REDACTED]")
            .field("destination_pubkey", &faster_hex::hex_string(&self.destination_pubkey))
            .finish()
    }
}

/// Entry stored on disk (encrypted)
#[derive(Clone, BorshSerialize, BorshDeserialize, Serialize, Deserialize)]
pub struct EphemeralKeyEntry {
    pub outpoint: TransactionOutpoint,
    pub data: EphemeralKeyData,
    pub status: EphemeralKeyStatus,
}

impl Zeroize for EphemeralKeyEntry {
    fn zeroize(&mut self) {
        self.data.zeroize();
    }
}

impl std::fmt::Debug for EphemeralKeyEntry {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EphemeralKeyEntry")
            .field("outpoint", &self.outpoint)
            .field("data", &self.data)
            .field("status", &self.status)
            .finish()
    }
}

// ============================================================================
// EPHEMERAL KEY STORE
// ============================================================================

/// In-memory store for ephemeral keys with disk persistence.
pub struct EphemeralKeyStore {
    account_id: AccountId,

    /// In-memory cache (decrypted keys)
    keys: DashMap<TransactionOutpoint, EphemeralKeyData>,

    /// Status tracking
    statuses: DashMap<TransactionOutpoint, EphemeralKeyStatus>,

    /// Dirty flag for persistence
    modified: AtomicBool,
}

impl EphemeralKeyStore {
    pub fn new(account_id: AccountId) -> Self {
        Self { account_id, keys: DashMap::new(), statuses: DashMap::new(), modified: AtomicBool::new(false) }
    }

    /// Returns the account ID this store belongs to
    pub fn account_id(&self) -> &AccountId {
        &self.account_id
    }

    // ========================================================================
    // IN-MEMORY OPERATIONS
    // ========================================================================

    /// Stores an ephemeral key in memory
    pub async fn store(&self, outpoint: TransactionOutpoint, data: EphemeralKeyData, daa_score: u64) -> Result<()> {
        self.keys.insert(outpoint, data);
        self.statuses.insert(outpoint, EphemeralKeyStatus::Pending { added_daa_score: daa_score });
        self.modified.store(true, Ordering::SeqCst);
        Ok(())
    }

    /// Retrieves an ephemeral key
    pub async fn get(&self, outpoint: &TransactionOutpoint) -> Option<EphemeralKeyData> {
        self.keys.get(outpoint).map(|r| (*r).clone())
    }

    /// Checks if an outpoint is stored
    pub fn contains(&self, outpoint: &TransactionOutpoint) -> bool {
        self.keys.contains_key(outpoint)
    }

    /// Removes an ephemeral key
    pub async fn remove(&self, outpoint: &TransactionOutpoint) -> Result<()> {
        self.keys.remove(outpoint);
        self.statuses.remove(outpoint);
        self.modified.store(true, Ordering::SeqCst);
        Ok(())
    }

    /// Confirms an ephemeral key (UTXO has sufficient confirmations)
    pub fn confirm(&self, outpoint: &TransactionOutpoint, daa_score: u64) {
        self.statuses.entry(*outpoint).and_modify(|status| {
            *status = EphemeralKeyStatus::Confirmed { confirmed_daa_score: daa_score };
        });
        self.modified.store(true, Ordering::SeqCst);
    }

    /// Returns all outpoints
    pub fn outpoints(&self) -> Vec<TransactionOutpoint> {
        self.keys.iter().map(|r| *r.key()).collect()
    }

    /// Returns count of stored keys
    pub fn len(&self) -> usize {
        self.keys.len()
    }

    /// Returns true if no keys are stored
    pub fn is_empty(&self) -> bool {
        self.keys.is_empty()
    }

    /// Returns true if the store has been modified since last save
    pub fn is_modified(&self) -> bool {
        self.modified.load(Ordering::SeqCst)
    }

    /// Returns all entries as a vector (for serialization)
    pub fn entries(&self) -> Vec<EphemeralKeyEntry> {
        self.keys
            .iter()
            .map(|r| {
                let outpoint = *r.key();
                let data = r.value().clone();
                let status = self.statuses.get(&outpoint).map(|s| s.clone()).unwrap_or_default();
                EphemeralKeyEntry { outpoint, data, status }
            })
            .collect()
    }

    /// Loads entries into the store (for deserialization)
    pub fn load_entries(&self, entries: Vec<EphemeralKeyEntry>) {
        for entry in entries {
            self.keys.insert(entry.outpoint, entry.data);
            self.statuses.insert(entry.outpoint, entry.status);
        }
        self.modified.store(false, Ordering::SeqCst);
    }

    /// Marks the store as saved
    pub fn mark_saved(&self) {
        self.modified.store(false, Ordering::SeqCst);
    }

    /// Clears all keys (zeroizing memory)
    pub fn clear(&self) {
        for mut entry in self.keys.iter_mut() {
            entry.value_mut().zeroize();
        }
        self.keys.clear();
        self.statuses.clear();
    }

    // ========================================================================
    // PERSISTENCE OPERATIONS
    // ========================================================================

    /// Returns the file path for storing ephemeral keys
    fn storage_path(wallet_folder: &str, account_id: &AccountId, network_id: NetworkId) -> PathBuf {
        PathBuf::from(wallet_folder).join("stealth").join(network_id.to_string()).join(format!("{}.keys", account_id.to_hex()))
    }

    /// Saves ephemeral keys to encrypted file.
    ///
    /// # Arguments
    /// * `wallet_folder` - Base folder for wallet data
    /// * `network_id` - Current network
    /// * `wallet_secret` - Secret for encryption
    pub async fn save_to_storage(&self, wallet_folder: &str, network_id: NetworkId, wallet_secret: &Secret) -> Result<()> {
        if !self.is_modified() {
            return Ok(());
        }

        let path = Self::storage_path(wallet_folder, &self.account_id, network_id);

        // Ensure directory exists
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).await?;
        }

        // Serialize entries
        let entries = self.entries();

        // Encrypt
        let decrypted = Decrypted::new(entries);
        let encrypted = decrypted.encrypt(wallet_secret, EncryptionKind::XChaCha20Poly1305)?;
        let bytes = borsh::to_vec(&encrypted)?;

        // Write to file
        fs::write(&path, bytes.as_slice()).await?;

        self.mark_saved();
        log_debug!("Saved {} ephemeral keys for account {}", self.len(), self.account_id.to_hex());

        Ok(())
    }

    /// Loads ephemeral keys from encrypted file.
    ///
    /// # Arguments
    /// * `wallet_folder` - Base folder for wallet data  
    /// * `network_id` - Current network
    /// * `wallet_secret` - Secret for decryption
    ///
    /// # Returns
    /// Number of keys loaded
    pub async fn load_from_storage(&self, wallet_folder: &str, network_id: NetworkId, wallet_secret: &Secret) -> Result<usize> {
        let path = Self::storage_path(wallet_folder, &self.account_id, network_id);

        if !fs::exists(&path).await? {
            log_debug!("No ephemeral keys file for account {}", self.account_id.to_hex());
            return Ok(0);
        }

        // Read file
        let bytes = fs::read(&path).await?;

        // Deserialize encrypted container
        let encrypted: crate::encryption::Encrypted = BorshDeserialize::try_from_slice(&bytes)?;

        // Decrypt
        let decrypted: Decrypted<Vec<EphemeralKeyEntry>> = encrypted.decrypt(wallet_secret)?;
        let entries = decrypted.0;
        let count = entries.len();

        // Load into store
        self.load_entries(entries);

        log_debug!("Loaded {} ephemeral keys for account {}", count, self.account_id.to_hex());
        Ok(count)
    }

    /// Deletes the ephemeral keys storage file.
    pub async fn delete_storage(wallet_folder: &str, account_id: &AccountId, network_id: NetworkId) -> Result<()> {
        let path = Self::storage_path(wallet_folder, account_id, network_id);
        if fs::exists(&path).await? {
            fs::remove(&path).await?;
            log_debug!("Deleted ephemeral keys for account {}", account_id.to_hex());
        }
        Ok(())
    }

    /// Checks if storage file exists
    pub async fn storage_exists(wallet_folder: &str, account_id: &AccountId, network_id: NetworkId) -> Result<bool> {
        let path = Self::storage_path(wallet_folder, account_id, network_id);
        Ok(fs::exists(&path).await?)
    }
}

impl Drop for EphemeralKeyStore {
    fn drop(&mut self) {
        self.clear();
    }
}

// ============================================================================
// EPHEMERAL KEY PROVIDER IMPLEMENTATION
// ============================================================================

use crate::tx::generator::stealth_signer::EphemeralKeyProvider;
use async_trait::async_trait;

#[async_trait]
impl EphemeralKeyProvider for EphemeralKeyStore {
    async fn get_ephemeral_key(&self, outpoint: &TransactionOutpoint) -> Option<EphemeralKeyData> {
        self.get(outpoint).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::deterministic::AccountId;
    use kaspa_hashes::Hash;
    use kaspa_utils::hex::FromHex;

    fn test_account_id(suffix: &str) -> AccountId {
        // Create a valid 64-char hex string for AccountId
        let hex = format!("cafe0000000000000000000000000000000000000000000000000000{}", suffix);
        AccountId::from_hex(&hex).unwrap()
    }

    #[tokio::test]
    async fn test_ephemeral_key_store_basic() {
        let account_id = test_account_id("00000001");
        let store = EphemeralKeyStore::new(account_id);

        let tx_id = Hash::from_bytes([1u8; 32]);
        let outpoint = TransactionOutpoint::new(tx_id, 0);
        let key_data = EphemeralKeyData::new([1u8; 32], [2u8; 32], [3u8; 33]);

        // Test store
        store.store(outpoint.clone(), key_data.clone(), 100).await.unwrap();
        assert!(store.contains(&outpoint));
        assert_eq!(store.len(), 1);
        assert!(store.is_modified());

        // Test get
        let retrieved = store.get(&outpoint).await.unwrap();
        assert_eq!(retrieved.spending_secret, key_data.spending_secret);

        // Test confirm
        store.confirm(&outpoint, 200);
        let entries = store.entries();
        assert_eq!(entries.len(), 1);
        assert!(matches!(entries[0].status, EphemeralKeyStatus::Confirmed { confirmed_daa_score: 200 }));

        // Test remove
        store.remove(&outpoint).await.unwrap();
        assert!(!store.contains(&outpoint));
        assert_eq!(store.len(), 0);
    }

    #[tokio::test]
    async fn test_ephemeral_key_store_serialization() {
        let account_id = test_account_id("00000002");
        let store = EphemeralKeyStore::new(account_id);

        // Add some entries
        for i in 0..5u8 {
            let tx_id = Hash::from_bytes([i; 32]);
            let outpoint = TransactionOutpoint::new(tx_id, i as u32);
            let key_data = EphemeralKeyData::new([i; 32], [i + 1; 32], [i + 2; 33]);
            store.store(outpoint, key_data, 100 + i as u64).await.unwrap();
        }

        // Get entries
        let entries = store.entries();
        assert_eq!(entries.len(), 5);

        // Load into new store
        let store2 = EphemeralKeyStore::new(account_id);
        store2.load_entries(entries);
        assert_eq!(store2.len(), 5);
        assert!(!store2.is_modified()); // Should not be modified after load
    }

    #[test]
    fn test_ephemeral_key_data_accessors() {
        let spending = [1u8; 32];
        let blinding = [2u8; 32];
        let pubkey = [3u8; 33];

        let data = EphemeralKeyData::new(spending, blinding, pubkey);

        assert_eq!(data.spending_secret_bytes(), Some(spending));
        assert_eq!(data.blinding_factor_bytes(), Some(blinding));
        assert_eq!(data.destination_pubkey_bytes(), Some(pubkey));
    }

    #[tokio::test]
    async fn test_ephemeral_key_provider_impl() {
        use crate::tx::generator::stealth_signer::EphemeralKeyProvider;

        let account_id = test_account_id("00000003");
        let store = EphemeralKeyStore::new(account_id);

        let tx_id = Hash::from_bytes([5u8; 32]);
        let outpoint = TransactionOutpoint::new(tx_id, 0);
        let key_data = EphemeralKeyData::new([10u8; 32], [20u8; 32], [30u8; 33]);

        // Store a key
        store.store(outpoint, key_data.clone(), 100).await.unwrap();

        // Retrieve via EphemeralKeyProvider trait
        let provider: &dyn EphemeralKeyProvider = &store;
        let retrieved = provider.get_ephemeral_key(&outpoint).await;
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().spending_secret, key_data.spending_secret);

        // Non-existent outpoint should return None
        let other_outpoint = TransactionOutpoint::new(Hash::from_bytes([99u8; 32]), 0);
        let not_found = provider.get_ephemeral_key(&other_outpoint).await;
        assert!(not_found.is_none());
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[tokio::test]
    async fn test_ephemeral_key_store_persistence() {
        use kaspa_wallet_keys::secret::Secret;
        use std::env;

        let account_id = test_account_id("00000004");
        let network_id =
            kaspa_consensus_core::network::NetworkId::with_suffix(kaspa_consensus_core::network::NetworkType::Testnet, 11);
        let wallet_secret = Secret::from("test-secret-for-stealth-keys");

        // Use temp directory
        let temp_dir = env::temp_dir().join("kaspa-test-stealth-keys");
        let wallet_folder = temp_dir.to_str().unwrap();

        // Cleanup before test
        let _ = EphemeralKeyStore::delete_storage(wallet_folder, &account_id, network_id).await;

        // Create and populate store
        let store1 = EphemeralKeyStore::new(account_id);
        for i in 0..3u8 {
            let tx_id = Hash::from_bytes([i + 10; 32]);
            let outpoint = TransactionOutpoint::new(tx_id, i as u32);
            let key_data = EphemeralKeyData::new([i; 32], [i + 1; 32], [i + 2; 33]);
            store1.store(outpoint, key_data, 100 + i as u64).await.unwrap();
        }

        // Confirm one entry
        let confirmed_outpoint = TransactionOutpoint::new(Hash::from_bytes([10; 32]), 0);
        store1.confirm(&confirmed_outpoint, 200);

        assert!(store1.is_modified());
        assert_eq!(store1.len(), 3);

        // Save to storage
        store1.save_to_storage(wallet_folder, network_id, &wallet_secret).await.unwrap();
        assert!(!store1.is_modified());

        // Verify storage exists
        assert!(EphemeralKeyStore::storage_exists(wallet_folder, &account_id, network_id).await.unwrap());

        // Create new store and load from storage
        let store2 = EphemeralKeyStore::new(account_id);
        let loaded_count = store2.load_from_storage(wallet_folder, network_id, &wallet_secret).await.unwrap();

        assert_eq!(loaded_count, 3);
        assert_eq!(store2.len(), 3);
        assert!(!store2.is_modified());

        // Verify data integrity
        let retrieved = store2.get(&confirmed_outpoint).await.unwrap();
        assert_eq!(retrieved.spending_secret, vec![0u8; 32]);

        // Verify status was preserved
        let entries = store2.entries();
        let confirmed_entry = entries.iter().find(|e| e.outpoint == confirmed_outpoint).unwrap();
        assert!(matches!(confirmed_entry.status, EphemeralKeyStatus::Confirmed { confirmed_daa_score: 200 }));

        // Cleanup
        EphemeralKeyStore::delete_storage(wallet_folder, &account_id, network_id).await.unwrap();
        assert!(!EphemeralKeyStore::storage_exists(wallet_folder, &account_id, network_id).await.unwrap());
    }
}
