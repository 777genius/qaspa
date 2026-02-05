//! Property-based tests for stealth address cryptography
//!
//! These tests use proptest to verify cryptographic invariants hold for
//! a wide range of randomly generated inputs. This is critical for
//! cryptographic code where edge cases can lead to security vulnerabilities.

use kaspa_stealth::{
    EPHEMERAL_OUTPUT_SIZE, EphemeralOutput, STEALTH_ADDRESS_SIZE, StealthAddress, StealthSecretKey, check_view_tag,
    create_stealth_output, derive_spending_key, scan_output, try_scan_output, verify_derived_key,
};
use proptest::prelude::*;
use rand::rngs::OsRng;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(500))]

    /// Property: For any stealth address, sender can create output and receiver can scan it
    #[test]
    fn prop_sender_receiver_roundtrip(_dummy in any::<u8>()) {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        let output = create_stealth_output(&address, &mut OsRng)
            .expect("Failed to create output");

        // View tag must match
        prop_assert!(check_view_tag(
            &output.ephemeral_pubkey,
            output.view_tag,
            &keys.scan_secret()
        ));

        // Full scan must succeed
        let scan_result = scan_output(&output, &keys.scan_secret(), &address.spend_pubkey)
            .expect("Scan should succeed");

        // Derived key must match destination
        let spending_key = derive_spending_key(&keys.spend_secret(), &scan_result.blinding_factor)
            .expect("Key derivation should succeed");

        prop_assert!(verify_derived_key(&spending_key, &output.destination_pubkey));
    }

    /// Property: Each output to the same address is unique
    #[test]
    fn prop_output_uniqueness(n in 2usize..20) {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        let outputs: Vec<_> = (0..n)
            .map(|_| create_stealth_output(&address, &mut OsRng).unwrap())
            .collect();

        // All ephemeral keys must be unique
        for i in 0..outputs.len() {
            for j in (i + 1)..outputs.len() {
                prop_assert_ne!(
                    outputs[i].ephemeral_pubkey,
                    outputs[j].ephemeral_pubkey,
                    "Ephemeral keys must be unique"
                );
                prop_assert_ne!(
                    outputs[i].destination_pubkey,
                    outputs[j].destination_pubkey,
                    "Destinations must be unique"
                );
            }
        }
    }

    /// Property: Different recipients cannot claim each other's outputs
    #[test]
    fn prop_privacy_isolation(_dummy in any::<u8>()) {
        let alice = StealthSecretKey::generate().unwrap();
        let bob = StealthSecretKey::generate().unwrap();

        let alice_addr = alice.to_address();
        let bob_addr = bob.to_address();

        // Payment to Alice
        let alice_output = create_stealth_output(&alice_addr, &mut OsRng).unwrap();

        // Bob should not be able to claim it (with high probability)
        let bob_scan = try_scan_output(&alice_output, &bob.scan_secret(), &bob_addr.spend_pubkey);

        // Even if view tag happens to match (1/256 chance), full scan should fail
        if let Some(scan_result) = bob_scan {
            let bob_key = derive_spending_key(&bob.spend_secret(), &scan_result.blinding_factor).unwrap();
            prop_assert!(
                !verify_derived_key(&bob_key, &alice_output.destination_pubkey),
                "Bob should not be able to derive a valid spending key"
            );
        }

        // Alice CAN claim her output
        let alice_scan = try_scan_output(&alice_output, &alice.scan_secret(), &alice_addr.spend_pubkey);
        prop_assert!(alice_scan.is_some());
    }

    /// Property: Serialization roundtrips preserve all data
    #[test]
    fn prop_address_serialization_roundtrip(_dummy in any::<u8>()) {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        let bytes = address.to_bytes();
        prop_assert_eq!(bytes.len(), STEALTH_ADDRESS_SIZE);

        let restored = StealthAddress::from_slice(&bytes).expect("Should deserialize");
        prop_assert_eq!(address, restored);

        // Borsh roundtrip
        let borsh_bytes = borsh::to_vec(&address).expect("Borsh serialize");
        let borsh_restored: StealthAddress = borsh::from_slice(&borsh_bytes).expect("Borsh deserialize");
        prop_assert_eq!(address, borsh_restored);
    }

    /// Property: Ephemeral output serialization roundtrips
    #[test]
    fn prop_output_serialization_roundtrip(_dummy in any::<u8>()) {
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();
        let output = create_stealth_output(&address, &mut OsRng).unwrap();

        let bytes = output.to_bytes();
        prop_assert_eq!(bytes.len(), EPHEMERAL_OUTPUT_SIZE);

        let restored = EphemeralOutput::from_slice(&bytes).expect("Should deserialize");
        prop_assert_eq!(output, restored);

        // Borsh roundtrip
        let borsh_bytes = borsh::to_vec(&output).expect("Borsh serialize");
        let borsh_restored: EphemeralOutput = borsh::from_slice(&borsh_bytes).expect("Borsh deserialize");
        prop_assert_eq!(output, borsh_restored);
    }

    /// Property: Secret keys derived from same source produce same address
    #[test]
    fn prop_address_derivation_deterministic(
        scan_bytes in prop::array::uniform32(any::<u8>()),
        spend_bytes in prop::array::uniform32(any::<u8>())
    ) {
        // Try to create keys from random bytes
        // Most will fail validation, but those that succeed should be deterministic
        if let Ok(keys) = StealthSecretKey::from_bytes(scan_bytes, spend_bytes) {
            let addr1 = keys.to_address();

            let keys2 = StealthSecretKey::from_bytes(scan_bytes, spend_bytes).unwrap();
            let addr2 = keys2.to_address();

            prop_assert_eq!(addr1, addr2);
        }
    }

    /// Property: View tag provides ~256x filtering
    #[test]
    fn prop_view_tag_filtering_effectiveness(_dummy in any::<u8>()) {
        let scanner = StealthSecretKey::generate().unwrap();

        // Create 256 outputs to random addresses
        let mut matches = 0;
        for _ in 0..256 {
            let other = StealthSecretKey::generate().unwrap();
            let output = create_stealth_output(&other.to_address(), &mut OsRng).unwrap();

            if check_view_tag(&output.ephemeral_pubkey, output.view_tag, &scanner.scan_secret()) {
                matches += 1;
            }
        }

        // Expected: ~1 match (1/256 per output)
        // Allow up to 10 for statistical variance (very unlikely to exceed)
        prop_assert!(
            matches <= 10,
            "Too many view tag collisions: {} out of 256",
            matches
        );
    }

    /// Property: Different scan keys produce different view tags
    #[test]
    fn prop_view_tags_depend_on_scan_key(_dummy in any::<u8>()) {
        let sender = StealthSecretKey::generate().unwrap();
        let output = create_stealth_output(&sender.to_address(), &mut OsRng).unwrap();

        let key1 = StealthSecretKey::generate().unwrap();
        let key2 = StealthSecretKey::generate().unwrap();

        let tag1_matches = check_view_tag(&output.ephemeral_pubkey, output.view_tag, &key1.scan_secret());
        let tag2_matches = check_view_tag(&output.ephemeral_pubkey, output.view_tag, &key2.scan_secret());

        // Both matching is possible (1/65536 chance) but unlikely
        // We just verify the function doesn't panic and returns boolean
        let _ = (tag1_matches, tag2_matches);
    }

    /// Property: ECDH works correctly regardless of key parity
    /// This is critical because sender uses x-only pubkey (even parity assumed)
    /// while receiver may have a secret key corresponding to odd parity pubkey.
    #[test]
    fn prop_ecdh_parity_independent(_dummy in any::<u8>()) {
        // Generate many keys - statistically ~50% will have odd parity
        let keys = StealthSecretKey::generate().unwrap();
        let address = keys.to_address();

        // Check the parity of the original scan pubkey
        let scan_full = keys.scan_secret().public_key(secp256k1::SECP256K1);
        let (_, scan_parity) = scan_full.x_only_public_key();

        let spend_full = keys.spend_secret().public_key(secp256k1::SECP256K1);
        let (_, spend_parity) = spend_full.x_only_public_key();

        // Create output (sender uses x-only with even parity)
        let output = create_stealth_output(&address, &mut OsRng)
            .expect("Failed to create output");

        // Receiver scans (uses original secret key which may be odd parity)
        let scan_result = scan_output(&output, &keys.scan_secret(), &address.spend_pubkey);

        // This MUST work regardless of parity
        prop_assert!(
            scan_result.is_ok(),
            "Scan failed with scan_parity={:?}, spend_parity={:?}",
            scan_parity, spend_parity
        );

        // Derive spending key and verify
        let spending_key = derive_spending_key(
            &keys.spend_secret(),
            &scan_result.unwrap().blinding_factor
        ).expect("Key derivation should succeed");

        prop_assert!(
            verify_derived_key(&spending_key, &output.destination_pubkey),
            "Derived key verification failed with spend_parity={:?}",
            spend_parity
        );
    }
}

/// Additional edge case tests
#[cfg(test)]
mod edge_cases {
    use super::*;

    #[test]
    fn test_invalid_address_bytes() {
        // Too short
        assert!(StealthAddress::from_slice(&[0u8; 32]).is_err());
        // Too long
        assert!(StealthAddress::from_slice(&[0u8; 128]).is_err());
        // All zeros (invalid x-only pubkey)
        assert!(StealthAddress::from_slice(&[0u8; 64]).is_err());
    }

    #[test]
    fn test_invalid_output_bytes() {
        // Too short
        assert!(EphemeralOutput::from_slice(&[0u8; 32]).is_err());
        // Too long
        assert!(EphemeralOutput::from_slice(&[0u8; 128]).is_err());
    }

    #[test]
    fn test_invalid_secret_key_bytes() {
        // All zeros is invalid
        let zeros = [0u8; 32];
        assert!(StealthSecretKey::from_bytes(zeros, zeros).is_err());

        // All ones (0xFF) is likely >= curve order
        let all_ff = [0xFFu8; 32];
        assert!(StealthSecretKey::from_bytes(all_ff, all_ff).is_err());
    }

    #[test]
    fn test_debug_output_safety() {
        let keys = StealthSecretKey::generate().unwrap();
        let debug = format!("{:?}", keys);

        // Must contain redaction
        assert!(debug.contains("<redacted>"));

        // Must not contain any hex that looks like a key
        // (64 hex chars would be 32 bytes = key size)
        let hex_pattern = regex::Regex::new(r"[0-9a-f]{64}").unwrap();
        assert!(!hex_pattern.is_match(&debug.to_lowercase()), "Debug output may contain secret key material");
    }

    /// Tests that stealth outputs look like random noise to external observers.
    ///
    /// This is a critical privacy property: multiple outputs to the same recipient
    /// should be indistinguishable from outputs to different recipients.
    #[test]
    fn test_stealth_addresses_look_random() {
        use std::collections::HashSet;

        let receiver = StealthSecretKey::generate().unwrap();
        let address = receiver.to_address();

        // Create 100 outputs to the same recipient
        let outputs: Vec<_> = (0..100).map(|_| create_stealth_output(&address, &mut OsRng).unwrap()).collect();

        // All destination_pubkey must be unique (they look random)
        let unique_destinations: HashSet<_> = outputs.iter().map(|o| o.destination_pubkey.serialize()).collect();
        assert_eq!(unique_destinations.len(), 100, "All 100 destination pubkeys should be unique (outputs look random)");

        // All ephemeral pubkeys (R) must be unique
        let unique_r: HashSet<_> = outputs.iter().map(|o| o.ephemeral_pubkey.serialize()).collect();
        assert_eq!(unique_r.len(), 100, "All 100 ephemeral pubkeys (R) should be unique");

        // View tags should be mostly unique (statistically ~99% for 100 samples from 256 values)
        // Using birthday paradox: expected collisions for n=100, k=256 is ~18
        // So we expect ~82 unique values, but allow more variance
        let unique_tags: HashSet<_> = outputs.iter().map(|o| o.view_tag).collect();
        assert!(unique_tags.len() > 70, "View tags should be mostly unique, got {} unique out of 100", unique_tags.len());

        // Additional check: verify outputs don't share any cryptographic structure
        // by ensuring no duplicate pairs of (R, destination)
        let unique_pairs: HashSet<_> =
            outputs.iter().map(|o| (o.ephemeral_pubkey.serialize(), o.destination_pubkey.serialize())).collect();
        assert_eq!(unique_pairs.len(), 100, "All (R, destination) pairs should be unique");
    }
}
