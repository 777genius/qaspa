//! # kaspa-mldsa
//!
//! ML-DSA (CRYSTALS-Dilithium) post-quantum digital signatures for QUBIC blockchain.
//!
//! This crate provides a clean, type-safe API for ML-DSA signatures based on the
//! NIST FIPS 204 final standard. It wraps the `ml-dsa` RustCrypto implementation
//! with additional safety and usability features.
//!
//! ## Security Levels
//!
//! ML-DSA supports three security levels:
//! - **Level 2** (dilithium2): 128-bit security, smallest signatures (~2.4 KB)
//! - **Level 3** (dilithium3): 192-bit security, medium signatures (~3.3 KB)
//! - **Level 5** (dilithium5): 256-bit security, largest signatures (~4.6 KB)
//!
//! For blockchain use, **Level 2** provides sufficient post-quantum security
//! while minimizing transaction size.
//!
//! ## Example
//!
//! ```rust
//! use kaspa_mldsa::{MlDsaLevel, generate_keypair, sign, verify};
//!
//! // Generate a keypair
//! let keypair = generate_keypair(MlDsaLevel::Level2);
//!
//! // Sign a message
//! let message = b"Hello, quantum-resistant world!";
//! let signature = sign(message, &keypair.secret_key);
//!
//! // Verify the signature
//! assert!(verify(message, &signature, &keypair.public_key));
//! ```

mod error;
mod keypair;
mod master;
mod params;
mod sign;
mod verify;

pub use error::{MlDsaError, Result};
pub use keypair::{generate_keypair, MlDsaKeypair, PrivateKey, PublicKey, SecretKey};
pub use master::{derive_keypair_from_master_seed, derive_keypair_from_seed, MasterSeed, MASTER_SEED_LEN};
pub use params::MlDsaLevel;
pub use sign::{sign, Signature};
pub use verify::verify;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_sign_verify() {
        let keypair = generate_keypair(MlDsaLevel::Level2);
        let message = b"test message";
        let sig = sign(message, &keypair.secret_key);
        assert!(verify(message, &sig, &keypair.public_key));
    }

    #[test]
    fn test_invalid_signature() {
        let keypair = generate_keypair(MlDsaLevel::Level2);
        let message = b"test message";
        let mut sig = sign(message, &keypair.secret_key);

        // Corrupt signature
        sig.bytes[0] ^= 0xFF;

        assert!(!verify(message, &sig, &keypair.public_key));
    }

    #[test]
    fn test_wrong_message() {
        let keypair = generate_keypair(MlDsaLevel::Level2);
        let message = b"original message";
        let sig = sign(message, &keypair.secret_key);

        let wrong_message = b"tampered message";
        assert!(!verify(wrong_message, &sig, &keypair.public_key));
    }

    #[test]
    fn test_all_security_levels() {
        for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
            let keypair = generate_keypair(level);
            let message = b"test";
            let sig = sign(message, &keypair.secret_key);
            assert!(verify(message, &sig, &keypair.public_key));
        }
    }
}
