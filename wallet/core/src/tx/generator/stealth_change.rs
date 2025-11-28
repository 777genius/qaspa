//! Stealth Change Output Creation
//!
//! This module provides the infrastructure for creating stealth change outputs
//! with pre-calculated spending keys. This is critical for stealth addresses
//! because:
//!
//! 1. Each stealth output has a unique ephemeral key (R)
//! 2. The spending key depends on this ephemeral key
//! 3. If we don't save the spending key immediately, we'd need to re-scan
//!    the entire blockchain to find our own change output
//!
//! # Architecture
//!
//! The [`StealthChangeCreator`] trait allows the Generator to delegate
//! stealth output creation to the account, which has access to the spend secret.
//!
//! ```text
//! Account (has spend_secret)
//!    |
//!    v
//! StealthChangeCreator.create_change_output()
//!    |
//!    +---> TransactionOutput (for the transaction)
//!    +---> PendingStealthChange (with pre-calculated spending key)
//! ```
//!
//! After the transaction is submitted, the account finalizes the change by
//! storing the ephemeral key with the real outpoint (txid:index).

use crate::result::Result;
use kaspa_consensus_core::tx::TransactionOutput;
use kaspa_stealth::EphemeralOutput;
use secp256k1::{Scalar, SecretKey, XOnlyPublicKey};
use std::sync::Arc;

/// Pre-calculated ephemeral key data for a stealth change output.
///
/// This struct holds all the cryptographic data needed to spend a stealth
/// output that we created for ourselves (change). The data is computed
/// at transaction creation time so we don't need to re-scan the blockchain.
///
/// # Lifecycle
///
/// 1. Created by [`StealthChangeCreator::create_change_output`]
/// 2. Stored temporarily in [`PendingTransaction`]
/// 3. After submit: finalized with real `outpoint` and stored in account
///
/// # Security
///
/// The `spending_secret` should be zeroized after being stored in the
/// account's ephemeral key cache. Use `zeroize` crate's traits.
pub struct PendingStealthChange {
    /// Index of the change output in the transaction.
    /// Set by the Generator after the output is added to the transaction.
    pub output_index: usize,

    /// The ephemeral output data stored in ScriptPublicKey.
    /// Contains: R (ephemeral pubkey), view_tag, P_dest (destination pubkey)
    pub ephemeral_output: EphemeralOutput,

    /// The blinding factor `t` used to derive the destination.
    /// Formula: P_dest = PubSpend + t*G
    /// Also used to derive: PrivDest = PrivSpend + t
    pub blinding_factor: Scalar,

    /// The pre-computed spending secret key.
    /// Formula: PrivDest = PrivSpend + t (mod n)
    /// This is the key needed to sign transactions spending this output.
    pub spending_secret: SecretKey,

    /// The destination public key (x-only, 32 bytes).
    /// This is redundant with ephemeral_output.destination_pubkey but
    /// stored separately for convenience during signing.
    pub destination_pubkey: XOnlyPublicKey,
}

impl PendingStealthChange {
    /// Creates a new PendingStealthChange.
    ///
    /// # Arguments
    ///
    /// * `ephemeral_output` - The output data for the ScriptPublicKey
    /// * `blinding_factor` - The scalar `t` for key derivation
    /// * `spending_secret` - The pre-computed spending key
    pub fn new(ephemeral_output: EphemeralOutput, blinding_factor: Scalar, spending_secret: SecretKey) -> Self {
        let destination_pubkey = ephemeral_output.destination_pubkey;
        Self {
            output_index: 0, // Will be set by Generator
            ephemeral_output,
            blinding_factor,
            spending_secret,
            destination_pubkey,
        }
    }
}

impl std::fmt::Debug for PendingStealthChange {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PendingStealthChange")
            .field("output_index", &self.output_index)
            .field("ephemeral_output", &self.ephemeral_output)
            .field("destination_pubkey", &self.destination_pubkey)
            // Don't expose blinding_factor or spending_secret in debug output
            .field("blinding_factor", &"[REDACTED]")
            .field("spending_secret", &"[REDACTED]")
            .finish()
    }
}

impl Clone for PendingStealthChange {
    fn clone(&self) -> Self {
        Self {
            output_index: self.output_index,
            ephemeral_output: self.ephemeral_output,
            blinding_factor: self.blinding_factor,
            spending_secret: self.spending_secret,
            destination_pubkey: self.destination_pubkey,
        }
    }
}

impl Drop for PendingStealthChange {
    fn drop(&mut self) {
        self.blinding_factor.non_secure_erase();
        self.spending_secret.non_secure_erase();
    }
}

/// Trait for creating stealth change outputs with pre-calculated keys.
///
/// This trait is implemented by [`StealthAccount`] (or a helper struct)
/// and passed to the Generator via [`GeneratorSettings`].
///
/// # Why a Trait?
///
/// The Generator doesn't have access to the spend secret (only the Signer does).
/// But for stealth change outputs, we need the spend secret to pre-calculate
/// the spending key BEFORE the transaction is broadcast.
///
/// This trait allows the account to provide a callback that:
/// 1. Generates the ephemeral key
/// 2. Creates the ScriptPublicKey
/// 3. Pre-computes the spending key
///
/// All without exposing the spend secret to the Generator.
///
/// # Thread Safety
///
/// Implementations must be `Send + Sync` because the Generator may be used
/// across threads (e.g., in async contexts).
///
/// # Example Implementation
///
/// ```ignore
/// struct MyStealthChangeCreator {
///     stealth_address: StealthAddress,
///     spend_secret: SecretKey,
/// }
///
/// impl StealthChangeCreator for MyStealthChangeCreator {
///     fn create_change_output(&self, amount: u64) -> Result<(TransactionOutput, PendingStealthChange)> {
///         let (ephemeral_output, blinding_factor) =
///             create_stealth_output_with_blinding(&self.stealth_address, &mut OsRng)?;
///         
///         let spending_secret = derive_spending_key(&self.spend_secret, &blinding_factor)?;
///         let script = pay_to_stealth(&ephemeral_output);
///         let output = TransactionOutput::new(amount, script);
///         
///         let pending = PendingStealthChange::new(ephemeral_output, blinding_factor, spending_secret);
///         Ok((output, pending))
///     }
/// }
/// ```
pub trait StealthChangeCreator: Send + Sync {
    /// Creates a stealth output for change with a pre-calculated spending key.
    ///
    /// This method is called by the Generator when it needs to create a
    /// change output for a stealth address.
    ///
    /// # Arguments
    ///
    /// * `amount` - The change amount in sompi
    ///
    /// # Returns
    ///
    /// A tuple of:
    /// - `TransactionOutput` - The output to include in the transaction
    /// - `PendingStealthChange` - The pre-calculated key data for later storage
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Random number generation fails
    /// - Key derivation fails (unlikely with valid keys)
    fn create_change_output(&self, amount: u64) -> Result<(TransactionOutput, PendingStealthChange)>;
}

/// Type alias for a boxed stealth change creator.
pub type DynStealthChangeCreator = Arc<dyn StealthChangeCreator>;

// ============================================================================
// Concrete Implementation
// ============================================================================

/// Concrete implementation of [`StealthChangeCreator`] for creating stealth
/// change outputs.
///
/// This implementation holds the stealth address and spend secret, and uses
/// them to create properly formed stealth outputs with pre-calculated spending
/// keys.
///
/// # Usage
///
/// ```ignore
/// let creator = StealthChangeCreatorImpl::new(
///     stealth_address,
///     spend_secret,
/// );
/// let arc_creator: DynStealthChangeCreator = Arc::new(creator);
/// let settings = GeneratorSettings::try_new_with_account(...)
///     .with_stealth_change_creator(arc_creator);
/// ```
pub struct StealthChangeCreatorImpl {
    /// The stealth address to send change to (our own address)
    stealth_address: kaspa_stealth::StealthAddress,
    /// Our spend secret for pre-calculating the spending key
    spend_secret: SecretKey,
}

impl StealthChangeCreatorImpl {
    /// Creates a new stealth change creator.
    ///
    /// # Arguments
    ///
    /// * `stealth_address` - The stealth address for change outputs
    /// * `spend_secret` - The spend secret key for deriving spending keys
    pub fn new(stealth_address: kaspa_stealth::StealthAddress, spend_secret: SecretKey) -> Self {
        Self { stealth_address, spend_secret }
    }
}

impl StealthChangeCreator for StealthChangeCreatorImpl {
    fn create_change_output(&self, amount: u64) -> Result<(TransactionOutput, PendingStealthChange)> {
        use kaspa_stealth::{create_stealth_output_with_blinding, derive_spending_key};
        use kaspa_txscript::pay_to_stealth;
        use rand::rngs::OsRng;

        // 1. Generate ephemeral output with blinding factor
        let (ephemeral_output, blinding_factor) = create_stealth_output_with_blinding(&self.stealth_address, &mut OsRng)
            .map_err(|e| crate::error::Error::Custom(format!("Stealth output creation failed: {}", e)))?;

        // 2. Pre-calculate spending key (we know the spend_secret!)
        let spending_secret = derive_spending_key(&self.spend_secret, &blinding_factor)
            .map_err(|e| crate::error::Error::Custom(format!("Spending key derivation failed: {}", e)))?;

        // 3. Create ScriptPublicKey for the transaction
        let script_public_key = pay_to_stealth(&ephemeral_output);
        let output = TransactionOutput::new(amount, script_public_key);

        // 4. Create pending change data for later storage
        let pending = PendingStealthChange::new(ephemeral_output, blinding_factor, spending_secret);

        Ok((output, pending))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pending_stealth_change_debug_redacts_secrets() {
        use kaspa_stealth::{create_stealth_output_with_blinding, derive_spending_key, StealthSecretKey};
        use rand::rngs::OsRng;

        let keys = StealthSecretKey::generate();
        let address = keys.to_address();

        let (ephemeral_output, blinding_factor) = create_stealth_output_with_blinding(&address, &mut OsRng).unwrap();
        let spending_secret = derive_spending_key(&keys.spend_secret(), &blinding_factor).unwrap();

        let pending = PendingStealthChange::new(ephemeral_output, blinding_factor, spending_secret);

        let debug_output = format!("{:?}", pending);

        // Verify secrets are redacted
        assert!(debug_output.contains("[REDACTED]"), "Debug output should redact secrets");
        assert!(!debug_output.contains(&format!("{:?}", pending.spending_secret.secret_bytes())));
    }

    #[test]
    fn test_stealth_change_creator_impl() {
        use kaspa_stealth::{verify_derived_key, StealthSecretKey, STEALTH_SCRIPT_VERSION};

        let keys = StealthSecretKey::generate();
        let address = keys.to_address();

        let creator = StealthChangeCreatorImpl::new(address, keys.spend_secret());

        // Create a change output
        let amount = 100_000_000; // 1 KAS
        let (output, pending) = creator.create_change_output(amount).unwrap();

        // Verify output amount
        assert_eq!(output.value, amount);

        // Verify output script version
        assert_eq!(output.script_public_key.version(), STEALTH_SCRIPT_VERSION, "Output should have stealth script version");

        // Verify output script length (66 bytes)
        assert_eq!(output.script_public_key.script().len(), 66, "Stealth output should be 66 bytes");

        // Verify the pre-calculated spending key is correct
        assert!(
            verify_derived_key(&pending.spending_secret, &pending.destination_pubkey),
            "Pre-calculated spending key should match destination"
        );

        // Verify output_index is initially 0 (set by Generator later)
        assert_eq!(pending.output_index, 0);
    }

    #[test]
    fn test_stealth_change_creator_unique_outputs() {
        use kaspa_stealth::StealthSecretKey;

        let keys = StealthSecretKey::generate();
        let address = keys.to_address();

        let creator = StealthChangeCreatorImpl::new(address, keys.spend_secret());

        // Create multiple change outputs
        let (output1, pending1) = creator.create_change_output(100).unwrap();
        let (output2, pending2) = creator.create_change_output(100).unwrap();
        let (_output3, pending3) = creator.create_change_output(100).unwrap();

        // Each output should have a unique ephemeral key (R)
        assert_ne!(
            pending1.ephemeral_output.ephemeral_pubkey, pending2.ephemeral_output.ephemeral_pubkey,
            "Each output should have unique ephemeral pubkey"
        );
        assert_ne!(
            pending2.ephemeral_output.ephemeral_pubkey, pending3.ephemeral_output.ephemeral_pubkey,
            "Each output should have unique ephemeral pubkey"
        );

        // Each output should have a unique destination pubkey
        assert_ne!(pending1.destination_pubkey, pending2.destination_pubkey, "Each output should have unique destination");
        assert_ne!(pending2.destination_pubkey, pending3.destination_pubkey, "Each output should have unique destination");

        // Script public keys should be different
        assert_ne!(output1.script_public_key.script(), output2.script_public_key.script(), "Each output should have unique script");
    }

    #[test]
    fn test_stealth_change_creator_spending_keys_are_unique() {
        use kaspa_stealth::StealthSecretKey;

        let keys = StealthSecretKey::generate();
        let address = keys.to_address();

        let creator = StealthChangeCreatorImpl::new(address, keys.spend_secret());

        // Create multiple change outputs
        let (_, pending1) = creator.create_change_output(100).unwrap();
        let (_, pending2) = creator.create_change_output(100).unwrap();

        // Each should have a unique spending secret
        assert_ne!(
            pending1.spending_secret.secret_bytes(),
            pending2.spending_secret.secret_bytes(),
            "Each output should have unique spending key"
        );

        // Each should have a unique blinding factor
        assert_ne!(pending1.blinding_factor, pending2.blinding_factor, "Each output should have unique blinding factor");
    }
}
