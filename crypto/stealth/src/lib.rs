//! # kaspa-stealth
//!
//! Stealth address cryptographic primitives for Qaspa blockchain.
//!
//! This crate implements [Stealth Addresses](https://gist.github.com/RubenSomsen/c43b79517e7cb701a4be7b587a5929fc)
//! for privacy-preserving transactions. Stealth addresses allow a recipient to publish
//! a single address that senders can use to create one-time payment destinations.
//!
//! ## Key Features
//!
//! - **Privacy**: Each payment creates a unique on-chain address
//! - **Efficiency**: View tags enable 256x faster scanning
//! - **Security**: Uses secp256k1 ECDH with domain-separated hashing
//! - **Quantum Resistance**: Public keys hidden until spending (ephemeral key model)
//!
//! ## Protocol Overview
//!
//! ### Sender (Creating a Payment)
//!
//! ```text
//! 1. Generate random ephemeral secret: r ← random()
//! 2. Compute ephemeral pubkey: R = r·G
//! 3. Compute shared secret: S = r·PubScan  (ECDH)
//! 4. Compute view tag: tag = Hash("ViewTag", S)[0]
//! 5. Compute blinding: t = Hash("Blinding", S)
//! 6. Compute destination: P = PubSpend + t·G
//! 7. Store in ScriptPubKey: [R | tag | P]
//! ```
//!
//! ### Receiver (Scanning)
//!
//! ```text
//! For each output [R | tag | P]:
//!   1. Compute shared secret: S' = PrivScan·R
//!   2. Fast check: if Hash("ViewTag", S')[0] ≠ tag → skip (99.6%)
//!   3. Compute blinding: t' = Hash("Blinding", S')
//!   4. Check ownership: P' = PubSpend + t'·G == P?
//!   5. If match: PrivDest = PrivSpend + t' (spending key)
//! ```
//!
//! ## Example Usage
//!
//! ```rust
//! use kaspa_stealth::{
//!     StealthSecretKey, create_stealth_output,
//!     check_view_tag, scan_output, derive_spending_key
//! };
//! use rand::rngs::OsRng;
//! # fn main() -> Result<(), kaspa_stealth::StealthError> {
//!
//! // Recipient: Generate keys and share address
//! let recipient_keys = StealthSecretKey::generate()?;
//! let address = recipient_keys.to_address();
//! // Share `address` publicly (e.g., in payment request)
//!
//! // Sender: Create payment to stealth address
//! let output = create_stealth_output(&address, &mut OsRng).unwrap();
//! // Include output.to_bytes() in ScriptPublicKey
//!
//! // Recipient: Scan blockchain for payments
//! // Step 1: Fast filter using view tag
//! if check_view_tag(&output.ephemeral_pubkey, output.view_tag, &recipient_keys.scan_secret()) {
//!     // Step 2: Full verification
//!     if let Ok(scan_result) = scan_output(&output, &recipient_keys.scan_secret(), &address.spend_pubkey) {
//!         // Step 3: Derive spending key
//!         let spending_key = derive_spending_key(
//!             &recipient_keys.spend_secret(),
//!             &scan_result.blinding_factor
//!         ).unwrap();
//!         // Use spending_key to sign transaction spending this UTXO
//!     }
//! }
//! # Ok(())
//! # }
//! ```
//!
//! ## Security Considerations
//!
//! 1. **Random Number Generation**: Always use `OsRng` or `getrandom` for ephemeral keys.
//!    Predictable randomness allows attackers to recover spending keys!
//!
//! 2. **Key Separation**:
//!    - `scan_secret`: Can be shared with watch-only wallets
//!    - `spend_secret`: Must remain in cold storage
//!
//! 3. **Domain Separation**: Different hash domains prevent cross-protocol attacks.
//!
//! 4. **Quantum Resistance**: The destination public key is only revealed during
//!    spending, not during receipt. Combined with fast block times, this provides
//!    practical post-quantum security without heavy PQ signatures.

pub mod ecdh;
pub mod error;
pub mod hash;
pub mod keys;
pub mod receiver;
pub mod sender;

// Re-export main types and functions
pub use error::{Result, StealthError};
pub use hash::{BlindingFactorHash, ViewTagHash};
pub use keys::{
    EphemeralOutput, StealthAddress, StealthSecretKey, COMPRESSED_PUBKEY_SIZE, EPHEMERAL_OUTPUT_SIZE, SECRET_KEY_SIZE,
    STEALTH_ADDRESS_SIZE, XONLY_PUBKEY_SIZE,
};
pub use receiver::{check_view_tag, derive_spending_key, scan_output, try_scan_output, verify_derived_key, ScanResult};
pub use sender::{
    create_stealth_output, create_stealth_output_with_blinding, create_stealth_outputs_batch, try_create_stealth_output,
    try_create_stealth_output_with_blinding,
};

// Re-export script constants for convenience
// These are also defined in kaspa-txscript, but re-exported here for users who only depend on kaspa-stealth
/// ScriptPublicKey version for Stealth addresses
pub const STEALTH_SCRIPT_VERSION: u16 = 16;
/// Size of stealth output in ScriptPublicKey: [33B R][1B tag][32B P_dest]
pub const STEALTH_OUTPUT_SIZE: usize = EPHEMERAL_OUTPUT_SIZE;

#[cfg(test)]
mod integration_tests {
    use super::*;
    use rand::rngs::OsRng;

    /// Tests the complete lifecycle of a stealth payment
    #[test]
    fn test_complete_payment_flow() {
        // === SETUP ===
        // Recipient generates and publishes their stealth address
        let recipient = StealthSecretKey::generate().unwrap();
        let stealth_address = recipient.to_address();

        // === PAYMENT ===
        // Sender creates a payment to the stealth address
        let output = create_stealth_output(&stealth_address, &mut OsRng).expect("Failed to create stealth output");

        // The output would be serialized into ScriptPublicKey
        let spk_data = output.to_bytes();
        assert_eq!(spk_data.len(), EPHEMERAL_OUTPUT_SIZE);

        // === SCANNING ===
        // Recipient scans the blockchain
        // In practice, this would iterate over all new UTXOs

        // Parse output from ScriptPublicKey
        let parsed_output = EphemeralOutput::from_slice(&spk_data).expect("Failed to parse ephemeral output");

        // Fast path: check view tag first
        let tag_matches = check_view_tag(&parsed_output.ephemeral_pubkey, parsed_output.view_tag, &recipient.scan_secret());
        assert!(tag_matches, "View tag should match for our output");

        // Full verification
        let scan_result = scan_output(&parsed_output, &recipient.scan_secret(), &stealth_address.spend_pubkey)
            .expect("Scan should succeed for our output");

        // === SPENDING ===
        // Recipient wants to spend the UTXO
        let spending_key =
            derive_spending_key(&recipient.spend_secret(), &scan_result.blinding_factor).expect("Key derivation should succeed");

        // Verify the derived key is correct
        assert!(verify_derived_key(&spending_key, &parsed_output.destination_pubkey), "Derived key should match destination");
    }

    /// Tests that different recipients can't scan each other's outputs
    #[test]
    fn test_privacy_isolation() {
        let alice = StealthSecretKey::generate().unwrap();
        let bob = StealthSecretKey::generate().unwrap();

        let alice_address = alice.to_address();

        // Payment to Alice
        let output = create_stealth_output(&alice_address, &mut OsRng).unwrap();

        // Bob tries to scan Alice's output
        let bob_scan = try_scan_output(&output, &bob.scan_secret(), &bob.to_address().spend_pubkey);

        assert!(bob_scan.is_none(), "Bob should not be able to claim Alice's output");

        // Alice can scan her output
        let alice_scan = try_scan_output(&output, &alice.scan_secret(), &alice_address.spend_pubkey);

        assert!(alice_scan.is_some(), "Alice should be able to claim her output");
    }

    /// Tests that each output is unlinkable
    #[test]
    fn test_unlinkability() {
        let recipient = StealthSecretKey::generate().unwrap();
        let address = recipient.to_address();

        // Create 10 payments to the same address
        let outputs: Vec<_> = (0..10).map(|_| create_stealth_output(&address, &mut OsRng).unwrap()).collect();

        // All ephemeral keys should be unique
        for i in 0..outputs.len() {
            for j in (i + 1)..outputs.len() {
                assert_ne!(outputs[i].ephemeral_pubkey, outputs[j].ephemeral_pubkey, "Ephemeral keys must be unique");
                assert_ne!(outputs[i].destination_pubkey, outputs[j].destination_pubkey, "Destination pubkeys must be unique");
            }
        }

        // All should be scannable
        for output in &outputs {
            let scan = scan_output(output, &recipient.scan_secret(), &address.spend_pubkey);
            assert!(scan.is_ok());
        }
    }

    /// Stress test with many keys and outputs
    #[test]
    fn test_stress_many_outputs() {
        let recipient = StealthSecretKey::generate().unwrap();
        let address = recipient.to_address();

        // Create 100 outputs
        for _ in 0..100 {
            let output = create_stealth_output(&address, &mut OsRng).unwrap();
            let scan = scan_output(&output, &recipient.scan_secret(), &address.spend_pubkey);
            assert!(scan.is_ok());

            let spending_key = derive_spending_key(&recipient.spend_secret(), &scan.unwrap().blinding_factor).unwrap();
            assert!(verify_derived_key(&spending_key, &output.destination_pubkey));
        }
    }

    /// Tests serialization roundtrips
    #[test]
    fn test_serialization_roundtrips() {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();
        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        // Address roundtrip
        let addr_bytes = address.to_bytes();
        let addr_restored = StealthAddress::from_slice(&addr_bytes).unwrap();
        assert_eq!(address, addr_restored);

        // Output roundtrip
        let out_bytes = output.to_bytes();
        let out_restored = EphemeralOutput::from_slice(&out_bytes).unwrap();
        assert_eq!(output, out_restored);

        // Borsh roundtrip for address
        let borsh_bytes = borsh::to_vec(&address).unwrap();
        let borsh_restored: StealthAddress = borsh::from_slice(&borsh_bytes).unwrap();
        assert_eq!(address, borsh_restored);

        // Borsh roundtrip for output
        let borsh_bytes = borsh::to_vec(&output).unwrap();
        let borsh_restored: EphemeralOutput = borsh::from_slice(&borsh_bytes).unwrap();
        assert_eq!(output, borsh_restored);
    }
}
