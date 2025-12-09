//! ECDH (Elliptic Curve Diffie-Hellman) primitives for stealth addresses
//!
//! This module provides the core ECDH operations needed for stealth address
//! cryptography. The shared secret is computed as:
//!
//! - Sender: S = r * PubScan (using ephemeral secret r)
//! - Receiver: S = PrivScan * R (using R from blockchain)
//!
//! Both computations yield the same shared secret due to ECDH properties.

use secp256k1::{PublicKey, Scalar, SecretKey, XOnlyPublicKey, SECP256K1};

/// Computes ECDH shared secret between a secret key and a public key.
///
/// Returns the x-coordinate of the resulting point (32 bytes).
/// This is the standard ECDH construction.
///
/// # Security
///
/// The resulting shared secret should be hashed before use to ensure
/// uniform distribution and domain separation.
#[inline]
pub fn compute_shared_secret(secret: &SecretKey, public: &PublicKey) -> [u8; 32] {
    // Convert secret key to scalar for multiplication
    let scalar = Scalar::from(*secret);
    // Compute point = secret * public (ECDH)
    let point = public.mul_tweak(SECP256K1, &scalar).expect("valid tweak");
    let (xonly, _parity) = point.x_only_public_key();
    xonly.serialize()
}

/// Computes ECDH shared secret using an x-only public key.
///
/// This is used by the sender who has the recipient's stealth address
/// (which contains x-only public keys).
///
/// # Note
///
/// X-only keys have implicit even parity. This is fine for our use case
/// since we hash the shared secret before using it.
#[inline]
pub fn compute_shared_secret_xonly(secret: &SecretKey, xonly_public: &XOnlyPublicKey) -> [u8; 32] {
    // Convert x-only to full public key (assumes even parity)
    let public = PublicKey::from_x_only_public_key(*xonly_public, secp256k1::Parity::Even);
    compute_shared_secret(secret, &public)
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::rngs::OsRng;

    #[test]
    fn test_ecdh_symmetry() {
        // Generate two keypairs
        let sk_a = SecretKey::new(&mut OsRng);
        let pk_a = sk_a.public_key(SECP256K1);

        let sk_b = SecretKey::new(&mut OsRng);
        let pk_b = sk_b.public_key(SECP256K1);

        // ECDH should be symmetric
        let shared_ab = compute_shared_secret(&sk_a, &pk_b);
        let shared_ba = compute_shared_secret(&sk_b, &pk_a);

        assert_eq!(shared_ab, shared_ba);
    }

    #[test]
    fn test_ecdh_xonly_consistency() {
        // Test that x-only and full pubkey produce the same shared secret
        // when the full pubkey has EVEN parity
        for _ in 0..100 {
            let sk = SecretKey::new(&mut OsRng);
            let pk = sk.public_key(SECP256K1);
            let (xonly, parity) = pk.x_only_public_key();

            // Only test even parity keys (about 50% of generated keys)
            if parity == secp256k1::Parity::Even {
                let other_sk = SecretKey::new(&mut OsRng);

                let shared_full = compute_shared_secret(&other_sk, &pk);
                let shared_xonly = compute_shared_secret_xonly(&other_sk, &xonly);

                assert_eq!(shared_full, shared_xonly, "ECDH results must match for even parity keys");
            }
        }
    }

    #[test]
    fn test_ecdh_xonly_parity_invariant() {
        // CRITICAL TEST: Verify that our ECDH construction produces the same
        // x-coordinate regardless of whether the original key had odd or even parity.
        //
        // This is essential for stealth addresses because:
        // - Sender uses x-only pubkey (converted to even parity internally)
        // - Receiver uses their original secret key (which may correspond to odd parity pubkey)
        //
        // The math works because we extract only the x-coordinate of the result:
        // - For point P = (x, y), the negation -P = (x, -y) has the SAME x-coordinate
        // - So even if sender computes r*P_even and receiver computes priv*R where
        //   P_even = -P_original, the x-coordinates of the results are identical.

        for _ in 0..100 {
            let sk = SecretKey::new(&mut OsRng);
            let pk = sk.public_key(SECP256K1);
            let (xonly, parity) = pk.x_only_public_key();

            let other_sk = SecretKey::new(&mut OsRng);
            let other_pk = other_sk.public_key(SECP256K1);

            // Simulate sender: uses x-only (assumes even parity)
            let sender_shared = compute_shared_secret_xonly(&other_sk, &xonly);

            // Simulate receiver: uses full pubkey from sender
            let receiver_shared = compute_shared_secret(&sk, &other_pk);

            // These MUST be equal regardless of parity, because we use x-only result
            assert_eq!(sender_shared, receiver_shared, "ECDH must be symmetric even with parity difference (parity={:?})", parity);
        }
    }

    #[test]
    fn test_shared_secret_deterministic() {
        let sk_a = SecretKey::new(&mut OsRng);
        let pk_a = sk_a.public_key(SECP256K1);

        let sk_b = SecretKey::new(&mut OsRng);

        let shared1 = compute_shared_secret(&sk_b, &pk_a);
        let shared2 = compute_shared_secret(&sk_b, &pk_a);

        assert_eq!(shared1, shared2);
    }

    #[test]
    fn test_different_keys_different_secrets() {
        let sk = SecretKey::new(&mut OsRng);

        let other1 = SecretKey::new(&mut OsRng);
        let pk1 = other1.public_key(SECP256K1);

        let other2 = SecretKey::new(&mut OsRng);
        let pk2 = other2.public_key(SECP256K1);

        let shared1 = compute_shared_secret(&sk, &pk1);
        let shared2 = compute_shared_secret(&sk, &pk2);

        assert_ne!(shared1, shared2);
    }
}
