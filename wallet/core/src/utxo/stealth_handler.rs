//!
//! Stealth UTXO Handler trait for processing stealth transactions.
//!
//! # Example Usage
//!
//! ```ignore
//! use kaspa_wallet_core::tx::generator::{StealthSigner, DynEphemeralKeyProvider};
//!
//! // When sending a transaction with stealth inputs:
//! async fn send_with_stealth(
//!     pending_tx: &PendingTransaction,
//!     ephemeral_keys: Arc<EphemeralKeyStore>,
//! ) -> Result<()> {
//!     // Create a StealthSigner with the ephemeral key provider
//!     let stealth_signer = StealthSigner::new(ephemeral_keys as DynEphemeralKeyProvider);
//!
//!     // Sign both regular and stealth inputs
//!     pending_tx.try_sign_with_stealth(Some(&stealth_signer)).await?;
//!
//!     Ok(())
//! }
//! ```
//!

use crate::deterministic::AccountId;
use crate::result::Result;
use crate::storage::ephemeral_keys::EphemeralKeyStore;
use crate::utxo::UtxoContext;
use async_trait::async_trait;
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_rpc_core::RpcUtxosByAddressesEntry;
use std::sync::Arc;

/// Handler trait for stealth UTXOs.
///
/// Implemented by StealthAccount to receive notifications about
/// stealth UTXOs that may belong to it.
#[async_trait]
pub trait StealthUtxoHandler: Send + Sync {
    /// Attempts to claim a UTXO for this handler.
    ///
    /// Returns `Some(UtxoContext)` if the UTXO belongs to this account,
    /// `None` otherwise.
    ///
    /// This method should:
    /// 1. Check if script version is STEALTH_SCRIPT_VERSION
    /// 2. Parse the EphemeralOutput from the script
    /// 3. Check View Tag (fast filter)
    /// 4. If View Tag matches, perform full ECDH check
    /// 5. If UTXO belongs to us, derive and store the spending key
    async fn try_claim_utxo(&self, utxo: &RpcUtxosByAddressesEntry) -> Option<UtxoContext>;

    /// Returns the UtxoContext for this handler
    fn utxo_context(&self) -> &UtxoContext;

    /// Returns the account ID for this handler
    fn account_id(&self) -> &AccountId;

    /// Checks if this handler owns the given outpoint
    fn has_outpoint(&self, outpoint: &TransactionOutpoint) -> bool;

    /// Called when a UTXO owned by this handler is removed (spent or reorg)
    async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()>;

    /// Returns the ephemeral key store for this handler.
    /// Used for signing stealth inputs.
    fn ephemeral_key_store(&self) -> Option<Arc<EphemeralKeyStore>>;
}

/// Type alias for dynamic stealth handler
pub type DynStealthUtxoHandler = std::sync::Arc<dyn StealthUtxoHandler + 'static>;
