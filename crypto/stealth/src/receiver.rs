//! Receiver-side stealth address operations
//!
//! This module provides functions for:
//! 1. Fast scanning using view tags (check_view_tag)
//! 2. Full ownership verification (scan_output)
//! 3. Deriving the spending key for owned outputs (derive_spending_key)
//!
//! # Scanning Protocol
//!
//! For each output in the blockchain:
//! 1. Quick check: `check_view_tag(R, tag, scan_secret)` → 99.6% filtered out
//! 2. If tag matches: `scan_output(...)` → verify ownership & get blinding factor
//! 3. If owned: `derive_spending_key(spend_secret, t)` → get spending key
//!
//! # Security
//!
//! - `scan_secret` can be shared with a watch-only wallet
//! - `spend_secret` MUST remain in the cold wallet
//! - The derived spending key is for a single UTXO only

use crate::ecdh::compute_shared_secret;
use crate::error::{Result, StealthError};
use crate::hash::{BlindingFactorHash, ViewTagHash};
use crate::keys::EphemeralOutput;
use secp256k1::{PublicKey, SECP256K1, Scalar, SecretKey, XOnlyPublicKey};

/// Result of successfully scanning an output that belongs to us.
#[derive(Clone, Copy, Debug)]
pub struct ScanResult {
    /// The blinding factor used to derive the spending key
    pub blinding_factor: Scalar,
}

/// Quickly checks if an output might belong to us using the view tag.
///
/// This is a fast O(1) operation that filters out ~99.6% (255/256) of outputs
/// without performing expensive elliptic curve operations.
///
/// # Arguments
///
/// * `ephemeral_pubkey` - The R value from the blockchain (33 bytes compressed)
/// * `view_tag` - The view tag from the blockchain (1 byte)
/// * `scan_secret` - Our scan secret key
///
/// # Returns
///
/// - `true` if the view tag matches (proceed to full scan)
/// - `false` if the view tag doesn't match (definitely not ours)
///
/// # Note
///
/// A `true` result does NOT mean the output belongs to us!
/// There's a 1/256 chance of false positives.
/// Always call `scan_output` to confirm ownership.
#[inline]
pub fn check_view_tag(ephemeral_pubkey: &PublicKey, view_tag: u8, scan_secret: &SecretKey) -> bool {
    // Compute S' = PrivScan * R (ECDH)
    // Due to ECDH properties: S' = PrivScan * R = PrivScan * r*G = r * PubScan = S
    let shared_secret = compute_shared_secret(scan_secret, ephemeral_pubkey);

    // Compute expected view tag
    let expected_tag = ViewTagHash::compute_tag(shared_secret);

    expected_tag == view_tag
}

/// Performs full ownership verification of a stealth output.
///
/// This function verifies that an output was created for our stealth address
/// and returns the blinding factor needed to derive the spending key.
///
/// # Arguments
///
/// * `output` - The ephemeral output data from the blockchain
/// * `scan_secret` - Our scan secret key
/// * `spend_pubkey` - Our spend public key (from stealth address)
///
/// # Returns
///
/// - `Ok(ScanResult)` if the output belongs to us
/// - `Err(StealthError::NotOwned)` if it doesn't belong to us
/// - `Err(StealthError::ViewTagMismatch)` if the view tag doesn't match
///
/// # Performance
///
/// For best performance, call `check_view_tag` first to filter obvious non-matches.
pub fn scan_output(output: &EphemeralOutput, scan_secret: &SecretKey, spend_pubkey: &XOnlyPublicKey) -> Result<ScanResult> {
    // Step 1: Compute shared secret S = PrivScan * R
    let shared_secret = compute_shared_secret(scan_secret, &output.ephemeral_pubkey);

    // Step 2: Verify view tag (optional optimization - caller may have already checked)
    let expected_tag = ViewTagHash::compute_tag(shared_secret);
    if expected_tag != output.view_tag {
        return Err(StealthError::ViewTagMismatch);
    }

    // Step 3: Compute blinding factor t = Hash(S)
    let blinding_hash = BlindingFactorHash::hash(shared_secret);
    let blinding_factor =
        Scalar::from_be_bytes(blinding_hash.as_bytes()).map_err(|_| StealthError::TweakFailed("blinding factor overflow".into()))?;

    // Step 4: Compute expected P_dest = PubSpend + t*G
    let (expected_dest, _parity) =
        spend_pubkey.add_tweak(SECP256K1, &blinding_factor).map_err(|e| StealthError::TweakFailed(e.to_string()))?;

    // Step 5: Compare with actual destination
    if expected_dest != output.destination_pubkey {
        return Err(StealthError::NotOwned);
    }

    Ok(ScanResult { blinding_factor })
}

/// Convenience function to scan using an EphemeralOutput directly.
///
/// Combines view tag check and full scan in one call.
/// Use this when you haven't already checked the view tag.
pub fn try_scan_output(output: &EphemeralOutput, scan_secret: &SecretKey, spend_pubkey: &XOnlyPublicKey) -> Option<ScanResult> {
    // Quick view tag check first
    if !check_view_tag(&output.ephemeral_pubkey, output.view_tag, scan_secret) {
        return None;
    }

    // Full verification
    scan_output(output, scan_secret, spend_pubkey).ok()
}

/// Derives the spending secret key for an owned output.
///
/// This key can be used to sign a transaction spending the UTXO.
///
/// # Arguments
///
/// * `spend_secret` - Our master spend secret key
/// * `blinding_factor` - The blinding factor from `scan_output`
///
/// # Returns
///
/// The derived spending key with correct parity for x-only signing.
///
/// # Security
///
/// - This function requires the spend_secret (cold storage key)
/// - The returned key is for a single UTXO - don't reuse it
/// - The returned key should be zeroized after signing
///
/// # Note
///
/// This uses Keypair::add_xonly_tweak to correctly handle parity issues
/// that arise with x-only public keys (BIP-340 Schnorr).
pub fn derive_spending_key(spend_secret: &SecretKey, blinding_factor: &Scalar) -> Result<SecretKey> {
    // Use Keypair to properly handle x-only parity
    // This is the same approach as BIP-341 Taproot key tweaking
    let keypair = secp256k1::Keypair::from_secret_key(SECP256K1, spend_secret);

    let tweaked_keypair = keypair.add_xonly_tweak(SECP256K1, blinding_factor).map_err(|e| StealthError::TweakFailed(e.to_string()))?;

    Ok(SecretKey::from_keypair(&tweaked_keypair))
}

/// Verifies that a derived key matches the expected destination pubkey.
///
/// This is a sanity check to ensure key derivation is correct before signing.
pub fn verify_derived_key(derived_key: &SecretKey, expected_destination: &XOnlyPublicKey) -> bool {
    let pubkey = derived_key.public_key(SECP256K1);
    let (xonly, _) = pubkey.x_only_public_key();
    xonly == *expected_destination
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keys::StealthSecretKey;
    use crate::sender::create_stealth_output;
    use rand::rngs::OsRng;

    #[test]
    fn test_view_tag_check() {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Our scan key should match
        assert!(check_view_tag(&output.ephemeral_pubkey, output.view_tag, &keys.scan_secret()));

        // Someone else's scan key should (usually) not match
        let other_keys = StealthSecretKey::generate().unwrap();
        // Note: There's a 1/256 chance this could be a false positive
        // We don't assert here, just demonstrate the usage
        let _other_matches = check_view_tag(&output.ephemeral_pubkey, output.view_tag, &other_keys.scan_secret());
    }

    #[test]
    fn test_scan_output_success() {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Should successfully scan our own output
        let result = scan_output(&output, &keys.scan_secret(), &address.spend_pubkey);
        assert!(result.is_ok());
    }

    #[test]
    fn test_scan_output_not_ours() {
        let keys = StealthSecretKey::generate().unwrap();
        let other_keys = StealthSecretKey::generate().unwrap();

        let address = keys.to_address();
        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Other person trying to scan should fail
        let result = scan_output(&output, &other_keys.scan_secret(), &other_keys.to_address().spend_pubkey);
        assert!(result.is_err());
    }

    #[test]
    fn test_derive_spending_key() {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Scan to get blinding factor
        let scan_result = scan_output(&output, &keys.scan_secret(), &address.spend_pubkey).unwrap();

        // Derive spending key
        let derived = derive_spending_key(&keys.spend_secret(), &scan_result.blinding_factor).unwrap();

        // Verify the derived key matches the destination
        assert!(verify_derived_key(&derived, &output.destination_pubkey));
    }

    #[test]
    fn test_full_roundtrip() {
        // This is the complete flow: send -> scan -> spend

        // 1. Recipient generates keys and shares address
        let recipient_keys = StealthSecretKey::generate().unwrap();
        let address = recipient_keys.to_address();

        // 2. Sender creates stealth output
        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // 3. Recipient scans blockchain (fast path)
        let tag_matches = check_view_tag(&output.ephemeral_pubkey, output.view_tag, &recipient_keys.scan_secret());
        assert!(tag_matches);

        // 4. Recipient verifies ownership
        let scan_result = scan_output(&output, &recipient_keys.scan_secret(), &address.spend_pubkey).unwrap();

        // 5. Recipient derives spending key
        let spending_key = derive_spending_key(&recipient_keys.spend_secret(), &scan_result.blinding_factor).unwrap();

        // 6. Verify derived key can sign for this output
        assert!(verify_derived_key(&spending_key, &output.destination_pubkey));
    }

    #[test]
    fn test_multiple_outputs_to_same_address() {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        // Create multiple outputs to the same address
        let output1 = create_stealth_output(&address, &mut OsRng).unwrap();
        let output2 = create_stealth_output(&address, &mut OsRng).unwrap();
        let output3 = create_stealth_output(&address, &mut OsRng).unwrap();

        // All should scan successfully
        let scan1 = scan_output(&output1, &keys.scan_secret(), &address.spend_pubkey).unwrap();
        let scan2 = scan_output(&output2, &keys.scan_secret(), &address.spend_pubkey).unwrap();
        let scan3 = scan_output(&output3, &keys.scan_secret(), &address.spend_pubkey).unwrap();

        // Each should have a different blinding factor
        assert_ne!(scan1.blinding_factor, scan2.blinding_factor);
        assert_ne!(scan2.blinding_factor, scan3.blinding_factor);

        // Each derives a different spending key
        let key1 = derive_spending_key(&keys.spend_secret(), &scan1.blinding_factor).unwrap();
        let key2 = derive_spending_key(&keys.spend_secret(), &scan2.blinding_factor).unwrap();
        let key3 = derive_spending_key(&keys.spend_secret(), &scan3.blinding_factor).unwrap();

        assert!(verify_derived_key(&key1, &output1.destination_pubkey));
        assert!(verify_derived_key(&key2, &output2.destination_pubkey));
        assert!(verify_derived_key(&key3, &output3.destination_pubkey));
    }

    #[test]
    fn test_try_scan_output() {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();
        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Convenience function should work
        let result = try_scan_output(&output, &keys.scan_secret(), &address.spend_pubkey);
        assert!(result.is_some());

        // Other person should get None
        let other_keys = StealthSecretKey::generate().unwrap();
        let result = try_scan_output(&output, &other_keys.scan_secret(), &other_keys.to_address().spend_pubkey);
        assert!(result.is_none());
    }
}
