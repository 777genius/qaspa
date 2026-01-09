//! Sender-side stealth address operations
//!
//! This module provides functions for creating stealth payments.
//! The sender uses the recipient's stealth address to create a one-time
//! destination that only the recipient can spend.
//!
//! # Protocol
//!
//! 1. Sender generates ephemeral secret `r` (MUST be cryptographically random)
//! 2. Computes `R = r * G` (ephemeral public key, stored in blockchain)
//! 3. Computes shared secret `S = r * PubScan` (ECDH)
//! 4. Computes view tag `tag = Hash(S)[0]` (for fast scanning)
//! 5. Computes blinding factor `t = Hash(S)` (as scalar)
//! 6. Computes destination `P_dest = PubSpend + t*G` (one-time address)
//!
//! # Security
//!
//! The ephemeral secret `r` MUST be generated using a cryptographically secure
//! RNG (OsRng). Using a predictable or low-entropy `r` allows attackers to
//! recover the recipient's spend key!

use crate::ecdh::compute_shared_secret_xonly;
use crate::error::{Result, StealthError};
use crate::hash::{BlindingFactorHash, ViewTagHash};
use crate::keys::{EphemeralOutput, StealthAddress};
use rand_core::CryptoRngCore;
use secp256k1::{Scalar, SecretKey, SECP256K1};
use zeroize::Zeroize;

fn try_generate_secret_key() -> Result<SecretKey> {
    const MAX_ATTEMPTS: usize = 128;

    for _ in 0..MAX_ATTEMPTS {
        let mut bytes = [0u8; 32];
        getrandom::fill(&mut bytes).map_err(|e| StealthError::RandomnessFailed(format!("getrandom failed: {e}")))?;

        let secret = match SecretKey::from_slice(&bytes) {
            Ok(sk) => {
                bytes.zeroize();
                sk
            }
            Err(_) => {
                bytes.zeroize();
                continue;
            }
        };

        return Ok(secret);
    }

    Err(StealthError::RandomnessFailed(format!("failed to generate valid secret key after {MAX_ATTEMPTS} attempts")))
}

/// Creates a stealth output using the system RNG via `getrandom` (fallible).
///
/// This is intended for environments where `rand` RNG adapters may panic on RNG failures (notably some WASM setups).
pub fn try_create_stealth_output(address: &StealthAddress) -> Result<EphemeralOutput> {
    // Step 1: Generate ephemeral secret key r (fallible)
    let ephemeral_secret = try_generate_secret_key()?;

    // Step 2: Compute R = r * G (ephemeral public key)
    let ephemeral_pubkey = ephemeral_secret.public_key(SECP256K1);

    // Step 3: Compute shared secret S = r * PubScan (ECDH)
    let shared_secret = compute_shared_secret_xonly(&ephemeral_secret, &address.scan_pubkey);

    // Step 4: Compute view tag = Hash("StealthViewTag", S)[0]
    let view_tag = ViewTagHash::compute_tag(shared_secret);

    // Step 5: Compute blinding factor t = Hash("StealthBlindingFactor", S)
    let blinding_hash = BlindingFactorHash::hash(shared_secret);

    // Convert hash to scalar (mod n where n is the curve order)
    let blinding_scalar = Scalar::from_be_bytes(blinding_hash.as_bytes())
        .map_err(|_| StealthError::TweakFailed("blinding factor scalar overflow".into()))?;

    // Step 6: Compute P_dest = PubSpend + t*G
    let (destination_pubkey, _parity) =
        address.spend_pubkey.add_tweak(SECP256K1, &blinding_scalar).map_err(|e| StealthError::TweakFailed(e.to_string()))?;

    Ok(EphemeralOutput::new(ephemeral_pubkey, view_tag, destination_pubkey))
}

/// Creates a stealth output for sending funds to a stealth address.
///
/// This function generates all cryptographic data needed to create a
/// transaction output that only the recipient can spend.
///
/// # Arguments
///
/// * `address` - The recipient's stealth address
/// * `rng` - A cryptographically secure random number generator (MUST be OsRng in production!)
///
/// # Returns
///
/// Returns the `EphemeralOutput` to be stored in the transaction's ScriptPublicKey.
///
/// # Security
///
/// - The RNG MUST be cryptographically secure (use `OsRng` or `getrandom`)
/// - Never reuse the same ephemeral secret for multiple outputs
/// - Each output in a transaction should call this function separately
///
/// # Example
///
/// ```ignore
/// use kaspa_stealth::{create_stealth_output, StealthAddress};
/// use rand::rngs::OsRng;
///
/// let address: StealthAddress = /* recipient's address */;
/// let output = create_stealth_output(&address, &mut OsRng)?;
/// // Use output.to_bytes() in ScriptPublicKey
/// ```
pub fn create_stealth_output<R: CryptoRngCore>(address: &StealthAddress, rng: &mut R) -> Result<EphemeralOutput> {
    // Step 1: Generate ephemeral secret key r
    // CRITICAL: This MUST be cryptographically random!
    let ephemeral_secret = SecretKey::new(rng);

    // Step 2: Compute R = r * G (ephemeral public key)
    let ephemeral_pubkey = ephemeral_secret.public_key(SECP256K1);

    // Step 3: Compute shared secret S = r * PubScan (ECDH)
    let shared_secret = compute_shared_secret_xonly(&ephemeral_secret, &address.scan_pubkey);

    // Step 4: Compute view tag = Hash("StealthViewTag", S)[0]
    let view_tag = ViewTagHash::compute_tag(shared_secret);

    // Step 5: Compute blinding factor t = Hash("StealthBlindingFactor", S)
    let blinding_hash = BlindingFactorHash::hash(shared_secret);

    // Convert hash to scalar (mod n where n is the curve order)
    let blinding_scalar = Scalar::from_be_bytes(blinding_hash.as_bytes())
        .map_err(|_| StealthError::TweakFailed("blinding factor scalar overflow".into()))?;

    // Step 6: Compute P_dest = PubSpend + t*G
    // This is done by tweaking the spend public key with the blinding factor
    let (destination_pubkey, _parity) =
        address.spend_pubkey.add_tweak(SECP256K1, &blinding_scalar).map_err(|e| StealthError::TweakFailed(e.to_string()))?;

    Ok(EphemeralOutput::new(ephemeral_pubkey, view_tag, destination_pubkey))
}

/// Creates a stealth output AND returns the blinding factor using system RNG via `getrandom` (fallible).
pub fn try_create_stealth_output_with_blinding(address: &StealthAddress) -> Result<(EphemeralOutput, Scalar)> {
    let ephemeral_secret = try_generate_secret_key()?;
    let ephemeral_pubkey = ephemeral_secret.public_key(SECP256K1);

    let shared_secret = compute_shared_secret_xonly(&ephemeral_secret, &address.scan_pubkey);
    let view_tag = ViewTagHash::compute_tag(shared_secret);

    let blinding_hash = BlindingFactorHash::hash(shared_secret);
    let blinding_factor = Scalar::from_be_bytes(blinding_hash.as_bytes())
        .map_err(|_| StealthError::TweakFailed("blinding factor scalar overflow".into()))?;

    let (destination_pubkey, _parity) =
        address.spend_pubkey.add_tweak(SECP256K1, &blinding_factor).map_err(|e| StealthError::TweakFailed(e.to_string()))?;

    let output = EphemeralOutput::new(ephemeral_pubkey, view_tag, destination_pubkey);
    Ok((output, blinding_factor))
}

/// Creates a stealth output AND returns the blinding factor.
///
/// This variant is needed when the sender is also the receiver (e.g., change output)
/// and needs to pre-calculate the spending key before the transaction is broadcast.
///
/// # Use Case: Change Outputs
///
/// When sending to your own stealth address as change, you need to:
/// 1. Create the output (for the transaction)
/// 2. Pre-compute the spending key (to avoid re-scanning the blockchain)
///
/// This function returns the blinding factor `t` which can be used with
/// `derive_spending_key(spend_secret, t)` to compute the spending key immediately.
///
/// # Arguments
///
/// * `address` - The recipient's stealth address (your own address for change)
/// * `rng` - A cryptographically secure random number generator
///
/// # Returns
///
/// A tuple of:
/// - `EphemeralOutput` - The output data for the transaction
/// - `Scalar` - The blinding factor `t` for deriving the spending key
///
/// # Example
///
/// ```ignore
/// use kaspa_stealth::{create_stealth_output_with_blinding, derive_spending_key};
/// use rand::rngs::OsRng;
///
/// let (output, blinding_factor) = create_stealth_output_with_blinding(&my_address, &mut OsRng)?;
/// let spending_key = derive_spending_key(&my_spend_secret, &blinding_factor)?;
/// // Now you can sign with spending_key when spending this output
/// ```
pub fn create_stealth_output_with_blinding<R: CryptoRngCore>(
    address: &StealthAddress,
    rng: &mut R,
) -> Result<(EphemeralOutput, Scalar)> {
    // Step 1: Generate ephemeral secret key r
    // CRITICAL: This MUST be cryptographically random!
    let ephemeral_secret = SecretKey::new(rng);

    // Step 2: Compute R = r * G (ephemeral public key)
    let ephemeral_pubkey = ephemeral_secret.public_key(SECP256K1);

    // Step 3: Compute shared secret S = r * PubScan (ECDH)
    let shared_secret = compute_shared_secret_xonly(&ephemeral_secret, &address.scan_pubkey);

    // Step 4: Compute view tag = Hash("StealthViewTag", S)[0]
    let view_tag = ViewTagHash::compute_tag(shared_secret);

    // Step 5: Compute blinding factor t = Hash("StealthBlindingFactor", S)
    let blinding_hash = BlindingFactorHash::hash(shared_secret);

    // Convert hash to scalar (mod n where n is the curve order)
    let blinding_factor = Scalar::from_be_bytes(blinding_hash.as_bytes())
        .map_err(|_| StealthError::TweakFailed("blinding factor scalar overflow".into()))?;

    // Step 6: Compute P_dest = PubSpend + t*G
    let (destination_pubkey, _parity) =
        address.spend_pubkey.add_tweak(SECP256K1, &blinding_factor).map_err(|e| StealthError::TweakFailed(e.to_string()))?;

    let output = EphemeralOutput::new(ephemeral_pubkey, view_tag, destination_pubkey);

    Ok((output, blinding_factor))
}

/// Creates multiple stealth outputs for a batch transaction.
///
/// Each output gets a unique ephemeral key for maximum privacy.
/// This is the recommended way to create multiple outputs in one transaction.
///
/// # Arguments
///
/// * `addresses` - Slice of recipient stealth addresses
/// * `rng` - A cryptographically secure random number generator
///
/// # Returns
///
/// A vector of `EphemeralOutput`, one for each address in the same order.
pub fn create_stealth_outputs_batch<R: CryptoRngCore>(addresses: &[StealthAddress], rng: &mut R) -> Result<Vec<EphemeralOutput>> {
    addresses.iter().map(|addr| create_stealth_output(addr, rng)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keys::StealthSecretKey;
    use rand::rngs::OsRng;

    #[test]
    fn test_create_stealth_output() {
        let recipient_keys = StealthSecretKey::generate().unwrap();
        let address = recipient_keys.to_address();

        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Verify output structure
        assert_ne!(output.ephemeral_pubkey.serialize(), [0u8; 33]);
        assert_ne!(output.destination_pubkey.serialize(), [0u8; 32]);

        // Destination should be different from spend_pubkey (it's tweaked)
        assert_ne!(output.destination_pubkey.serialize(), address.spend_pubkey.serialize());
    }

    #[test]
    fn test_unique_outputs_per_call() {
        let recipient_keys = StealthSecretKey::generate().unwrap();
        let address = recipient_keys.to_address();

        let output1 = create_stealth_output(&address, &mut OsRng).unwrap();
        let output2 = create_stealth_output(&address, &mut OsRng).unwrap();

        // Each call should produce different outputs (different ephemeral keys)
        assert_ne!(output1.ephemeral_pubkey, output2.ephemeral_pubkey);
        assert_ne!(output1.destination_pubkey, output2.destination_pubkey);
        // View tags may or may not match (1/256 chance of collision)
    }

    #[test]
    fn test_batch_creation() {
        let keys1 = StealthSecretKey::generate().unwrap();
        let keys2 = StealthSecretKey::generate().unwrap();
        let keys3 = StealthSecretKey::generate().unwrap();

        let addresses = vec![keys1.to_address(), keys2.to_address(), keys3.to_address()];

        let outputs = create_stealth_outputs_batch(&addresses, &mut OsRng).unwrap();

        assert_eq!(outputs.len(), 3);

        // All outputs should be unique
        assert_ne!(outputs[0].ephemeral_pubkey, outputs[1].ephemeral_pubkey);
        assert_ne!(outputs[1].ephemeral_pubkey, outputs[2].ephemeral_pubkey);
    }

    #[test]
    fn test_output_serialization() {
        let recipient_keys = StealthSecretKey::generate().unwrap();
        let address = recipient_keys.to_address();

        let output = create_stealth_output(&address, &mut OsRng).unwrap();
        let bytes = output.to_bytes();

        // Should be exactly 66 bytes: 33 (R) + 1 (tag) + 32 (P_dest)
        assert_eq!(bytes.len(), 66);

        // Should be deserializable
        let restored = EphemeralOutput::from_slice(&bytes).unwrap();
        assert_eq!(output, restored);
    }

    #[test]
    fn test_create_stealth_output_with_blinding() {
        use crate::receiver::{derive_spending_key, verify_derived_key};

        let recipient_keys = StealthSecretKey::generate().unwrap();
        let address = recipient_keys.to_address();

        // Create output with blinding factor
        let (output, blinding_factor) = create_stealth_output_with_blinding(&address, &mut OsRng).unwrap();

        // Verify output structure
        assert_ne!(output.ephemeral_pubkey.serialize(), [0u8; 33]);
        assert_ne!(output.destination_pubkey.serialize(), [0u8; 32]);

        // Pre-calculate the spending key using the blinding factor
        let spending_key = derive_spending_key(&recipient_keys.spend_secret(), &blinding_factor).unwrap();

        // Verify the derived key matches the destination pubkey
        assert!(
            verify_derived_key(&spending_key, &output.destination_pubkey),
            "Pre-calculated spending key should match destination pubkey"
        );
    }

    #[test]
    fn test_with_blinding_matches_regular_output() {
        use crate::receiver::{derive_spending_key, scan_output, verify_derived_key};

        let recipient_keys = StealthSecretKey::generate().unwrap();
        let address = recipient_keys.to_address();

        // Create output with blinding factor (pre-calculation method)
        let (output, blinding_factor) = create_stealth_output_with_blinding(&address, &mut OsRng).unwrap();

        // Method 1: Use pre-calculated blinding factor directly
        let spending_key_direct = derive_spending_key(&recipient_keys.spend_secret(), &blinding_factor).unwrap();

        // Method 2: Scan the output as if we were a third party
        let scan_result = scan_output(&output, &recipient_keys.scan_secret(), &address.spend_pubkey).unwrap();
        let spending_key_scanned = derive_spending_key(&recipient_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

        // Both methods should produce the same spending key
        assert_eq!(
            spending_key_direct.secret_bytes(),
            spending_key_scanned.secret_bytes(),
            "Direct and scanned spending keys should match"
        );

        // Both should verify against the destination
        assert!(verify_derived_key(&spending_key_direct, &output.destination_pubkey));
        assert!(verify_derived_key(&spending_key_scanned, &output.destination_pubkey));
    }
}
