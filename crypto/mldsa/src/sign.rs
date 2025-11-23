//! ML-DSA signature generation

use crate::{error::*, keypair::SecretKey, params::MlDsaLevel};
use serde::{Deserialize, Serialize};
use std::fmt;

/// ML-DSA digital signature
///
/// Size depends on security level:
/// - Level 2: 2420 bytes
/// - Level 3: 3293 bytes
/// - Level 5: 4595 bytes
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Signature {
    pub(crate) bytes: Vec<u8>,
    pub(crate) level: MlDsaLevel,
}

impl Signature {
    /// Creates a signature from bytes
    pub fn from_bytes(bytes: &[u8], level: MlDsaLevel) -> Result<Self> {
        if bytes.len() != level.signature_len() {
            return Err(MlDsaError::InvalidSignatureLength {
                expected: level.signature_len(),
                actual: bytes.len(),
            });
        }
        Ok(Self { bytes: bytes.to_vec(), level })
    }

    /// Returns the raw bytes of the signature
    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }

    /// Returns the security level
    pub fn level(&self) -> MlDsaLevel {
        self.level
    }

    /// Returns the size in bytes
    pub fn len(&self) -> usize {
        self.bytes.len()
    }

    /// Always returns false (signatures are never empty)
    pub fn is_empty(&self) -> bool {
        false
    }

    /// Converts to hex string for display
    pub fn to_hex(&self) -> String {
        hex::encode(&self.bytes)
    }
}

impl fmt::Debug for Signature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Signature({}..{} [{} bytes, {}])",
            &self.to_hex()[..8],
            &self.to_hex()[self.to_hex().len()-8..],
            self.len(),
            self.level
        )
    }
}

impl fmt::Display for Signature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_hex())
    }
}

/// Signs a message using the ML-DSA algorithm
///
/// # Arguments
///
/// * `message` - The message to sign (arbitrary length)
/// * `secret_key` - The secret key to use for signing
///
/// # Returns
///
/// A detached ML-DSA signature
///
/// # Example
///
/// ```
/// use kaspa_mldsa::{generate_keypair, sign, verify, MlDsaLevel};
///
/// let keypair = generate_keypair(MlDsaLevel::Level2);
/// let message = b"Hello, quantum world!";
/// let signature = sign(message, &keypair.secret_key);
///
/// assert!(verify(message, &signature, &keypair.public_key));
/// ```
pub fn sign(message: &[u8], secret_key: &SecretKey) -> Signature {
    use pqcrypto_traits::sign::{DetachedSignature as _, SecretKey as _};

    let level = secret_key.level();

    let sig_bytes = match level {
        MlDsaLevel::Level2 => {
            let sk = pqcrypto_dilithium::dilithium2::SecretKey::from_bytes(secret_key.as_bytes())
                .expect("valid secret key");
            let sig = pqcrypto_dilithium::dilithium2::detached_sign(message, &sk);
            sig.as_bytes().to_vec()
        }
        MlDsaLevel::Level3 => {
            let sk = pqcrypto_dilithium::dilithium3::SecretKey::from_bytes(secret_key.as_bytes())
                .expect("valid secret key");
            let sig = pqcrypto_dilithium::dilithium3::detached_sign(message, &sk);
            sig.as_bytes().to_vec()
        }
        MlDsaLevel::Level5 => {
            let sk = pqcrypto_dilithium::dilithium5::SecretKey::from_bytes(secret_key.as_bytes())
                .expect("valid secret key");
            let sig = pqcrypto_dilithium::dilithium5::detached_sign(message, &sk);
            sig.as_bytes().to_vec()
        }
    };

    Signature { bytes: sig_bytes, level }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keypair::generate_keypair;

    #[test]
    fn test_sign_level2() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"test message";
        let sig = sign(msg, &kp.secret_key);

        assert_eq!(sig.len(), 2420);
        assert_eq!(sig.level(), MlDsaLevel::Level2);
    }

    #[test]
    fn test_sign_level3() {
        let kp = generate_keypair(MlDsaLevel::Level3);
        let msg = b"test message";
        let sig = sign(msg, &kp.secret_key);

        assert_eq!(sig.len(), 3309);
        assert_eq!(sig.level(), MlDsaLevel::Level3);
    }

    #[test]
    fn test_sign_different_messages() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let sig1 = sign(b"message1", &kp.secret_key);
        let sig2 = sign(b"message2", &kp.secret_key);

        // Different messages should produce different signatures
        assert_ne!(sig1, sig2);
    }

    #[test]
    fn test_signature_deterministic() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"deterministic test";

        // ML-DSA signatures are deterministic (same message + key → same signature)
        let sig1 = sign(msg, &kp.secret_key);
        let sig2 = sign(msg, &kp.secret_key);

        assert_eq!(sig1, sig2);
    }

    #[test]
    fn test_signature_from_bytes_invalid_length() {
        let bytes = vec![0u8; 100]; // Wrong length
        let result = Signature::from_bytes(&bytes, MlDsaLevel::Level2);
        assert!(result.is_err());
    }

    #[test]
    fn test_signature_display_debug() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"test";
        let sig = sign(msg, &kp.secret_key);

        // Test hex encoding
        let hex = sig.to_hex();
        assert_eq!(hex.len(), 2420 * 2); // 2 chars per byte

        // Test Display trait
        let display_str = format!("{}", sig);
        assert_eq!(display_str, hex);

        // Test Debug trait
        let debug_str = format!("{:?}", sig);
        assert!(debug_str.contains("Signature"));
        assert!(debug_str.contains("2420 bytes"));
        assert!(debug_str.contains("Level2"));
    }

    #[test]
    fn test_signature_is_empty() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let sig = sign(b"test", &kp.secret_key);

        assert!(!sig.is_empty());
        assert_eq!(sig.len(), 2420);
    }

    #[test]
    fn test_signature_level() {
        for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
            let kp = generate_keypair(level);
            let sig = sign(b"test", &kp.secret_key);
            assert_eq!(sig.level(), level);
        }
    }

    #[test]
    fn test_signature_from_bytes_valid() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let sig = sign(b"test", &kp.secret_key);

        // Recreate from bytes
        let sig2 = Signature::from_bytes(sig.as_bytes(), MlDsaLevel::Level2).unwrap();
        assert_eq!(sig, sig2);
    }

    #[test]
    fn test_signature_serde() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let sig = sign(b"test", &kp.secret_key);

        // Test JSON serialization
        let json = serde_json::to_string(&sig).unwrap();
        let deserialized: Signature = serde_json::from_str(&json).unwrap();
        assert_eq!(sig, deserialized);
    }
}
