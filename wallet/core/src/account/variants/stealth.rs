//!
//! Stealth Address Account Implementation
//!
//! Provides privacy-preserving transactions using ECDH-based stealth addresses.
//! Each payment creates a unique one-time destination that only the recipient
//! can identify and spend.
//!

use crate::account::{Account, AccountKind, GenerationNotifier, Inner};
use crate::deterministic::make_account_hashes;
use crate::imports::*;
use crate::serializer::StorageHeader;
use crate::storage::account::{AccountSettings, AccountStorable, AccountStorage};
use crate::storage::ephemeral_keys::{EphemeralKeyData, EphemeralKeyStore};
use crate::storage::interface::StorageDescriptor;
use crate::storage::{AccountMetadata, PrvKeyDataId, Storable};
use crate::tx::generator::stealth_change::{DynStealthChangeCreator, PendingStealthChange, StealthChangeCreator};
use crate::tx::generator::stealth_signer::StealthSigner;
use crate::tx::{Fees, GeneratorSummary, PaymentDestination};
use crate::utxo::stealth_handler::StealthUtxoHandler;
use crate::utxo::UtxoContext;
use kaspa_addresses::{Address, Version};
use kaspa_bip32::ExtendedPrivateKey;
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_rpc_core::RpcUtxosByAddressesEntry;
use kaspa_stealth::{check_view_tag, derive_spending_key, scan_output, StealthAddress};
use kaspa_txscript::{extract_stealth_output, STEALTH_SCRIPT_VERSION};
use secp256k1::{PublicKey, SecretKey, XOnlyPublicKey, SECP256K1};
use std::io::{Error as IoError, ErrorKind as IoErrorKind, Result as IoResult};

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
}

impl Payload {
    pub fn new(
        account_index: u64,
        scan_pubkey: XOnlyPublicKey,
        spend_pubkey: XOnlyPublicKey,
        creation_daa_score: Option<u64>,
    ) -> Self {
        Self {
            account_index,
            scan_pubkey: scan_pubkey.serialize().to_vec(),
            spend_pubkey: spend_pubkey.serialize().to_vec(),
            creation_daa_score,
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
    const STORAGE_VERSION: u32 = 0;
}

impl AccountStorable for Payload {}

impl BorshSerialize for Payload {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        StorageHeader::new(Self::STORAGE_MAGIC, Self::STORAGE_VERSION).serialize(writer)?;
        BorshSerialize::serialize(&self.account_index, writer)?;
        BorshSerialize::serialize(&self.scan_pubkey, writer)?;
        BorshSerialize::serialize(&self.spend_pubkey, writer)?;
        BorshSerialize::serialize(&self.creation_daa_score, writer)?;
        Ok(())
    }
}

impl BorshDeserialize for Payload {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> IoResult<Self> {
        let StorageHeader { version: _, .. } =
            StorageHeader::deserialize_reader(reader)?.try_magic(Self::STORAGE_MAGIC)?.try_version(Self::STORAGE_VERSION)?;

        let account_index = BorshDeserialize::deserialize_reader(reader)?;
        let scan_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
        let spend_pubkey: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
        let creation_daa_score = BorshDeserialize::deserialize_reader(reader)?;

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

        Ok(Self { account_index, scan_pubkey, spend_pubkey, creation_daa_score })
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

    /// Ephemeral key store for spending received UTXOs
    ephemeral_keys: Arc<EphemeralKeyStore>,

    /// DAA score when account was created
    creation_daa_score: Option<u64>,
}

impl StealthAccount {
    // ========================================================================
    // CONSTRUCTION
    // ========================================================================

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

        let storable = Payload::new(account_index, scan_pubkey, spend_pubkey, creation_daa_score);

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
            ephemeral_keys,
            creation_daa_score,
        })
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

        Ok(Self {
            inner,
            prv_key_data_id,
            account_index: payload.account_index,
            scan_pubkey,
            spend_pubkey,
            stealth_address,
            unlocked_keys: Arc::new(AsyncRwLock::new(None)),
            ephemeral_keys,
            creation_daa_score: payload.creation_daa_score,
        })
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

        // Load ephemeral keys from storage
        if let Ok(StorageDescriptor::Internal(wallet_folder)) = self.wallet().store().location() {
            if let Ok(network_id) = self.wallet().network_id() {
                let _ = self.ephemeral_keys.load_from_storage(&wallet_folder, network_id, wallet_secret).await;
            }
        }

        Ok(())
    }

    /// Locks the account by clearing cached keys from memory.
    pub async fn lock(&self) {
        let mut keys = self.unlocked_keys.write().await;
        // Keys will be zeroized on drop via UnlockedStealthKeys::drop()
        *keys = None;
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
        wallet_secret: &Secret,
    ) -> Result<()> {
        let outpoint = TransactionOutpoint::new(tx_id, pending.output_index as u32);

        // Use new_xonly for 32-byte x-only pubkey
        let key_data = EphemeralKeyData::new_xonly(
            pending.spending_secret.secret_bytes(),
            pending.blinding_factor.to_be_bytes(),
            pending.destination_pubkey.serialize(),
        );

        let daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);

        self.ephemeral_keys.store(outpoint, key_data, daa_score).await?;

        // Register in UtxoProcessor's outpoint index
        self.wallet().utxo_processor().register_stealth_outpoint(outpoint, *self.id());

        // Save to storage
        if let Ok(StorageDescriptor::Internal(wallet_folder)) = self.wallet().store().location() {
            if let Ok(network_id) = self.wallet().network_id() {
                let _ = self.ephemeral_keys.save_to_storage(&wallet_folder, network_id, wallet_secret).await;
            }
        }

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
        let storable = Payload::new(self.account_index, self.scan_pubkey, self.spend_pubkey, self.creation_daa_score);

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
        let descriptor = AccountDescriptor::new(
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

        // Create stealth change creator for stealth change outputs
        let stealth_change_creator = self.create_change_creator().await?;

        // Create stealth signer for stealth inputs
        let stealth_signer = StealthSigner::new(self.ephemeral_keys.clone());

        // Configure generator with stealth change creator
        let mut settings =
            GeneratorSettings::try_new_with_account(self.clone().as_dyn_arc(), destination, fee_rate, priority_fee_sompi, payload)?;
        settings.stealth_change_creator = Some(stealth_change_creator);

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
        let current_daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);

        // Check if server supports stealth features
        let server_info = rpc.get_server_info().await.map_err(|e| Error::Custom(e.to_string()))?;
        if !server_info.has_stealth_support {
            // Server doesn't support stealth - rely on notifications only
            log_warn!("Server does not support stealth features - scan skipped");
            return Ok(());
        }

        // Scan for stealth UTXOs using the dedicated RPC method
        let mut cursor = None;
        let limit = Some(1000u32);
        let mut total_claimed = 0usize;
        let mut updated_contexts = std::collections::HashSet::new();

        loop {
            let response = match rpc.get_utxos_by_script_version(STEALTH_SCRIPT_VERSION, cursor, limit).await {
                Ok(r) => r,
                Err(e) => {
                    // gRPC doesn't support this method - fall back to notifications only
                    let err_str = e.to_string();
                    if err_str.contains("not yet supported over gRPC") || err_str.contains("not supported") {
                        log_warn!("Stealth scan not supported over current RPC transport - relying on notifications only");
                        return Ok(());
                    }
                    return Err(Error::Custom(format!("RPC error during stealth scan: {}", e)));
                }
            };

            if response.entries.is_empty() {
                break;
            }

            // Try to claim each UTXO
            for entry in response.entries.iter() {
                // Convert RpcUtxosByScriptVersionEntry to RpcUtxosByAddressesEntry for try_claim_utxo
                let utxo_entry = kaspa_rpc_core::RpcUtxosByAddressesEntry {
                    address: None, // Stealth UTXOs have no address
                    outpoint: entry.outpoint,
                    utxo_entry: entry.utxo_entry.clone(),
                };

                if let Some(context) = self.try_claim_utxo(&utxo_entry).await {
                    // UTXO belongs to this account
                    let utxo_ref: crate::utxo::UtxoEntryReference = (&utxo_entry).into();
                    // Use current DAA score for maturity calculation (not block_daa_score!)
                    context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
                    updated_contexts.insert(context);
                    total_claimed += 1;
                }
            }

            // Check if there are more entries to fetch
            cursor = response.next_cursor;
            if cursor.is_none() {
                break;
            }
        }

        // Update balances for all contexts that received UTXOs
        for context in updated_contexts.iter() {
            context.update_balance().await?;
        }

        if total_claimed > 0 {
            log_info!("Stealth scan complete: claimed {} UTXOs", total_claimed);
            // Note: Ephemeral keys will be saved on next send() or finalize_stealth_change()
            // operation where wallet_secret is available. Keys are kept in memory until then.
        }

        Ok(())
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

                let daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);

                // Store ephemeral key
                if let Err(e) = self.ephemeral_keys.store(outpoint, key_data, daa_score).await {
                    log_error!("Failed to store ephemeral key: {}", e);
                    return None;
                }

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
        self.ephemeral_keys.contains(outpoint)
    }

    async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()> {
        self.ephemeral_keys.remove(outpoint).await?;
        Ok(())
    }

    fn ephemeral_key_store(&self) -> Option<Arc<EphemeralKeyStore>> {
        Some(self.ephemeral_keys.clone())
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
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

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

        let payload = Payload::new(42, scan_pubkey, spend_pubkey, Some(12345));

        // Serialize
        let bytes = borsh::to_vec(&payload).unwrap();

        // Deserialize
        let restored: Payload = borsh::from_slice(&bytes).unwrap();

        assert_eq!(restored.account_index, 42);
        assert_eq!(restored.creation_daa_score, Some(12345));
        assert_eq!(restored.scan_pubkey().unwrap(), scan_pubkey);
        assert_eq!(restored.spend_pubkey().unwrap(), spend_pubkey);
    }
}
