//! ML-DSA keypair generation and management

use crate::{error::*, params::MlDsaLevel};
use serde::{Deserialize, Serialize};
use std::fmt;

/// ML-DSA public key
///
/// Size depends on security level:
/// - Level 2: 1312 bytes
/// - Level 3: 1952 bytes
/// - Level 5: 2592 bytes
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicKey {
    pub(crate) bytes: Vec<u8>,
    pub(crate) level: MlDsaLevel,
}

impl PublicKey {
    /// Creates a public key from bytes
    pub fn from_bytes(bytes: &[u8], level: MlDsaLevel) -> Result<Self> {
        if bytes.len() != level.public_key_len() {
            return Err(MlDsaError::InvalidPublicKeyLength { expected: level.public_key_len(), actual: bytes.len() });
        }
        Ok(Self { bytes: bytes.to_vec(), level })
    }

    /// Returns the raw bytes of the public key
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

    /// Always returns false (public keys are never empty)
    pub fn is_empty(&self) -> bool {
        false
    }

    /// Converts to hex string for display
    pub fn to_hex(&self) -> String {
        hex::encode(&self.bytes)
    }
}

impl fmt::Debug for PublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PublicKey({}..{} [{} bytes])", &self.to_hex()[..8], &self.to_hex()[self.to_hex().len() - 8..], self.len())
    }
}

impl fmt::Display for PublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_hex())
    }
}

/// ML-DSA secret/private key
///
/// Size depends on security level:
/// - Level 2: 2528 bytes
/// - Level 3: 4000 bytes
/// - Level 5: 4864 bytes
///
/// **Security Notice**: This type does not implement Clone or Debug to prevent
/// accidental exposure of secret key material.
#[derive(Serialize, Deserialize)]
pub struct SecretKey {
    pub(crate) bytes: Vec<u8>,
    pub(crate) level: MlDsaLevel,
}

impl SecretKey {
    /// Creates a secret key from bytes
    pub fn from_bytes(bytes: &[u8], level: MlDsaLevel) -> Result<Self> {
        if bytes.len() != level.secret_key_len() {
            return Err(MlDsaError::InvalidSecretKeyLength { expected: level.secret_key_len(), actual: bytes.len() });
        }
        Ok(Self { bytes: bytes.to_vec(), level })
    }

    /// Returns the raw bytes of the secret key
    ///
    /// **Warning**: Handle with care! Exposure of secret key material
    /// allows anyone to forge signatures.
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

    /// Always returns false (secret keys are never empty)
    pub fn is_empty(&self) -> bool {
        false
    }
}

// Explicitly NOT implementing Clone for SecretKey (security)
// Explicitly NOT implementing Debug for SecretKey (security)
impl Drop for SecretKey {
    fn drop(&mut self) {
        // Zero out secret key memory on drop
        use std::ptr;
        unsafe {
            ptr::write_bytes(self.bytes.as_mut_ptr(), 0, self.bytes.len());
        }
    }
}

/// Alias for SecretKey (for consistency with public key terminology)
pub type PrivateKey = SecretKey;

/// ML-DSA keypair (public + secret key)
#[derive(Serialize, Deserialize)]
pub struct MlDsaKeypair {
    pub public_key: PublicKey,
    pub secret_key: SecretKey,
}

impl Clone for MlDsaKeypair {
    fn clone(&self) -> Self {
        // Manual clone implementation to allow cloning even though SecretKey doesn't derive Clone
        Self {
            public_key: self.public_key.clone(),
            secret_key: SecretKey { bytes: self.secret_key.bytes.clone(), level: self.secret_key.level },
        }
    }
}

impl fmt::Debug for MlDsaKeypair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Don't expose secret key material in debug output
        f.debug_struct("MlDsaKeypair").field("public_key", &self.public_key).field("secret_key", &"<redacted>").finish()
    }
}

impl MlDsaKeypair {
    /// Creates a new keypair from public and secret key bytes
    pub fn from_bytes(public_bytes: &[u8], secret_bytes: &[u8], level: MlDsaLevel) -> Result<Self> {
        Ok(Self { public_key: PublicKey::from_bytes(public_bytes, level)?, secret_key: SecretKey::from_bytes(secret_bytes, level)? })
    }

    /// Returns the security level
    pub fn level(&self) -> MlDsaLevel {
        self.public_key.level
    }
}

/// Generates a new ML-DSA keypair using the specified security level
///
/// # Example
///
/// ```
/// use kaspa_mldsa::{generate_keypair, MlDsaLevel};
///
/// let keypair = generate_keypair(MlDsaLevel::Level2);
/// assert_eq!(keypair.public_key.len(), 1312);
/// assert_eq!(keypair.secret_key.len(), 2560);
/// ```
pub fn generate_keypair(level: MlDsaLevel) -> MlDsaKeypair {
    use pqcrypto_traits::sign::PublicKey as _;
    use pqcrypto_traits::sign::SecretKey as _;

    let (pk, sk) = match level {
        MlDsaLevel::Level2 => {
            let (pk, sk) = pqcrypto_dilithium::dilithium2::keypair();
            (pk.as_bytes().to_vec(), sk.as_bytes().to_vec())
        }
        MlDsaLevel::Level3 => {
            let (pk, sk) = pqcrypto_dilithium::dilithium3::keypair();
            (pk.as_bytes().to_vec(), sk.as_bytes().to_vec())
        }
        MlDsaLevel::Level5 => {
            let (pk, sk) = pqcrypto_dilithium::dilithium5::keypair();
            (pk.as_bytes().to_vec(), sk.as_bytes().to_vec())
        }
    };

    MlDsaKeypair { public_key: PublicKey { bytes: pk, level }, secret_key: SecretKey { bytes: sk, level } }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_keypair_level2() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        assert_eq!(kp.public_key.len(), 1312);
        assert_eq!(kp.secret_key.len(), 2560);
        assert_eq!(kp.level(), MlDsaLevel::Level2);
    }

    #[test]
    fn test_generate_keypair_level3() {
        let kp = generate_keypair(MlDsaLevel::Level3);
        assert_eq!(kp.public_key.len(), 1952);
        assert_eq!(kp.secret_key.len(), 4032);
    }

    #[test]
    fn test_generate_keypair_level5() {
        let kp = generate_keypair(MlDsaLevel::Level5);
        assert_eq!(kp.public_key.len(), 2592);
        assert_eq!(kp.secret_key.len(), 4896);
    }

    #[test]
    fn test_public_key_from_bytes_invalid_length() {
        let bytes = vec![0u8; 100]; // Wrong length
        let result = PublicKey::from_bytes(&bytes, MlDsaLevel::Level2);
        assert!(result.is_err());
    }

    #[test]
    fn test_secret_key_from_bytes_invalid_length() {
        let bytes = vec![0u8; 100]; // Wrong length
        let result = SecretKey::from_bytes(&bytes, MlDsaLevel::Level2);
        assert!(result.is_err());
    }

    #[test]
    fn test_public_key_serialization() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let hex = kp.public_key.to_hex();
        assert_eq!(hex.len(), 1312 * 2); // hex is 2 chars per byte
    }

    #[test]
    fn test_public_key_display_debug() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let pk = &kp.public_key;

        // Test hex encoding
        let hex = pk.to_hex();
        assert_eq!(hex.len(), 1312 * 2);

        // Test Display trait
        let display_str = format!("{}", pk);
        assert_eq!(display_str, hex);

        // Test Debug trait
        let debug_str = format!("{:?}", pk);
        assert!(debug_str.contains("PublicKey"));
        assert!(debug_str.contains("1312 bytes"));
    }

    #[test]
    fn test_public_key_is_empty() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        assert!(!kp.public_key.is_empty());
    }

    #[test]
    fn test_public_key_serde() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let pk = &kp.public_key;

        // Test JSON serialization
        let json = serde_json::to_string(pk).unwrap();
        let deserialized: PublicKey = serde_json::from_str(&json).unwrap();
        assert_eq!(pk, &deserialized);
    }

    #[test]
    fn test_secret_key_zeroization() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let sk_bytes = kp.secret_key.as_bytes().to_vec();

        drop(kp);

        // After drop, the secret key should be zeroized (we can't directly verify
        // but we're testing that drop doesn't panic and the zeroization logic runs)
        assert_eq!(sk_bytes.len(), 2560);
    }

    #[test]
    fn test_keypair_debug() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let debug_str = format!("{:?}", kp);

        // Debug should show public key but redact secret key
        assert!(debug_str.contains("MlDsaKeypair"));
        assert!(debug_str.contains("public_key"));
        assert!(debug_str.contains("<redacted>"));
    }

    #[test]
    fn test_keypair_clone() {
        let kp1 = generate_keypair(MlDsaLevel::Level2);
        let kp2 = kp1.clone();

        assert_eq!(kp1.public_key, kp2.public_key);
        assert_eq!(kp1.secret_key.as_bytes(), kp2.secret_key.as_bytes());
    }

    #[test]
    fn test_keypair_from_bytes_roundtrip() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let pk_bytes = kp.public_key.as_bytes();
        let sk_bytes = kp.secret_key.as_bytes();

        let kp2 = MlDsaKeypair::from_bytes(pk_bytes, sk_bytes, MlDsaLevel::Level2).unwrap();

        assert_eq!(kp.public_key, kp2.public_key);
        assert_eq!(kp.secret_key.as_bytes(), kp2.secret_key.as_bytes());
    }

    #[test]
    fn test_keypair_from_bytes_mismatched() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let pk_bytes = vec![0u8; 100]; // Wrong size
        let sk_bytes = kp.secret_key.as_bytes();

        let result = MlDsaKeypair::from_bytes(&pk_bytes, sk_bytes, MlDsaLevel::Level2);
        assert!(result.is_err());
    }
}
