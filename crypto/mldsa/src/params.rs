//! ML-DSA security parameters and constants

use serde::{Deserialize, Serialize};

/// ML-DSA security levels as defined in NIST FIPS 204
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum MlDsaLevel {
    /// ML-DSA-44 (Category 2): 128-bit post-quantum security
    ///
    /// - Public key: 1312 bytes
    /// - Secret key: 2560 bytes
    /// - Signature: 2420 bytes
    /// - Recommended for most applications
    Level2 = 2,

    /// ML-DSA-65 (Category 3): 192-bit post-quantum security
    ///
    /// - Public key: 1952 bytes
    /// - Secret key: 4032 bytes
    /// - Signature: 3309 bytes
    /// - Higher security margin
    Level3 = 3,

    /// ML-DSA-87 (Category 5): 256-bit post-quantum security
    ///
    /// - Public key: 2592 bytes
    /// - Secret key: 4896 bytes
    /// - Signature: 4627 bytes
    /// - Maximum security
    Level5 = 5,
}

impl MlDsaLevel {
    /// Returns the public key size in bytes for this security level
    pub const fn public_key_len(self) -> usize {
        match self {
            MlDsaLevel::Level2 => 1312,
            MlDsaLevel::Level3 => 1952,
            MlDsaLevel::Level5 => 2592,
        }
    }

    /// Returns the secret key size in bytes for this security level
    pub const fn secret_key_len(self) -> usize {
        match self {
            MlDsaLevel::Level2 => 2560,
            MlDsaLevel::Level3 => 4032,
            MlDsaLevel::Level5 => 4896,
        }
    }

    /// Returns the signature size in bytes for this security level
    pub const fn signature_len(self) -> usize {
        match self {
            MlDsaLevel::Level2 => 2420,
            MlDsaLevel::Level3 => 3309,
            MlDsaLevel::Level5 => 4627,
        }
    }

    /// Returns the equivalent NIST security category
    pub const fn nist_category(self) -> u8 {
        self as u8
    }

    /// Returns a human-readable description of this security level
    pub const fn description(self) -> &'static str {
        match self {
            MlDsaLevel::Level2 => "ML-DSA-44: 128-bit PQ security (recommended for blockchain)",
            MlDsaLevel::Level3 => "ML-DSA-65: 192-bit PQ security (higher margin)",
            MlDsaLevel::Level5 => "ML-DSA-87: 256-bit PQ security (maximum)",
        }
    }

    /// Converts from u8, returns None if invalid
    pub const fn from_u8(value: u8) -> Option<Self> {
        match value {
            2 => Some(MlDsaLevel::Level2),
            3 => Some(MlDsaLevel::Level3),
            5 => Some(MlDsaLevel::Level5),
            _ => None,
        }
    }
}

impl Default for MlDsaLevel {
    /// Default to Level 2 (128-bit security) for optimal size/security tradeoff
    fn default() -> Self {
        MlDsaLevel::Level2
    }
}

impl std::fmt::Display for MlDsaLevel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Level{}", self.nist_category())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_size_constants() {
        assert_eq!(MlDsaLevel::Level2.public_key_len(), 1312);
        assert_eq!(MlDsaLevel::Level2.secret_key_len(), 2560);
        assert_eq!(MlDsaLevel::Level2.signature_len(), 2420);

        assert_eq!(MlDsaLevel::Level3.public_key_len(), 1952);
        assert_eq!(MlDsaLevel::Level3.secret_key_len(), 4032);
        assert_eq!(MlDsaLevel::Level3.signature_len(), 3309);

        assert_eq!(MlDsaLevel::Level5.public_key_len(), 2592);
        assert_eq!(MlDsaLevel::Level5.secret_key_len(), 4896);
        assert_eq!(MlDsaLevel::Level5.signature_len(), 4627);
    }

    #[test]
    fn test_from_u8() {
        assert_eq!(MlDsaLevel::from_u8(2), Some(MlDsaLevel::Level2));
        assert_eq!(MlDsaLevel::from_u8(3), Some(MlDsaLevel::Level3));
        assert_eq!(MlDsaLevel::from_u8(5), Some(MlDsaLevel::Level5));
        assert_eq!(MlDsaLevel::from_u8(1), None);
        assert_eq!(MlDsaLevel::from_u8(4), None);
    }

    #[test]
    fn test_default() {
        assert_eq!(MlDsaLevel::default(), MlDsaLevel::Level2);
    }
}

#[cfg(test)]
mod size_tests {
    use pqcrypto_dilithium::{dilithium2, dilithium3, dilithium5};
    use pqcrypto_traits::sign::{PublicKey, SecretKey, DetachedSignature};

    #[test]
    fn print_actual_sizes() {
        let (pk2, sk2) = dilithium2::keypair();
        let sig2 = dilithium2::detached_sign(b"test", &sk2);
        println!("Level 2: PK={}, SK={}, Sig={}", pk2.as_bytes().len(), sk2.as_bytes().len(), sig2.as_bytes().len());

        let (pk3, sk3) = dilithium3::keypair();
        let sig3 = dilithium3::detached_sign(b"test", &sk3);
        println!("Level 3: PK={}, SK={}, Sig={}", pk3.as_bytes().len(), sk3.as_bytes().len(), sig3.as_bytes().len());

        let (pk5, sk5) = dilithium5::keypair();
        let sig5 = dilithium5::detached_sign(b"test", &sk5);
        println!("Level 5: PK={}, SK={}, Sig={}", pk5.as_bytes().len(), sk5.as_bytes().len(), sig5.as_bytes().len());
    }
}
