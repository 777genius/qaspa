//!
//! Stealth Address Account Implementation
//!
//! Provides privacy-preserving transactions using ECDH-based stealth addresses.
//! Each payment creates a unique one-time destination that only the recipient
//! can identify and spend.
//!

use crate::account::delegation::{DelegationId, DelegationRecordV1, DelegationStatus};
use crate::account::{Account, AccountKind, GenerationNotifier, Inner};
use crate::deterministic::{make_account_hashes, AccountId};
use crate::events::Events;
use crate::imports::*;
use crate::serializer::StorageHeader;
use crate::storage::account::{AccountSettings, AccountStorable, AccountStorage};
use crate::storage::ephemeral_keys::{EphemeralKeyData, EphemeralKeyStatus, EphemeralKeyStore, OrphanReason};
use crate::storage::interface::StorageDescriptor;
use crate::storage::{AccountMetadata, PrvKeyDataId, Storable};
use crate::tx::generator::stealth_change::{DynStealthChangeCreator, PendingStealthChange, StealthChangeCreator};
use crate::tx::generator::stealth_signer::StealthSigner;
use crate::tx::{Fees, GeneratorSettings, GeneratorSummary, PaymentDestination, RandomFeeSettings};
use crate::utxo::stealth_handler::StealthUtxoHandler;
use crate::utxo::UtxoContext;
use dashmap::DashMap;
use kaspa_addresses::{Address, Version};
use kaspa_bip32::ExtendedPrivateKey;
use kaspa_consensus_core::{
    network::NetworkId,
    subnets,
    tx::{Transaction, TransactionOutpoint},
};
#[cfg(test)]
use kaspa_rpc_core::RpcTransactionOutpoint;
use kaspa_rpc_core::{RpcBlock, RpcHash, RpcTransactionId, RpcUtxoEntry, RpcUtxosByAddressesEntry};
#[cfg(test)]
use kaspa_stealth::EPHEMERAL_OUTPUT_SIZE;
use kaspa_stealth::{check_view_tag, derive_spending_key, scan_output, StealthAddress};
use kaspa_txscript::{extract_stealth_output, STEALTH_SCRIPT_VERSION};
use kaspa_utils::hex::ToHex;
use secp256k1::{PublicKey, SecretKey, XOnlyPublicKey, SECP256K1};
use std::collections::{HashMap, HashSet, VecDeque};
use std::io::{Error as IoError, ErrorKind as IoErrorKind, Result as IoResult};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use workflow_core::time::Instant;

// ============================================================================
// CONSTANTS
// ============================================================================

/// Account kind identifier for stealth accounts
pub const STEALTH_ACCOUNT_KIND: &str = "kaspa-stealth";

/// BIP-44 coin type for stealth derivation (custom, as per etap3_answers.md)
pub const STEALTH_COIN_TYPE: u32 = 111111;

/// Derivation path change index for spend key: m/44'/111111'/account'/0'/0
pub const STEALTH_SPEND_CHANGE: u32 = 0;

/// Derivation path change index for scan key: m/44'/111111'/account'/1'/0
pub const STEALTH_SCAN_CHANGE: u32 = 1;

/// How far (in DAA score) fallback scanning is allowed to rewind behind `creation_daa_score`.
const DEFAULT_FALLBACK_SCAN_LOOKBACK_DAA: u64 = 1_000_000;
const FALLBACK_PROGRESS_REPORT_INTERVAL: usize = 200;
const FALLBACK_PROGRESS_REPORT_INTERVAL_SECS: u64 = 5;
static FALLBACK_SCAN_LOOKBACK_OVERRIDE: AtomicU64 = AtomicU64::new(0);

fn fallback_scan_lookback_daa() -> u64 {
    match FALLBACK_SCAN_LOOKBACK_OVERRIDE.load(Ordering::Relaxed) {
        0 => DEFAULT_FALLBACK_SCAN_LOOKBACK_DAA,
        override_val => override_val,
    }
}

// ============================================================================
// PAYLOAD (Serializable storage data)
// ============================================================================

/// Serializable payload stored in AccountStorage.
/// Contains public keys (for identification) and account metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Payload {
    /// Account index in HD derivation tree
    pub account_index: u64,

    /// Compressed scan public key (32 bytes x-only)
    pub scan_pubkey: Vec<u8>,

    /// Compressed spend public key (32 bytes x-only)
    pub spend_pubkey: Vec<u8>,

    /// DAA score when account was created (for faster restoration scanning)
    pub creation_daa_score: Option<u64>,

    /// Optional anchor of the linked MLDSA master account (Iteration 3)
    pub master_anchor: Option<[u8; 32]>,

    /// Reserved for Iteration 4 (delegations)
    pub delegation_id: Option<u64>,
}

impl Payload {
    pub fn new(
        account_index: u64,
        scan_pubkey: XOnlyPublicKey,
        spend_pubkey: XOnlyPublicKey,
        creation_daa_score: Option<u64>,
        master_anchor: Option<[u8; 32]>,
        delegation_id: Option<u64>,
    ) -> Self {
        Self {
            account_index,
            scan_pubkey: scan_pubkey.serialize().to_vec(),
            spend_pubkey: spend_pubkey.serialize().to_vec(),
            creation_daa_score,
            master_anchor,
            delegation_id,
        }
    }

    pub fn try_load(storage: &AccountStorage) -> Result<Self> {
        Ok(Self::try_from_slice(storage.serialized.as_slice())?)
    }

    pub fn scan_pubkey(&self) -> Result<XOnlyPublicKey> {
        XOnlyPublicKey::from_slice(&self.scan_pubkey).map_err(|e| Error::Custom(format!("Invalid scan pubkey: {}", e)))
    }

    pub fn spend_pubkey(&self) -> Result<XOnlyPublicKey> {
        XOnlyPublicKey::from_slice(&self.spend_pubkey).map_err(|e| Error::Custom(format!("Invalid spend pubkey: {}", e)))
    }
}

impl Storable for Payload {
    const STORAGE_MAGIC: u32 = 0x53544C48; // "STLH"
    const STORAGE_VERSION: u32 = 1;
}

impl AccountStorable for Payload {}

impl BorshSerialize for Payload {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        StorageHeader::new(Self::STORAGE_MAGIC, Self::STORAGE_VERSION).serialize(writer)?;
        BorshSerialize::serialize(&self.account_index, writer)?;
        BorshSerialize::serialize(&self.scan_pubkey, writer)?;
        BorshSerialize::serialize(&self.spend_pubkey, writer)?;
        BorshSerialize::serialize(&self.creation_daa_score, writer)?;
        BorshSerialize::serialize(&self.master_anchor, writer)?;
        BorshSerialize::serialize(&self.delegation_id, writer)?;
        Ok(())
    }
}

impl BorshDeserialize for Payload {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> IoResult<Self> {
        let StorageHeader { version, .. } = StorageHeader::deserialize_reader(reader)?.try_magic(Self::STORAGE_MAGIC)?;

        let (account_index, scan_pubkey, spend_pubkey, creation_daa_score, master_anchor, delegation_id) = match version {
            0 => {
                let account_index = BorshDeserialize::deserialize_reader(reader)?;
                let scan_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
                let spend_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
                let creation_daa_score = BorshDeserialize::deserialize_reader(reader)?;
                (account_index, scan_pubkey, spend_pubkey, creation_daa_score, None, None)
            }
            1 => {
                let account_index = BorshDeserialize::deserialize_reader(reader)?;
                let scan_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
                let spend_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
                let creation_daa_score = BorshDeserialize::deserialize_reader(reader)?;
                let master_anchor = BorshDeserialize::deserialize_reader(reader)?;
                let delegation_id = BorshDeserialize::deserialize_reader(reader)?;
                (account_index, scan_pubkey, spend_pubkey, creation_daa_score, master_anchor, delegation_id)
            }
            other => return Err(IoError::new(IoErrorKind::InvalidData, format!("invalid stealth payload version {other}"))),
        };

        // Validate key lengths (must be 32 bytes for x-only)
        if scan_pubkey.len() != 32 {
            return Err(IoError::new(
                IoErrorKind::InvalidData,
                format!("invalid scan_pubkey length: expected 32, got {}", scan_pubkey.len()),
            ));
        }
        if spend_pubkey.len() != 32 {
            return Err(IoError::new(
                IoErrorKind::InvalidData,
                format!("invalid spend_pubkey length: expected 32, got {}", spend_pubkey.len()),
            ));
        }

        Ok(Self { account_index, scan_pubkey, spend_pubkey, creation_daa_score, master_anchor, delegation_id })
    }
}

// ============================================================================
// UNLOCKED KEYS (In-memory only when unlocked)
// ============================================================================

/// Decrypted stealth keys held in memory during an unlocked session.
/// These are securely erased when the account is locked.
pub struct UnlockedStealthKeys {
    /// Private key for scanning incoming transactions
    pub scan_secret: SecretKey,
    /// Private key for spending
    pub spend_secret: SecretKey,
}

impl Drop for UnlockedStealthKeys {
    fn drop(&mut self) {
        // SecretKey::non_secure_erase() is provided by secp256k1 via impl_non_secure_erase! macro.
        // It correctly overwrites the internal [u8; 32] without requiring unsafe code.
        self.scan_secret.non_secure_erase();
        self.spend_secret.non_secure_erase();
    }
}

#[derive(Default)]
struct PendingEphemeralPersist {
    queue: VecDeque<TransactionOutpoint>,
    dirty: bool,
}

impl PendingEphemeralPersist {
    fn new() -> Self {
        Self { queue: VecDeque::new(), dirty: false }
    }

    fn mark_dirty(&mut self, outpoint: TransactionOutpoint) {
        self.queue.push_back(outpoint);
        self.dirty = true;
    }

    fn len(&self) -> usize {
        self.queue.len()
    }

    fn is_dirty(&self) -> bool {
        self.dirty
    }

    async fn try_flush(
        &mut self,
        secret: Option<&Secret>,
        wallet_folder: Option<&str>,
        network_id: Option<NetworkId>,
        store: &EphemeralKeyStore,
    ) -> Result<()> {
        if !self.dirty {
            return Ok(());
        }

        let Some(secret) = secret else {
            return Err(Error::Custom("wallet secret unavailable".to_string()));
        };

        let Some(wallet_folder) = wallet_folder else {
            return Ok(());
        };

        let Some(network_id) = network_id else {
            return Ok(());
        };

        store.save_to_storage(wallet_folder, network_id, secret).await?;
        self.queue.clear();
        self.dirty = false;
        Ok(())
    }
}

// ============================================================================
// KEY DERIVATION
// ============================================================================

/// Derives stealth keys from an extended private key using BIP-44 paths.
pub struct StealthKeyDerivation {
    pub scan_secret: SecretKey,
    pub spend_secret: SecretKey,
    pub scan_pubkey: XOnlyPublicKey,
    pub spend_pubkey: XOnlyPublicKey,
}

impl StealthKeyDerivation {
    /// Derives stealth keys from xprv using BIP-44 paths:
    /// - Spend: m/44'/111111'/account'/0'/0
    /// - Scan:  m/44'/111111'/account'/1'/0
    pub fn from_xprv(xprv: &ExtendedPrivateKey<SecretKey>, account_index: u64) -> Result<Self> {
        use std::str::FromStr;

        // Derive spend key: m/44'/111111'/account'/0'/0
        let spend_path_str = format!("m/44'/{}'/{}'/{}'/{}", STEALTH_COIN_TYPE, account_index, STEALTH_SPEND_CHANGE, 0);
        let spend_path = kaspa_bip32::DerivationPath::from_str(&spend_path_str)
            .map_err(|e| Error::Custom(format!("Invalid spend derivation path: {}", e)))?;
        let spend_xprv = xprv.clone().derive_path(&spend_path)?;
        let spend_secret = *spend_xprv.private_key();
        let spend_pubkey_full = PublicKey::from_secret_key(SECP256K1, &spend_secret);
        let (spend_pubkey, _parity) = spend_pubkey_full.x_only_public_key();

        // Derive scan key: m/44'/111111'/account'/1'/0
        let scan_path_str = format!("m/44'/{}'/{}'/{}'/{}", STEALTH_COIN_TYPE, account_index, STEALTH_SCAN_CHANGE, 0);
        let scan_path = kaspa_bip32::DerivationPath::from_str(&scan_path_str)
            .map_err(|e| Error::Custom(format!("Invalid scan derivation path: {}", e)))?;
        let scan_xprv = xprv.clone().derive_path(&scan_path)?;
        let scan_secret = *scan_xprv.private_key();
        let scan_pubkey_full = PublicKey::from_secret_key(SECP256K1, &scan_secret);
        let (scan_pubkey, _parity) = scan_pubkey_full.x_only_public_key();

        Ok(Self { scan_secret, spend_secret, scan_pubkey, spend_pubkey })
    }

    /// Creates a StealthAddress from the derived public keys
    pub fn to_stealth_address(&self) -> StealthAddress {
        StealthAddress { scan_pubkey: self.scan_pubkey, spend_pubkey: self.spend_pubkey }
    }

    /// Creates unlocked keys structure (consumes self to avoid copies)
    pub fn into_unlocked_keys(self) -> UnlockedStealthKeys {
        UnlockedStealthKeys { scan_secret: self.scan_secret, spend_secret: self.spend_secret }
    }
}

// ============================================================================
// FACTORY
// ============================================================================

pub struct Ctor {}

#[async_trait]
impl crate::factory::Factory for Ctor {
    fn name(&self) -> String {
        "stealth".to_string()
    }

    fn description(&self) -> String {
        "Stealth Address Account (privacy-preserving)".to_string()
    }

    async fn try_load(
        &self,
        wallet: &Arc<Wallet>,
        storage: &AccountStorage,
        meta: Option<Arc<AccountMetadata>>,
    ) -> Result<Arc<dyn Account>> {
        Ok(Arc::new(StealthAccount::try_load(wallet, storage, meta).await?))
    }
}

// ============================================================================
// STEALTH ACCOUNT
// ============================================================================

pub struct StealthAccount {
    inner: Arc<Inner>,
    prv_key_data_id: PrvKeyDataId,
    account_index: u64,

    /// Public key for scanning incoming transactions (32 bytes x-only)
    scan_pubkey: XOnlyPublicKey,

    /// Public key for spending (32 bytes x-only)
    spend_pubkey: XOnlyPublicKey,

    /// Stealth address for receiving funds
    stealth_address: StealthAddress,

    /// Unlocked keys (populated after unlock())
    unlocked_keys: Arc<AsyncRwLock<Option<UnlockedStealthKeys>>>,
    wallet_secret_cache: Arc<AsyncRwLock<Option<Secret>>>,

    /// Ephemeral key store for spending received UTXOs
    ephemeral_keys: Arc<EphemeralKeyStore>,
    pending_ephemeral_persist: Arc<AsyncMutex<PendingEphemeralPersist>>,

    /// DAA score when account was created
    creation_daa_score: Option<u64>,

    /// Optional master anchor link (Iteration 3)
    master_anchor: Mutex<Option<[u8; 32]>>,

    /// Reserved for delegation id (Iteration 4)
    delegation_id: Mutex<Option<DelegationId>>,

    /// Orphan overlay map (Iteration 5)
    orphan_overlay: Arc<DashMap<TransactionOutpoint, OrphanOverlayEntry>>,
}

#[allow(dead_code)]
#[derive(Clone, Debug)]
struct OrphanOverlayEntry {
    reason: OrphanReason,
    first_marked_daa: u64,
}

fn delegation_window_ok(record: &DelegationRecordV1, current_daa: u64) -> bool {
    if current_daa == 0 {
        return true;
    }
    if record.valid_from_daa > current_daa {
        return false;
    }
    match record.valid_until_daa {
        Some(until) => current_daa <= until,
        None => true,
    }
}

fn select_delegation_from_records(
    block_daa: u64,
    candidates: Vec<(DelegationId, DelegationRecordV1)>,
) -> (Option<DelegationId>, Option<DelegationRecordV1>, Option<OrphanReason>) {
    if candidates.is_empty() {
        return (None, None, Some(OrphanReason::NoDelegation));
    }

    let mut covering: Option<(DelegationId, DelegationRecordV1)> = None;
    for (id, rec) in candidates.iter().cloned() {
        if !matches!(rec.status, DelegationStatus::Active) {
            continue;
        }
        let starts = rec.valid_from_daa <= block_daa;
        let ends = rec.valid_until_daa.map(|u| block_daa <= u).unwrap_or(true);
        if starts && ends && covering.as_ref().map(|c| rec.nonce > c.1.nonce).unwrap_or(true) {
            covering = Some((id, rec));
        }
    }

    if let Some((id, rec)) = covering {
        return (Some(id), Some(rec), None);
    }

    let max_until = candidates.iter().filter_map(|(_, r)| r.valid_until_daa).max();
    if let Some(limit) = max_until {
        if block_daa > limit {
            return (None, None, Some(OrphanReason::DelegationExpired));
        }
    }

    (None, None, Some(OrphanReason::NoDelegation))
}

impl StealthAccount {
    const DELEGATION_WARN_WINDOW_DAA: u64 = 1_000;

    /// Returns the spend pubkey (XOnly) for this stealth account.
    pub fn spend_pubkey(&self) -> Result<XOnlyPublicKey> {
        Ok(self.spend_pubkey)
    }

    /// Returns the scan pubkey (XOnly) for this stealth account.
    pub fn scan_pubkey(&self) -> Result<XOnlyPublicKey> {
        Ok(self.scan_pubkey)
    }
    // ========================================================================
    // CONSTRUCTION
    // ========================================================================

    pub fn override_fallback_scan_lookback_for_testing(value: u64) {
        FALLBACK_SCAN_LOOKBACK_OVERRIDE.store(value, Ordering::Relaxed);
    }

    /// Creates a new stealth account
    pub async fn try_new(
        wallet: &Arc<Wallet>,
        name: Option<String>,
        prv_key_data_id: PrvKeyDataId,
        account_index: u64,
        scan_pubkey: XOnlyPublicKey,
        spend_pubkey: XOnlyPublicKey,
        creation_daa_score: Option<u64>,
    ) -> Result<Self> {
        let stealth_address = StealthAddress { scan_pubkey, spend_pubkey };

        let storable = Payload::new(account_index, scan_pubkey, spend_pubkey, creation_daa_score, None, None);

        let settings = AccountSettings { name, ..Default::default() };

        let (id, storage_key) = make_account_hashes(crate::deterministic::from_stealth(&prv_key_data_id, &storable));
        let inner = Arc::new(Inner::new(wallet, id, storage_key, settings));

        let ephemeral_keys = Arc::new(EphemeralKeyStore::new(id));

        Ok(Self {
            inner,
            prv_key_data_id,
            account_index,
            scan_pubkey,
            spend_pubkey,
            stealth_address,
            unlocked_keys: Arc::new(AsyncRwLock::new(None)),
            wallet_secret_cache: Arc::new(AsyncRwLock::new(None)),
            ephemeral_keys,
            pending_ephemeral_persist: Arc::new(AsyncMutex::new(PendingEphemeralPersist::new())),
            creation_daa_score,
            master_anchor: Mutex::new(None),
            delegation_id: Mutex::new(None),
            orphan_overlay: Arc::new(DashMap::new()),
        })
    }

    /// Testing helper: override stored creation DAA score to control fallback window.
    ///
    /// # Safety
    /// This uses interior mutation to adjust an immutable field and is intended strictly for tests.
    pub fn override_creation_daa_score_for_testing(&self, value: Option<u64>) {
        unsafe {
            let ptr = self as *const Self as *mut Self;
            (*ptr).creation_daa_score = value;
        }
    }

    /// Loads an existing stealth account from storage
    pub async fn try_load(wallet: &Arc<Wallet>, storage: &AccountStorage, _meta: Option<Arc<AccountMetadata>>) -> Result<Self> {
        let payload = Payload::try_load(storage)?;
        let prv_key_data_id: PrvKeyDataId = storage.prv_key_data_ids.clone().try_into()?;
        let inner = Arc::new(Inner::from_storage(wallet, storage));

        let scan_pubkey = payload.scan_pubkey()?;
        let spend_pubkey = payload.spend_pubkey()?;
        let stealth_address = StealthAddress { scan_pubkey, spend_pubkey };

        // Use storage.id directly since Inner.id is private
        let ephemeral_keys = Arc::new(EphemeralKeyStore::new(storage.id));

        let account = Self {
            inner,
            prv_key_data_id,
            account_index: payload.account_index,
            scan_pubkey,
            spend_pubkey,
            stealth_address,
            unlocked_keys: Arc::new(AsyncRwLock::new(None)),
            wallet_secret_cache: Arc::new(AsyncRwLock::new(None)),
            ephemeral_keys,
            pending_ephemeral_persist: Arc::new(AsyncMutex::new(PendingEphemeralPersist::new())),
            creation_daa_score: payload.creation_daa_score,
            master_anchor: Mutex::new(payload.master_anchor),
            delegation_id: Mutex::new(payload.delegation_id.map(DelegationId)),
            orphan_overlay: Arc::new(DashMap::new()),
        };

        if let Some(id) = account.delegation_id() {
            let anchor =
                account.master_anchor().ok_or_else(|| Error::Custom("delegation_id present without master_anchor".to_string()))?;
            let store = wallet.delegation_store();
            let record = store.by_id(id).ok_or_else(|| Error::Custom("delegation not found in store".to_string()))?;
            account.validate_delegation_record(&record, Some(anchor))?;
            let current_daa = account.wallet().utxo_processor().current_daa_score().unwrap_or(0);
            if !matches!(record.status, DelegationStatus::Active) || !account.delegation_window_ok(&record, current_daa) {
                return Err(Error::Custom("delegation inactive or outside validity window".to_string()));
            }
        }

        Ok(account)
    }

    // ========================================================================
    // UNLOCK / LOCK SESSION
    // ========================================================================

    /// Unlocks the account by decrypting and caching the stealth keys.
    /// Must be called before scanning or claiming UTXOs.
    pub async fn unlock(&self, wallet_secret: &Secret, payment_secret: Option<&Secret>) -> Result<()> {
        let prv_key_data = self.prv_key_data(wallet_secret.clone()).await?;
        let payload = prv_key_data.payload.decrypt(payment_secret)?;
        let xprv = payload.get_xprv(payment_secret)?;

        let derivation = StealthKeyDerivation::from_xprv(&xprv, self.account_index)?;

        let mut keys = self.unlocked_keys.write().await;
        *keys = Some(derivation.into_unlocked_keys());
        let mut cached = self.wallet_secret_cache.write().await;
        *cached = Some(wallet_secret.clone());

        // Load ephemeral keys from storage
        if let Ok(StorageDescriptor::Internal(wallet_folder)) = self.wallet().store().location() {
            if let Ok(network_id) = self.wallet().network_id() {
                let _ = self.ephemeral_keys.load_from_storage(&wallet_folder, network_id, wallet_secret).await;
            }
        }
        self.rebuild_orphan_overlay_from_store();

        self.register_cached_stealth_outpoints();
        if let Err(err) = self.flush_pending_ephemeral_keys().await {
            log_warn!("Failed to flush pending stealth keys after unlock: {}", err);
        }

        Ok(())
    }

    /// Locks the account by clearing cached keys from memory.
    pub async fn lock(&self) {
        let mut keys = self.unlocked_keys.write().await;
        // Keys will be zeroized on drop via UnlockedStealthKeys::drop()
        *keys = None;
        if let Err(err) = self.flush_pending_ephemeral_keys().await {
            log_warn!("Failed to flush pending stealth keys before lock: {}", err);
        }
        let mut cached = self.wallet_secret_cache.write().await;
        *cached = None;
        self.orphan_overlay.clear();
    }

    /// Returns true if the account is currently unlocked
    pub async fn is_unlocked(&self) -> bool {
        self.unlocked_keys.read().await.is_some()
    }

    // ========================================================================
    // ACCESSORS
    // ========================================================================

    pub fn stealth_address(&self) -> &StealthAddress {
        &self.stealth_address
    }

    pub fn ephemeral_keys(&self) -> &Arc<EphemeralKeyStore> {
        &self.ephemeral_keys
    }

    pub fn account_index(&self) -> u64 {
        self.account_index
    }

    pub fn master_anchor(&self) -> Option<[u8; 32]> {
        *self.master_anchor.lock().unwrap()
    }

    pub fn delegation_id(&self) -> Option<DelegationId> {
        *self.delegation_id.lock().unwrap()
    }

    fn rebuild_orphan_overlay_from_store(&self) {
        self.orphan_overlay.clear();
        for entry in self.ephemeral_keys.entries() {
            if let EphemeralKeyStatus::Orphaned { reason } = entry.status {
                self.orphan_overlay.insert(entry.outpoint, OrphanOverlayEntry { reason, first_marked_daa: entry.created_daa_score });
            }
        }
    }

    fn mark_orphan_overlay(&self, outpoint: TransactionOutpoint, reason: OrphanReason, current_daa: u64) {
        self.orphan_overlay.insert(outpoint, OrphanOverlayEntry { reason, first_marked_daa: current_daa });
    }

    fn apply_orphan_filter(&self, mut settings: GeneratorSettings) -> GeneratorSettings {
        let overlay = self.orphan_overlay.clone();
        if overlay.is_empty() {
            return settings;
        }
        let iter = settings.utxo_iterator;
        let overlay_for_iter = overlay.clone();
        let filtered_iter = iter.filter(move |entry| {
            let op = entry.outpoint();
            let key = TransactionOutpoint::new(op.transaction_id(), op.index());
            !overlay_for_iter.contains_key(&key)
        });
        settings.utxo_iterator = Box::new(filtered_iter);

        if let Some(priority) = settings.priority_utxo_entries.as_mut() {
            let overlay_for_priority = overlay.clone();
            priority.retain(|entry| {
                let op = entry.outpoint();
                let key = TransactionOutpoint::new(op.transaction_id(), op.index());
                !overlay_for_priority.contains_key(&key)
            });
        }
        settings
    }

    /// Returns settings optionally пропуская фильтрацию orphan-UTXO.
    /// По умолчанию (allow_orphans = false) orphan-выходы скрываются.
    pub fn apply_orphan_filter_with_override(&self, settings: GeneratorSettings, allow_orphans: bool) -> GeneratorSettings {
        if allow_orphans {
            settings
        } else {
            self.apply_orphan_filter(settings)
        }
    }

    fn select_delegation_for_utxo(&self, block_daa: u64) -> (Option<DelegationId>, Option<DelegationRecordV1>, Option<OrphanReason>) {
        let Some(anchor) = self.master_anchor() else {
            // Обычный стелс-аккаунт без master: считаем UTXO валидным, не помечаем orphan.
            return (None, None, None);
        };

        let store = self.wallet().delegation_store();
        let candidates: Vec<(DelegationId, DelegationRecordV1)> =
            store.by_anchor(&anchor).into_iter().filter(|(_, rec)| rec.account_id == *self.id()).collect();

        if candidates.is_empty() {
            return (None, None, Some(OrphanReason::AnchorMismatch));
        }

        select_delegation_from_records(block_daa, candidates)
    }

    fn mark_delegation_as_orphaned(&self, delegation_id: DelegationId, reason: OrphanReason, current_daa: u64) {
        for entry in self.ephemeral_keys.entries() {
            if entry.delegation_id == Some(delegation_id.0) {
                let reason_clone = reason.clone();
                self.ephemeral_keys.set_status(entry.outpoint, EphemeralKeyStatus::Orphaned { reason: reason_clone.clone() });
                self.mark_orphan_overlay(entry.outpoint, reason_clone, current_daa);
            }
        }
    }

    fn validate_delegation_record(&self, record: &DelegationRecordV1, expected_anchor: Option<[u8; 32]>) -> Result<()> {
        let anchor = expected_anchor.ok_or_else(|| Error::Custom("delegation_id set but master_anchor is missing".to_string()))?;
        if record.anchor != anchor {
            return Err(Error::Custom("delegation anchor mismatch".to_string()));
        }
        if record.account_id != *self.id() {
            return Err(Error::Custom("delegation account mismatch".to_string()));
        }
        if record.scan_pubkey != self.scan_pubkey.serialize() || record.spend_pubkey != self.spend_pubkey.serialize() {
            return Err(Error::Custom("delegation pubkeys mismatch".to_string()));
        }
        Ok(())
    }

    fn delegation_window_ok(&self, record: &DelegationRecordV1, current_daa: u64) -> bool {
        delegation_window_ok(record, current_daa)
    }

    async fn delegation_metadata(&self) -> Result<(Option<[u8; 32]>, Option<DelegationId>)> {
        let anchor = match self.master_anchor() {
            Some(a) => a,
            None => return Ok((None, None)),
        };

        let store = self.wallet().delegation_store().clone();
        let current_daa = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);

        // Try explicit delegation id first
        if let Some(id) = self.delegation_id() {
            if let Some(record) = store.by_id(id) {
                if matches!(record.status, crate::account::delegation::DelegationStatus::Active)
                    && self.delegation_window_ok(&record, current_daa)
                    && self.validate_delegation_record(&record, Some(anchor)).is_ok()
                {
                    return Ok((Some(anchor), Some(id)));
                }
            }
        }

        // Fallback to active record from store
        if let Some((id, record)) = store.active_for_account(&anchor, self.id()) {
            if self.delegation_window_ok(&record, current_daa) && self.validate_delegation_record(&record, Some(anchor)).is_ok() {
                let mut slot = self.delegation_id.lock().unwrap();
                *slot = Some(id);
                return Ok((Some(anchor), Some(id)));
            }
        }

        Ok((Some(anchor), None))
    }

    pub fn attach_to_master(&self, anchor: [u8; 32]) {
        let mut anchor_slot = self.master_anchor.lock().unwrap();
        *anchor_slot = Some(anchor);
        let mut delegation_slot = self.delegation_id.lock().unwrap();
        *delegation_slot = None;
    }

    pub fn detach_master(&self) {
        let mut anchor_slot = self.master_anchor.lock().unwrap();
        *anchor_slot = None;
        let mut delegation_slot = self.delegation_id.lock().unwrap();
        *delegation_slot = None;
    }

    pub fn set_delegation(&self, anchor: [u8; 32], delegation_id: Option<DelegationId>) {
        let mut anchor_slot = self.master_anchor.lock().unwrap();
        *anchor_slot = Some(anchor);
        let mut delegation_slot = self.delegation_id.lock().unwrap();
        *delegation_slot = delegation_id;
    }

    // ========================================================================
    // STEALTH CHANGE CREATOR
    // ========================================================================

    /// Creates a StealthChangeCreator for use with Generator.
    /// Requires the account to be unlocked.
    pub async fn create_change_creator(&self) -> Result<DynStealthChangeCreator> {
        let keys = self.unlocked_keys.read().await;
        let keys_ref = keys.as_ref().ok_or(Error::AccountLocked)?;

        Ok(Arc::new(StealthChangeCreatorImpl { stealth_address: self.stealth_address, spend_secret: keys_ref.spend_secret }))
    }

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================

    fn register_cached_stealth_outpoints(&self) {
        let processor = self.wallet().utxo_processor();
        for outpoint in self.ephemeral_keys.outpoints() {
            processor.register_stealth_outpoint(outpoint, *self.id());
        }
    }

    async fn flush_pending_ephemeral_keys(&self) -> Result<()> {
        {
            let pending = self.pending_ephemeral_persist.lock().await;
            if !pending.is_dirty() {
                return Ok(());
            }
        }

        let secret = { self.wallet_secret_cache.read().await.clone() };
        let wallet_folder = match self.wallet().store().location() {
            Ok(StorageDescriptor::Internal(path)) => Some(path),
            _ => None,
        };
        let network_id = self.wallet().network_id().ok();

        {
            let mut pending = self.pending_ephemeral_persist.lock().await;
            pending.try_flush(secret.as_ref(), wallet_folder.as_deref(), network_id, &self.ephemeral_keys).await?;
        }

        Ok(())
    }

    async fn note_pending_ephemeral_key(&self, outpoint: TransactionOutpoint) {
        {
            let mut pending = self.pending_ephemeral_persist.lock().await;
            pending.mark_dirty(outpoint);
        }

        if let Err(err) = self.flush_pending_ephemeral_keys().await {
            let pending_len = {
                let pending = self.pending_ephemeral_persist.lock().await;
                pending.len()
            };
            log_warn!("Stealth key persistence deferred ({} pending entries): {}", pending_len, err);
        }
    }

    fn fallback_progress_event(account_id: AccountId, processed_blocks: u64, last_daa_score: u64, claimed: u64) -> Events {
        Events::StealthScanProgress { account_id, processed_blocks, last_daa_score, claimed }
    }

    fn should_emit_fallback_progress(processed_blocks: usize, elapsed_secs_since_last_emit: u64) -> bool {
        processed_blocks > 0
            && (processed_blocks % FALLBACK_PROGRESS_REPORT_INTERVAL == 0
                || elapsed_secs_since_last_emit >= FALLBACK_PROGRESS_REPORT_INTERVAL_SECS)
    }

    async fn emit_fallback_progress(&self, processed_blocks: u64, last_daa_score: u64, claimed: u64) {
        log_info!(
            "Stealth fallback progress for {}: processed {} blocks (daa {}), claimed {} UTXOs",
            self.id().short(),
            processed_blocks,
            last_daa_score,
            claimed
        );

        let event = Self::fallback_progress_event(*self.id(), processed_blocks, last_daa_score, claimed);
        if let Err(err) = self.wallet().notify(event).await {
            log_warn!("Failed to emit stealth fallback progress: {}", err);
        }
    }

    fn stealth_entry_from_transaction_output(
        tx_id: RpcTransactionId,
        output_index: u32,
        output: &kaspa_rpc_core::RpcTransactionOutput,
        block_daa_score: u64,
        is_coinbase: bool,
    ) -> Option<(TransactionOutpoint, RpcUtxoEntry)> {
        if output.script_public_key.version() != STEALTH_SCRIPT_VERSION {
            return None;
        }

        // Ensure script encodes a valid stealth payload before accepting it.
        extract_stealth_output(&output.script_public_key).ok()?;

        let outpoint = TransactionOutpoint::new(tx_id, output_index);
        let utxo_entry = RpcUtxoEntry::new(output.value, output.script_public_key.clone(), block_daa_score, is_coinbase);

        Some((outpoint, utxo_entry))
    }

    fn resolve_transaction_id(tx: &kaspa_rpc_core::RpcTransaction, tx_index: usize) -> Option<RpcTransactionId> {
        if let Some(verbose) = tx.verbose_data.as_ref() {
            return Some(verbose.transaction_id);
        }

        match Transaction::try_from(tx.clone()) {
            Ok(cons_tx) => Some(cons_tx.id()),
            Err(err) => {
                log_warn!("Stealth fallback: failed to derive transaction id for tx index {} (error: {})", tx_index, err);
                None
            }
        }
    }

    fn collect_live_stealth_utxos(block: &RpcBlock) -> Vec<(TransactionOutpoint, RpcUtxoEntry)> {
        let block_daa_score = block.header.daa_score;
        let mut live_entries: HashMap<TransactionOutpoint, RpcUtxoEntry> = HashMap::new();

        for (tx_index, tx) in block.transactions.iter().enumerate() {
            let Some(tx_id) = Self::resolve_transaction_id(tx, tx_index) else {
                continue;
            };

            let is_coinbase = tx.subnetwork_id == subnets::SUBNETWORK_ID_COINBASE;

            for (output_index, output) in tx.outputs.iter().enumerate() {
                if let Some((outpoint, utxo_entry)) =
                    Self::stealth_entry_from_transaction_output(tx_id, output_index as u32, output, block_daa_score, is_coinbase)
                {
                    live_entries.insert(outpoint, utxo_entry);
                }
            }

            for input in tx.inputs.iter() {
                let spent: TransactionOutpoint = input.previous_outpoint.into();
                live_entries.remove(&spent);
            }
        }

        live_entries.into_iter().collect()
    }

    async fn process_potential_entry(
        &self,
        entry: &RpcUtxosByAddressesEntry,
        updated_contexts: &mut Vec<UtxoContext>,
        current_daa_score: u64,
    ) -> Result<bool> {
        let outpoint: TransactionOutpoint = entry.outpoint.into();
        if Account::utxo_context(self).contains_outpoint(&outpoint) {
            return Ok(false);
        }

        if let Some(context) = self.try_claim_utxo(entry).await {
            let utxo_ref: crate::utxo::UtxoEntryReference = entry.into();
            context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
            if !updated_contexts.iter().any(|c| c.id() == context.id()) {
                updated_contexts.push(context);
            }
            return Ok(true);
        }

        Ok(false)
    }

    async fn scan_via_utxoindex(&self, rpc: &Arc<DynRpcApi>, current_daa_score: u64) -> Result<bool> {
        let mut cursor = None;
        let limit = Some(1000u32);
        let mut total_claimed = 0usize;
        let mut updated_contexts: Vec<UtxoContext> = Vec::new();

        loop {
            let response = match rpc.get_utxos_by_script_version(STEALTH_SCRIPT_VERSION, cursor, limit).await {
                Ok(r) => r,
                Err(e) => {
                    let err_str = e.to_string();
                    if err_str.contains("not yet supported over gRPC")
                        || err_str.contains("not supported")
                        || err_str.contains("utxo index")
                        || err_str.contains("utxoindex")
                        || err_str.contains("Method unavailable")
                    {
                        return Ok(false);
                    }
                    return Err(Error::Custom(format!("RPC error during stealth scan: {}", err_str)));
                }
            };

            if response.entries.is_empty() {
                break;
            }

            for entry in response.entries.iter() {
                let utxo_entry =
                    RpcUtxosByAddressesEntry { address: None, outpoint: entry.outpoint, utxo_entry: entry.utxo_entry.clone() };
                if self.process_potential_entry(&utxo_entry, &mut updated_contexts, current_daa_score).await? {
                    total_claimed += 1;
                }
            }

            cursor = response.next_cursor;
            if cursor.is_none() {
                break;
            }
        }

        for context in updated_contexts.iter() {
            context.update_balance().await?;
        }

        if total_claimed > 0 {
            log_info!("Stealth scan complete via utxoindex: claimed {} UTXOs", total_claimed);
        }

        Ok(true)
    }

    async fn scan_via_view_tags(&self, rpc: &Arc<DynRpcApi>, current_daa_score: u64) -> Result<()> {
        let mut cursor: Option<RpcHash> = None;
        let mut seen_hashes = HashSet::new();
        let mut updated_contexts: Vec<UtxoContext> = Vec::new();
        let mut total_claimed = 0usize;
        let mut encountered_full_blocks = false;
        let mut header_only_encountered = false;
        let mut header_only_before_first_full = false;
        let mut earliest_header_daa: Option<u64> = None;
        let creation_daa_score = self.creation_daa_score.unwrap_or(0);
        let lookback_daa = fallback_scan_lookback_daa();
        let reference_daa = if creation_daa_score == 0 { current_daa_score } else { creation_daa_score };
        let min_daa_score = Some(reference_daa).map(|score| score.saturating_sub(lookback_daa)).filter(|score| *score > 0);
        log_info!(
            "Stealth fallback scanning with lookback DAA {} (creation_daa_score={}, current_daa_score={}, min_daa_score={:?})",
            lookback_daa,
            creation_daa_score,
            current_daa_score,
            min_daa_score
        );
        let mut processed_blocks = 0usize;
        let mut last_processed_daa_score = 0u64;
        let mut last_progress_emit = Instant::now();

        'outer: loop {
            let response =
                rpc.get_blocks(cursor, true, true).await.map_err(|e| Error::Custom(format!("GetBlocks RPC error: {}", e)))?;

            if response.block_hashes.is_empty() {
                break;
            }

            let mut processed_new = false;
            for (idx, hash) in response.block_hashes.iter().enumerate() {
                if cursor.is_some() && idx == 0 {
                    continue;
                }

                if !seen_hashes.insert(*hash) {
                    continue;
                }

                processed_new = true;
                if let Some(block) = response.blocks.get(idx) {
                    if block.transactions.is_empty() {
                        header_only_encountered = true;
                        if !encountered_full_blocks {
                            header_only_before_first_full = true;
                            earliest_header_daa = Some(block.header.daa_score);
                        }
                        log_warn!(
                            "Skipping header-only block {} during stealth fallback (node likely pruned before needed history)",
                            hash
                        );
                        continue;
                    }

                    if let Some(min_daa) = min_daa_score {
                        if block.header.daa_score < min_daa {
                            continue;
                        }
                    }

                    encountered_full_blocks = true;
                    last_processed_daa_score = block.header.daa_score;
                    processed_blocks += 1;
                    let live_outputs = Self::collect_live_stealth_utxos(block);
                    if !live_outputs.is_empty() {
                        log_info!(
                            "Stealth fallback: block {} (daa {}) yielded {} stealth candidates",
                            hash,
                            block.header.daa_score,
                            live_outputs.len()
                        );
                    }
                    for (outpoint, utxo_entry) in live_outputs {
                        let rpc_entry = RpcUtxosByAddressesEntry { address: None, outpoint: outpoint.into(), utxo_entry };
                        if self.process_potential_entry(&rpc_entry, &mut updated_contexts, current_daa_score).await? {
                            total_claimed += 1;
                        }
                    }
                    if Self::should_emit_fallback_progress(processed_blocks, last_progress_emit.elapsed().as_secs()) {
                        self.emit_fallback_progress(processed_blocks as u64, last_processed_daa_score, total_claimed as u64).await;
                        last_progress_emit = Instant::now();
                    }
                }
            }

            if !processed_new {
                break 'outer;
            }

            cursor = response.block_hashes.last().cloned();
            if cursor.is_none() {
                break;
            }
        }

        if !encountered_full_blocks && header_only_encountered {
            return Err(Error::Custom(
                "Stealth block replay fallback requires a node with historical block bodies (current node appears pruned)".into(),
            ));
        }
        if header_only_before_first_full && total_claimed == 0 {
            if let Some(header_daa) = earliest_header_daa {
                if creation_daa_score > 0 && creation_daa_score < header_daa {
                    return Err(Error::Custom(
                        "Stealth fallback detected missing historical block bodies before account creation; please use archival node"
                            .into(),
                    ));
                }
            }
            return Err(Error::Custom(
                "Stealth fallback detected missing historical block bodies before available data (node pruned too aggressively)"
                    .into(),
            ));
        }

        if processed_blocks > 0 {
            self.emit_fallback_progress(processed_blocks as u64, last_processed_daa_score, total_claimed as u64).await;
        }

        for context in updated_contexts.iter() {
            context.update_balance().await?;
        }

        log_info!("Stealth scan via block replay fallback complete: claimed {} UTXOs", total_claimed);

        Ok(())
    }

    /// Internal method to check if UTXO belongs to this account and derive spending key
    async fn try_claim_utxo_internal(&self, utxo: &RpcUtxosByAddressesEntry) -> Result<Option<EphemeralKeyData>> {
        let script = &utxo.utxo_entry.script_public_key;

        // Check script version
        if script.version() != STEALTH_SCRIPT_VERSION {
            return Ok(None);
        }

        // Parse ephemeral output from script
        let ephemeral_output = match extract_stealth_output(script) {
            Ok(output) => output,
            Err(_) => return Ok(None),
        };

        // Get unlocked keys
        let keys = self.unlocked_keys.read().await;
        let keys_ref = keys.as_ref().ok_or(Error::AccountLocked)?;

        // Fast check: View Tag (1 byte comparison) - rejects 255/256 non-matching UTXOs instantly
        if !check_view_tag(&ephemeral_output.ephemeral_pubkey, ephemeral_output.view_tag, &keys_ref.scan_secret) {
            return Ok(None);
        }

        // Full check: Compute and verify destination pubkey via ECDH
        match scan_output(&ephemeral_output, &keys_ref.scan_secret, &self.spend_pubkey) {
            Ok(scan_result) => {
                // Derive spending key: spend_secret + blinding_factor
                let spending_secret = derive_spending_key(&keys_ref.spend_secret, &scan_result.blinding_factor)
                    .map_err(|e| Error::Custom(e.to_string()))?;

                // destination_pubkey comes from ephemeral_output, not scan_result
                // Use new_xonly for 32-byte x-only pubkey
                Ok(Some(EphemeralKeyData::new_xonly(
                    spending_secret.secret_bytes(),
                    scan_result.blinding_factor.to_be_bytes(),
                    ephemeral_output.destination_pubkey.serialize(),
                )))
            }
            Err(_) => Ok(None), // False positive from View Tag collision (~1/256 chance)
        }
    }

    /// Finalizes a stealth change output after transaction submission.
    /// Stores the pre-computed spending key for the change output.
    pub async fn finalize_stealth_change(
        &self,
        tx_id: kaspa_consensus_core::tx::TransactionId,
        pending: &PendingStealthChange,
        _wallet_secret: &Secret,
    ) -> Result<()> {
        let outpoint = TransactionOutpoint::new(tx_id, pending.output_index as u32);

        // Use new_xonly for 32-byte x-only pubkey
        let key_data = EphemeralKeyData::new_xonly(
            pending.spending_secret.secret_bytes(),
            pending.blinding_factor.to_be_bytes(),
            pending.destination_pubkey.serialize(),
        );

        let daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);
        let (anchor, delegation_id) = self.delegation_metadata().await?;

        self.ephemeral_keys.store(outpoint, key_data, daa_score, anchor, delegation_id.map(|d| d.0)).await?;

        // Register in UtxoProcessor's outpoint index
        self.wallet().utxo_processor().register_stealth_outpoint(outpoint, *self.id());

        self.note_pending_ephemeral_key(outpoint).await;
        Ok(())
    }
}

// ============================================================================
// ACCOUNT TRAIT IMPLEMENTATION
// ============================================================================

#[async_trait]
impl Account for StealthAccount {
    fn inner(&self) -> &Arc<Inner> {
        &self.inner
    }

    fn account_kind(&self) -> AccountKind {
        STEALTH_ACCOUNT_KIND.into()
    }

    fn prv_key_data_id(&self) -> Result<&PrvKeyDataId> {
        Ok(&self.prv_key_data_id)
    }

    fn as_dyn_arc(self: Arc<Self>) -> Arc<dyn Account> {
        self
    }

    fn sig_op_count(&self) -> u8 {
        1 // Single Schnorr signature
    }

    fn minimum_signatures(&self) -> u16 {
        1
    }

    /// Returns the stealth address encoded as bech32m (qs1...)
    fn receive_address(&self) -> Result<Address> {
        // CRITICAL: Version::Stealth requires EXACTLY 64 bytes: [32 scan][32 spend]
        // Address::new() will panic if payload != 64 on mainnet/testnet!
        let prefix = self.wallet().address_prefix()?.to_stealth().ok_or(Error::InvalidNetworkPrefix)?;

        let mut payload = [0u8; 64];
        payload[..32].copy_from_slice(&self.scan_pubkey.serialize());
        payload[32..].copy_from_slice(&self.spend_pubkey.serialize());

        Ok(Address::new(prefix, Version::Stealth, &payload))
    }

    /// Change address is the same as receive address for stealth accounts
    fn change_address(&self) -> Result<Address> {
        self.receive_address()
    }

    fn to_storage(&self) -> Result<AccountStorage> {
        let settings = self.context().settings.clone();
        let master_anchor = *self.master_anchor.lock().unwrap();
        let delegation_id = self.delegation_id.lock().unwrap().map(|id| id.0);
        let storable = Payload::new(
            self.account_index,
            self.scan_pubkey,
            self.spend_pubkey,
            self.creation_daa_score,
            master_anchor,
            delegation_id,
        );

        AccountStorage::try_new(
            STEALTH_ACCOUNT_KIND.into(),
            self.id(),
            self.storage_key(),
            self.prv_key_data_id.into(),
            settings,
            storable,
        )
    }

    fn metadata(&self) -> Result<Option<AccountMetadata>> {
        // Stealth accounts don't use address derivation indexes
        Ok(None)
    }

    fn descriptor(&self) -> Result<AccountDescriptor> {
        let mut descriptor = AccountDescriptor::new(
            STEALTH_ACCOUNT_KIND.into(),
            *self.id(),
            self.name(),
            self.balance(),
            self.prv_key_data_id.into(),
            self.receive_address().ok(),
            self.change_address().ok(),
            None, // No derived addresses for stealth accounts
        )
        .with_property(AccountDescriptorProperty::AccountIndex, self.account_index.into());

        if let Some(anchor) = *self.master_anchor.lock().unwrap() {
            descriptor = descriptor
                .with_property(AccountDescriptorProperty::Other("master_anchor".to_string()), anchor.to_vec().to_hex().into());
        }

        if let Some(delegation_id) = *self.delegation_id.lock().unwrap() {
            descriptor =
                descriptor.with_property(AccountDescriptorProperty::Other("delegation_id".to_string()), delegation_id.0.into());
        }

        Ok(descriptor)
    }

    fn as_stealth_account(self: Arc<Self>) -> Result<Arc<StealthAccount>> {
        Ok(self)
    }

    // ========================================================================
    // LIFECYCLE OVERRIDES
    // ========================================================================

    /// Override connect to register stealth handler
    async fn connect(self: Arc<Self>) -> Result<()> {
        // Register stealth handler in UtxoProcessor
        self.wallet().utxo_processor().register_stealth_handler(self.clone()).await?;

        // Standard connect logic
        let vacated = self.wallet().active_accounts().insert(self.clone().as_dyn_arc());
        if vacated.is_none() && self.wallet().is_connected() {
            self.clone().scan(None, None).await?;
        }

        Ok(())
    }

    /// Override disconnect to unregister stealth handler
    async fn disconnect(&self) -> Result<()> {
        // Unregister stealth handler
        self.wallet().utxo_processor().unregister_stealth_handler(self.id()).await?;

        // Standard disconnect logic
        self.wallet().active_accounts().remove(self.id());

        Ok(())
    }

    /// Override stop to also lock the account
    async fn stop(self: Arc<Self>) -> Result<()> {
        self.lock().await;
        Account::utxo_context(&*self).clear().await?;
        self.disconnect().await?;
        Ok(())
    }

    // ========================================================================
    // SENDING (override to support stealth change and stealth inputs)
    // ========================================================================

    async fn send(
        self: Arc<Self>,
        destination: PaymentDestination,
        fee_rate: Option<f64>,
        priority_fee_sompi: Fees,
        random_fee_settings: Option<RandomFeeSettings>,
        payload: Option<Vec<u8>>,
        wallet_secret: Secret,
        payment_secret: Option<Secret>,
        abortable: &Abortable,
        notifier: Option<GenerationNotifier>,
    ) -> Result<(GeneratorSummary, Vec<kaspa_hashes::Hash>)> {
        use crate::tx::generator::{Generator, GeneratorSettings, Signer};
        use futures::TryStreamExt;
        use workflow_core::task::yield_executor;

        // Ensure account is unlocked
        if !self.is_unlocked().await {
            return Err(Error::AccountLocked);
        }

        // Create signer for regular inputs
        let keydata = self.prv_key_data(wallet_secret.clone()).await?;
        let signer = Arc::new(Signer::new(self.clone().as_dyn_arc(), keydata, payment_secret));

        // Create stealth signer for stealth inputs
        let stealth_signer = StealthSigner::new(self.ephemeral_keys.clone());

        // Configure generator with stealth change creator
        let settings = GeneratorSettings::try_new_with_account(
            self.clone().as_dyn_arc(),
            destination,
            fee_rate,
            priority_fee_sompi,
            payload,
            random_fee_settings,
        )?;
        let settings = self.apply_orphan_filter(settings);
        let settings = self.clone().ensure_stealth_change_support(settings).await?;

        let generator = Generator::try_new(settings, Some(signer), Some(abortable))?;

        let mut stream = generator.stream();
        let mut ids = vec![];
        while let Some(transaction) = stream.try_next().await? {
            // Sign regular inputs first
            transaction.try_sign()?;

            // Sign stealth inputs if any
            if transaction.has_stealth_inputs() {
                transaction.try_sign_stealth(&stealth_signer).await?;
            }

            // Submit transaction
            let tx_id = transaction.try_submit(&self.wallet().rpc_api()).await?;

            // Finalize stealth change output if present
            if let Some(pending_change) = transaction.take_stealth_change() {
                self.finalize_stealth_change(tx_id, &pending_change, &wallet_secret).await?;
            }

            ids.push(tx_id);

            if let Some(notifier) = notifier.as_ref() {
                notifier(&transaction);
            }
            yield_executor().await;
        }

        Ok((generator.summary(), ids))
    }

    async fn sweep(
        self: Arc<Self>,
        wallet_secret: Secret,
        payment_secret: Option<Secret>,
        fee_rate: Option<f64>,
        abortable: &Abortable,
        notifier: Option<GenerationNotifier>,
    ) -> Result<(GeneratorSummary, Vec<kaspa_hashes::Hash>)> {
        use crate::tx::generator::{Generator, GeneratorSettings, Signer};
        use futures::TryStreamExt;
        use workflow_core::task::yield_executor;

        let keydata = self.prv_key_data(wallet_secret).await?;
        let signer = Arc::new(Signer::new(self.clone().as_dyn_arc(), keydata, payment_secret));
        let settings = GeneratorSettings::try_new_with_account(
            self.clone().as_dyn_arc(),
            PaymentDestination::Change,
            fee_rate,
            Fees::None,
            None,
            None,
        )?;
        let settings = self.apply_orphan_filter(settings);
        let settings = self.clone().ensure_stealth_change_support(settings).await?;
        let generator = Generator::try_new(settings, Some(signer), Some(abortable))?;

        let mut stream = generator.stream();
        let mut ids = vec![];
        while let Some(transaction) = stream.try_next().await? {
            transaction.try_sign()?;
            ids.push(transaction.try_submit(&self.wallet().rpc_api()).await?);

            if let Some(notifier) = notifier.as_ref() {
                notifier(&transaction);
            }
            yield_executor().await;
        }

        Ok((generator.summary(), ids))
    }

    // ========================================================================
    // SCANNING (simplified for MVP)
    // ========================================================================

    async fn scan(self: Arc<Self>, _window_size: Option<usize>, _extent: Option<u32>) -> Result<()> {
        if !self.is_unlocked().await {
            return Err(Error::AccountLocked);
        }

        // Try to use the get_utxos_by_script_version RPC for full historical scan
        let rpc = self.wallet().rpc_api();

        // Get current DAA score for maturity calculation
        let mut current_daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);

        // Check server capabilities (used for logging / diagnostics)
        let server_info = rpc.get_server_info().await.map_err(|e| Error::Custom(e.to_string()))?;
        if current_daa_score == 0 {
            current_daa_score = server_info.virtual_daa_score;
        }

        if self.scan_via_utxoindex(&rpc, current_daa_score).await? {
            return Ok(());
        }

        if !server_info.has_stealth_support {
            log_warn!("Server lacks stealth-specific RPC extensions; falling back to block replay");
        } else {
            log_info!("Stealth RPC fallback: scanning blocks via block replay");
        }
        self.scan_via_view_tags(&rpc, current_daa_score).await
    }
}

// ============================================================================
// STEALTH UTXO HANDLER IMPLEMENTATION
// ============================================================================

#[async_trait]
impl StealthUtxoHandler for StealthAccount {
    async fn try_claim_utxo(&self, utxo: &RpcUtxosByAddressesEntry) -> Option<UtxoContext> {
        // Must be unlocked to claim
        if !self.is_unlocked().await {
            return None;
        }

        match self.try_claim_utxo_internal(utxo).await {
            Ok(Some(key_data)) => {
                let outpoint = TransactionOutpoint::new(utxo.outpoint.transaction_id, utxo.outpoint.index);

                let block_daa = utxo.utxo_entry.block_daa_score;
                let current_daa = self.wallet().utxo_processor().current_daa_score().unwrap_or(block_daa);
                let safety_margin =
                    self.wallet().utxo_processor().network_params().map(|p| p.user_transaction_maturity_period_daa()).unwrap_or(0);
                let (selected_id, record, orphan_reason) = self.select_delegation_for_utxo(block_daa);
                let anchor = self.master_anchor();
                let delegation_id = selected_id;
                let valid_until = record.as_ref().and_then(|r| r.valid_until_daa.map(|u| u.saturating_add(safety_margin)));

                if let Err(e) = self
                    .ephemeral_keys
                    .store_with_metadata(outpoint, key_data, block_daa, anchor, delegation_id.map(|d| d.0), valid_until)
                    .await
                {
                    log_error!("Failed to store ephemeral key: {}", e);
                    return None;
                }
                let status = match orphan_reason {
                    Some(reason) => {
                        let reason_for_overlay = reason.clone();
                        self.mark_orphan_overlay(outpoint, reason_for_overlay, current_daa);
                        if matches!(reason, OrphanReason::AnchorMismatch) {
                            if let Some(expected) = self.master_anchor() {
                                let _ = self
                                    .wallet()
                                    .notify(Events::MasterAnchorMismatch {
                                        account_id: *self.id(),
                                        expected_anchor: expected,
                                        actual_anchor: [0u8; 32],
                                    })
                                    .await;
                            }
                        }
                        EphemeralKeyStatus::Orphaned { reason }
                    }
                    None => EphemeralKeyStatus::Pending { added_daa_score: block_daa },
                };
                self.ephemeral_keys.set_status(outpoint, status);

                self.wallet().utxo_processor().register_stealth_outpoint(outpoint, *self.id());
                self.note_pending_ephemeral_key(outpoint).await;

                Some(Account::utxo_context(self).clone())
            }
            Ok(None) => None, // Not our UTXO
            Err(e) => {
                log_error!("Error claiming stealth UTXO: {}", e);
                None
            }
        }
    }

    fn utxo_context(&self) -> &UtxoContext {
        &self.inner.utxo_context
    }

    fn account_id(&self) -> &AccountId {
        self.id()
    }

    fn has_outpoint(&self, outpoint: &TransactionOutpoint) -> bool {
        Account::utxo_context(self).contains_outpoint(outpoint)
    }

    async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()> {
        let current_daa = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);
        self.ephemeral_keys.mark_removed(outpoint, current_daa).await?;
        self.orphan_overlay.remove(outpoint);
        Ok(())
    }

    fn ephemeral_key_store(&self) -> Option<Arc<EphemeralKeyStore>> {
        Some(self.ephemeral_keys.clone())
    }

    async fn on_daa_score_changed(&self, current_daa_score: u64) -> Result<()> {
        self.ephemeral_keys.cleanup_expired(current_daa_score);

        let active: HashSet<_> = self.ephemeral_keys.outpoints().into_iter().collect();
        self.orphan_overlay.retain(|outpoint, _| active.contains(outpoint));

        if let Some(anchor) = self.master_anchor() {
            let store = self.wallet().delegation_store();
            let mut expired_events = Vec::new();
            let mut expiring_events = Vec::new();
            let mut revoked_events = Vec::new();

            for (id, rec) in store.by_anchor(&anchor).into_iter().filter(|(_, r)| r.account_id == *self.id()) {
                match rec.status {
                    DelegationStatus::Active => {
                        if let Some(until) = rec.valid_until_daa {
                            if current_daa_score >= until {
                                expired_events.push((id, rec));
                            } else if current_daa_score + Self::DELEGATION_WARN_WINDOW_DAA >= until {
                                expiring_events.push((id, rec));
                            }
                        }
                    }
                    DelegationStatus::Revoked { .. } => revoked_events.push((id, rec)),
                    _ => {}
                }
            }

            for (id, rec) in expiring_events {
                let _ = self
                    .wallet()
                    .notify(Events::MasterDelegationExpiringSoon {
                        account_id: *self.id(),
                        delegation_id: id.0,
                        anchor,
                        valid_until_daa: rec.valid_until_daa.unwrap_or_default(),
                    })
                    .await;
            }

            for (id, rec) in expired_events {
                self.mark_delegation_as_orphaned(id, OrphanReason::DelegationExpired, current_daa_score);
                let _ = self
                    .wallet()
                    .notify(Events::MasterDelegationExpired {
                        account_id: *self.id(),
                        delegation_id: id.0,
                        anchor,
                        valid_until_daa: rec.valid_until_daa.unwrap_or_default(),
                    })
                    .await;
            }

            for (id, _rec) in revoked_events {
                self.mark_delegation_as_orphaned(id, OrphanReason::DelegationRevoked, current_daa_score);
                let _ = self
                    .wallet()
                    .notify(Events::MasterDelegationRevoked { account_id: *self.id(), delegation_id: id.0, anchor })
                    .await;
            }
        }
        Ok(())
    }
}

// ============================================================================
// STEALTH CHANGE CREATOR IMPLEMENTATION
// ============================================================================

struct StealthChangeCreatorImpl {
    stealth_address: StealthAddress,
    spend_secret: SecretKey,
}

impl StealthChangeCreator for StealthChangeCreatorImpl {
    fn create_change_output(&self, amount: u64) -> Result<(kaspa_consensus_core::tx::TransactionOutput, PendingStealthChange)> {
        use kaspa_stealth::create_stealth_output_with_blinding;
        use kaspa_txscript::pay_to_stealth;
        use rand::rngs::OsRng;

        // Create ephemeral output with blinding factor
        let (ephemeral_output, blinding_factor) =
            create_stealth_output_with_blinding(&self.stealth_address, &mut OsRng).map_err(|e| Error::Custom(e.to_string()))?;

        // Pre-compute spending key immediately (critical for change recovery)
        let spending_secret = derive_spending_key(&self.spend_secret, &blinding_factor).map_err(|e| Error::Custom(e.to_string()))?;

        // Create script
        let script = pay_to_stealth(&ephemeral_output);
        let output = kaspa_consensus_core::tx::TransactionOutput::new(amount, script);

        Ok((
            output,
            PendingStealthChange {
                output_index: 0, // Will be set by Generator
                ephemeral_output,
                blinding_factor,
                spending_secret,
                destination_pubkey: ephemeral_output.destination_pubkey,
            },
        ))
    }
}

// ============================================================================
// Orphan-aware helpers (inherent methods)
// ============================================================================

impl StealthAccount {
    /// Отправка с опцией разрешить использование orphan-UTXO.
    pub async fn send_allowing_orphans(
        self: Arc<Self>,
        destination: PaymentDestination,
        fee_rate: Option<f64>,
        priority_fee_sompi: Fees,
        random_fee_settings: Option<RandomFeeSettings>,
        payload: Option<Vec<u8>>,
        wallet_secret: Secret,
        payment_secret: Option<Secret>,
        abortable: &Abortable,
        notifier: Option<GenerationNotifier>,
        allow_orphans: bool,
    ) -> Result<(GeneratorSummary, Vec<kaspa_hashes::Hash>)> {
        use crate::tx::generator::{Generator, GeneratorSettings, Signer};
        use futures::TryStreamExt;
        use workflow_core::task::yield_executor;

        if !self.is_unlocked().await {
            return Err(Error::AccountLocked);
        }

        let keydata = self.prv_key_data(wallet_secret.clone()).await?;
        let signer = Arc::new(Signer::new(self.clone().as_dyn_arc(), keydata, payment_secret));
        let stealth_signer = StealthSigner::new(self.ephemeral_keys.clone());

        let settings = GeneratorSettings::try_new_with_account(
            self.clone().as_dyn_arc(),
            destination,
            fee_rate,
            priority_fee_sompi,
            payload,
            random_fee_settings,
        )?;
        let settings = self.apply_orphan_filter_with_override(settings, allow_orphans);
        let settings = self.clone().ensure_stealth_change_support(settings).await?;

        let generator = Generator::try_new(settings, Some(signer), Some(abortable))?;

        let mut stream = generator.stream();
        let mut ids = vec![];
        while let Some(transaction) = stream.try_next().await? {
            transaction.try_sign()?;
            if transaction.has_stealth_inputs() {
                transaction.try_sign_stealth(&stealth_signer).await?;
            }
            let tx_id = transaction.try_submit(&self.wallet().rpc_api()).await?;
            if let Some(pending_change) = transaction.take_stealth_change() {
                self.finalize_stealth_change(tx_id, &pending_change, &wallet_secret).await?;
            }
            ids.push(tx_id);
            if let Some(notifier) = notifier.as_ref() {
                notifier(&transaction);
            }
            yield_executor().await;
        }

        Ok((generator.summary(), ids))
    }

    /// Sweep с возможностью включать orphan-UTXO.
    pub async fn sweep_allowing_orphans(
        self: Arc<Self>,
        wallet_secret: Secret,
        payment_secret: Option<Secret>,
        fee_rate: Option<f64>,
        abortable: &Abortable,
        notifier: Option<GenerationNotifier>,
        allow_orphans: bool,
    ) -> Result<(GeneratorSummary, Vec<kaspa_hashes::Hash>)> {
        use crate::tx::generator::{Generator, GeneratorSettings, Signer};
        use futures::TryStreamExt;
        use workflow_core::task::yield_executor;

        let keydata = self.prv_key_data(wallet_secret).await?;
        let signer = Arc::new(Signer::new(self.clone().as_dyn_arc(), keydata, payment_secret));
        let settings = GeneratorSettings::try_new_with_account(
            self.clone().as_dyn_arc(),
            PaymentDestination::Change,
            fee_rate,
            Fees::None,
            None,
            None,
        )?;
        let settings = self.apply_orphan_filter_with_override(settings, allow_orphans);
        let settings = self.clone().ensure_stealth_change_support(settings).await?;
        let generator = Generator::try_new(settings, Some(signer), Some(abortable))?;

        let mut stream = generator.stream();
        let mut ids = vec![];
        while let Some(transaction) = stream.try_next().await? {
            transaction.try_sign()?;
            ids.push(transaction.try_submit(&self.wallet().rpc_api()).await?);

            if let Some(notifier) = notifier.as_ref() {
                notifier(&transaction);
            }
            yield_executor().await;
        }

        Ok((generator.summary(), ids))
    }
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::account::delegation::DelegationId;
    use crate::deterministic::AccountId;
    use crate::storage::ephemeral_keys::{EphemeralKeyData, EphemeralKeyStore};
    use kaspa_consensus_core::network::{NetworkId, NetworkType};
    use kaspa_consensus_core::subnets;
    use kaspa_hashes::Hash;
    use kaspa_mldsa::MlDsaLevel;
    use kaspa_rpc_core::{RpcBlock, RpcHeader, RpcTransaction, RpcTransactionInput, RpcTransactionOutput, RpcTransactionVerboseData};
    use kaspa_stealth::create_stealth_output;
    use kaspa_txscript::pay_to_stealth;
    use kaspa_wallet_keys::secret::Secret;
    use rand::{rngs::StdRng, SeedableRng};
    #[cfg(not(target_arch = "wasm32"))]
    use tempfile::tempdir;

    fn make_record(valid_from: u64, valid_until: Option<u64>) -> DelegationRecordV1 {
        DelegationRecordV1 {
            version: 1,
            level: MlDsaLevel::Level2 as u8,
            anchor: [0u8; 32],
            account_id: AccountId(Hash::from_u64_word(1)),
            spend_pubkey: [0u8; 32],
            scan_pubkey: [0u8; 32],
            valid_from_daa: valid_from,
            valid_until_daa: valid_until,
            nonce: 0,
            status: DelegationStatus::Active,
            signature: Vec::new(),
        }
    }

    #[test]
    fn select_delegation_prefers_latest_nonce_and_handles_expiry() {
        let rec1 = DelegationRecordV1 { nonce: 1, valid_from_daa: 10, valid_until_daa: Some(20), ..make_record(10, Some(20)) };
        let rec2 = DelegationRecordV1 { nonce: 2, valid_from_daa: 10, valid_until_daa: Some(20), ..make_record(10, Some(20)) };

        let (id, rec, reason) =
            select_delegation_from_records(15, vec![(DelegationId(1), rec1.clone()), (DelegationId(2), rec2.clone())]);
        assert_eq!(id, Some(DelegationId(2)));
        assert_eq!(rec.unwrap().nonce, 2);
        assert!(reason.is_none());

        let (id2, rec2_sel, reason2) = select_delegation_from_records(30, vec![(DelegationId(1), rec1)]);
        assert!(id2.is_none());
        assert!(rec2_sel.is_none());
        assert!(matches!(reason2, Some(OrphanReason::DelegationExpired)));
    }

    #[test]
    fn select_delegation_anchor_mismatch_when_no_records() {
        let (id, rec, reason) = select_delegation_from_records(15, vec![]);
        assert!(id.is_none());
        assert!(rec.is_none());
        assert!(matches!(reason, Some(OrphanReason::NoDelegation)));
    }

    #[test]
    fn delegation_window_allows_when_no_daa() {
        let record = make_record(10, Some(20));
        assert!(delegation_window_ok(&record, 0));
    }

    #[test]
    fn delegation_window_blocks_before_start() {
        let record = make_record(10, Some(20));
        assert!(!delegation_window_ok(&record, 5));
    }

    #[test]
    fn delegation_window_blocks_after_end() {
        let record = make_record(10, Some(20));
        assert!(!delegation_window_ok(&record, 25));
    }

    #[test]
    fn delegation_window_allows_within_bounds() {
        let record = make_record(10, Some(20));
        assert!(delegation_window_ok(&record, 15));
    }

    #[test]
    fn delegation_window_open_ended() {
        let record = make_record(10, None);
        assert!(delegation_window_ok(&record, 50));
    }

    fn sample_header(hash_byte: u8, daa_score: u64) -> RpcHeader {
        RpcHeader {
            hash: Hash::from_bytes([hash_byte; 32]),
            version: 0,
            parents_by_level: vec![],
            hash_merkle_root: Hash::default(),
            accepted_id_merkle_root: Hash::default(),
            utxo_commitment: Hash::default(),
            timestamp: 0,
            bits: 0,
            nonce: 0,
            daa_score,
            blue_work: Default::default(),
            blue_score: 0,
            pruning_point: Hash::default(),
        }
    }

    fn make_verbose_tx(
        tx_id: Hash,
        inputs: Vec<RpcTransactionInput>,
        outputs: Vec<RpcTransactionOutput>,
        subnetwork_id: subnets::SubnetworkId,
    ) -> RpcTransaction {
        RpcTransaction {
            version: 0,
            inputs,
            outputs,
            lock_time: 0,
            subnetwork_id,
            gas: 0,
            payload: vec![],
            mass: 0,
            verbose_data: Some(RpcTransactionVerboseData {
                transaction_id: tx_id,
                hash: tx_id,
                compute_mass: 0,
                block_hash: Hash::default(),
                block_time: 0,
            }),
        }
    }

    fn sample_stealth_output(amount: u64) -> (RpcTransactionOutput, RpcTransactionOutpoint) {
        let mut rng = StdRng::seed_from_u64(42);
        let scan_secret = SecretKey::new(&mut rng);
        let spend_secret = SecretKey::new(&mut rng);
        let scan_pubkey = PublicKey::from_secret_key(SECP256K1, &scan_secret).x_only_public_key().0;
        let spend_pubkey = PublicKey::from_secret_key(SECP256K1, &spend_secret).x_only_public_key().0;
        let stealth_address = StealthAddress { scan_pubkey, spend_pubkey };
        let ephemeral_output = create_stealth_output(&stealth_address, &mut rng).expect("ephemeral output");
        let script_public_key = pay_to_stealth(&ephemeral_output);
        let tx_id = Hash::from_bytes([1u8; 32]);
        let outpoint = RpcTransactionOutpoint { transaction_id: tx_id, index: 0 };
        (RpcTransactionOutput { value: amount, script_public_key, verbose_data: None }, outpoint)
    }

    fn build_block(with_spend: bool) -> (RpcBlock, RpcTransactionOutpoint) {
        let tx_id = Hash::from_bytes([1u8; 32]);
        let (output, expected_outpoint) = sample_stealth_output(1000);
        let coinbase_tx = make_verbose_tx(tx_id, vec![], vec![output.clone()], subnets::SUBNETWORK_ID_COINBASE);

        let mut transactions = vec![coinbase_tx];
        if with_spend {
            let spend_id = Hash::from_bytes([2u8; 32]);
            let spend_input = RpcTransactionInput {
                previous_outpoint: expected_outpoint,
                signature_script: vec![],
                sequence: 0,
                sig_op_count: 0,
                verbose_data: None,
            };
            transactions.push(make_verbose_tx(spend_id, vec![spend_input], vec![], subnets::SUBNETWORK_ID_NATIVE));
        }

        let block = RpcBlock { header: sample_header(9, 5), transactions, verbose_data: None };

        (block, expected_outpoint)
    }

    fn test_account_id(suffix: &str) -> AccountId {
        let hex = format!("cafe0000000000000000000000000000000000000000000000000000{}", suffix);
        AccountId::from_hex(&hex).unwrap()
    }

    #[test]
    fn test_stealth_key_derivation() {
        use kaspa_bip32::{Language, Mnemonic, WordCount};

        let mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
        let seed = mnemonic.to_seed("");
        let xprv = ExtendedPrivateKey::<SecretKey>::new(seed).unwrap();

        let derivation = StealthKeyDerivation::from_xprv(&xprv, 0).unwrap();

        // Verify keys are valid (32 bytes for x-only)
        assert_eq!(derivation.scan_pubkey.serialize().len(), 32);
        assert_eq!(derivation.spend_pubkey.serialize().len(), 32);

        // Verify deterministic derivation
        let derivation2 = StealthKeyDerivation::from_xprv(&xprv, 0).unwrap();
        assert_eq!(derivation.scan_pubkey, derivation2.scan_pubkey);
        assert_eq!(derivation.spend_pubkey, derivation2.spend_pubkey);

        // Verify different account_index = different keys
        let derivation3 = StealthKeyDerivation::from_xprv(&xprv, 1).unwrap();
        assert_ne!(derivation.scan_pubkey, derivation3.scan_pubkey);
        assert_ne!(derivation.spend_pubkey, derivation3.spend_pubkey);
    }

    #[test]
    fn test_payload_serialization() {
        use rand::rngs::OsRng;

        // Generate test keys
        let scan_secret = SecretKey::new(&mut OsRng);
        let spend_secret = SecretKey::new(&mut OsRng);
        let scan_pubkey_full = PublicKey::from_secret_key(SECP256K1, &scan_secret);
        let spend_pubkey_full = PublicKey::from_secret_key(SECP256K1, &spend_secret);
        let (scan_pubkey, _) = scan_pubkey_full.x_only_public_key();
        let (spend_pubkey, _) = spend_pubkey_full.x_only_public_key();

        let payload = Payload::new(42, scan_pubkey, spend_pubkey, Some(12345), None, None);

        // Serialize
        let bytes = borsh::to_vec(&payload).unwrap();

        // Deserialize
        let restored: Payload = borsh::from_slice(&bytes).unwrap();

        assert_eq!(restored.account_index, 42);
        assert_eq!(restored.creation_daa_score, Some(12345));
        assert_eq!(restored.scan_pubkey().unwrap(), scan_pubkey);
        assert_eq!(restored.spend_pubkey().unwrap(), spend_pubkey);
    }

    #[test]
    fn test_collect_live_stealth_utxos_filters_spent_outputs() {
        let (block, _) = build_block(true);
        let live_entries = StealthAccount::collect_live_stealth_utxos(&block);
        assert!(live_entries.is_empty());
    }

    #[test]
    fn test_collect_live_stealth_utxos_keeps_unspent_outputs() {
        let (block, expected_outpoint) = build_block(false);
        let tx = &block.transactions[0];
        assert_eq!(tx.outputs[0].script_public_key.version(), STEALTH_SCRIPT_VERSION);
        assert_eq!(tx.outputs[0].script_public_key.script().len(), EPHEMERAL_OUTPUT_SIZE);
        assert!(extract_stealth_output(&tx.outputs[0].script_public_key).is_ok());
        assert!(StealthAccount::stealth_entry_from_transaction_output(
            tx.verbose_data.as_ref().map(|v| v.transaction_id).unwrap(),
            0,
            &tx.outputs[0],
            block.header.daa_score,
            true
        )
        .is_some());
        let live_entries = StealthAccount::collect_live_stealth_utxos(&block);
        assert_eq!(live_entries.len(), 1);
        let expected: TransactionOutpoint = expected_outpoint.into();
        assert!(live_entries.iter().any(|(outpoint, _)| *outpoint == expected));
    }

    #[test]
    fn test_fallback_progress_event_contents() {
        let account_id = test_account_id("00000001");
        let processed_blocks = 321;
        let last_daa = 654;
        let claimed = 7;

        let event = StealthAccount::fallback_progress_event(account_id, processed_blocks, last_daa, claimed);
        match event {
            Events::StealthScanProgress { account_id: id, processed_blocks: blocks, last_daa_score: daa, claimed: total } => {
                assert_eq!(id, account_id);
                assert_eq!(blocks, processed_blocks);
                assert_eq!(daa, last_daa);
                assert_eq!(total, claimed);
            }
            other => panic!("Unexpected event variant: {:?}", other),
        }
    }

    #[test]
    fn test_should_emit_fallback_progress_by_interval() {
        assert!(!StealthAccount::should_emit_fallback_progress(FALLBACK_PROGRESS_REPORT_INTERVAL - 1, 0));
        assert!(StealthAccount::should_emit_fallback_progress(FALLBACK_PROGRESS_REPORT_INTERVAL, 0));
    }

    #[test]
    fn test_should_emit_fallback_progress_by_timer() {
        assert!(!StealthAccount::should_emit_fallback_progress(1, FALLBACK_PROGRESS_REPORT_INTERVAL_SECS - 1));
        assert!(StealthAccount::should_emit_fallback_progress(1, FALLBACK_PROGRESS_REPORT_INTERVAL_SECS));
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[tokio::test]
    async fn test_pending_ephemeral_keys_flush_after_unlock() {
        let account_id = test_account_id("00000005");
        let store = EphemeralKeyStore::new(account_id);
        let mut pending = PendingEphemeralPersist::new();

        let tx_id = Hash::from_bytes([9u8; 32]);
        let outpoint = TransactionOutpoint::new(tx_id, 0);
        let key_data = EphemeralKeyData::new_xonly([1u8; 32], [2u8; 32], [3u8; 32]);
        store.store(outpoint, key_data, 123, None, None).await.unwrap();

        pending.mark_dirty(outpoint);

        let temp_dir = tempdir().unwrap();
        let wallet_folder = temp_dir.path().to_string_lossy().to_string();
        let network_id = NetworkId::with_suffix(NetworkType::Testnet, 17);

        let err = pending.try_flush(None, Some(wallet_folder.as_str()), Some(network_id), &store).await.unwrap_err();
        assert!(matches!(err, Error::Custom(_)));
        assert!(pending.is_dirty());
        assert_eq!(pending.len(), 1);

        let wallet_secret = Secret::from("stealth-persist-test");
        pending.try_flush(Some(&wallet_secret), Some(wallet_folder.as_str()), Some(network_id), &store).await.unwrap();

        assert!(!pending.is_dirty());
        assert_eq!(pending.len(), 0);
        assert!(EphemeralKeyStore::storage_exists(&wallet_folder, &account_id, network_id).await.unwrap());
    }
}
