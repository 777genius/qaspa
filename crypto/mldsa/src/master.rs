use crate::{error::*, keypair::keypair_from_seed_bytes, params::MlDsaLevel, MlDsaKeypair, Result};
use hkdf::Hkdf;
use serde::{de, Deserialize, Deserializer, Serialize, Serializer};
use sha3::Sha3_512;
use zeroize::Zeroize;

pub const MASTER_SEED_LEN: usize = 48;
const MASTER_KDF_INFO: &[u8] = b"kaspa.mldsa.master";

/// Deterministic ML-DSA master seed (48 bytes).
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct MasterSeed {
    #[serde(with = "serde_seed")]
    bytes: [u8; MASTER_SEED_LEN],
}

impl MasterSeed {
    /// Constructs a master seed from a fixed-size array.
    pub const fn new(bytes: [u8; MASTER_SEED_LEN]) -> Self {
        Self { bytes }
    }

    /// Creates a master seed from a slice, returning an error if the length mismatches.
    pub fn from_slice(data: &[u8]) -> Result<Self> {
        if data.len() != MASTER_SEED_LEN {
            return Err(MlDsaError::InvalidMasterSeedLength { expected: MASTER_SEED_LEN, actual: data.len() });
        }
        let mut bytes = [0u8; MASTER_SEED_LEN];
        bytes.copy_from_slice(data);
        Ok(Self { bytes })
    }

    /// Returns the raw bytes of the seed.
    pub const fn as_bytes(&self) -> &[u8; MASTER_SEED_LEN] {
        &self.bytes
    }

    /// Consumes the seed and returns the inner bytes.
    pub fn into_bytes(mut self) -> [u8; MASTER_SEED_LEN] {
        let mut out = [0u8; MASTER_SEED_LEN];
        out.copy_from_slice(&self.bytes);
        self.zeroize();
        out
    }
}

impl Zeroize for MasterSeed {
    fn zeroize(&mut self) {
        self.bytes.zeroize();
    }
}

impl Drop for MasterSeed {
    fn drop(&mut self) {
        self.zeroize();
    }
}

/// Derives an ML-DSA keypair from a raw 48-byte seed.
pub fn derive_keypair_from_seed(seed: &[u8], level: MlDsaLevel) -> Result<MlDsaKeypair> {
    if seed.len() != MASTER_SEED_LEN {
        return Err(MlDsaError::InvalidMasterSeedLength { expected: MASTER_SEED_LEN, actual: seed.len() });
    }
    let mut derived = [0u8; 32];
    Hkdf::<Sha3_512>::new(None, seed)
        .expand(MASTER_KDF_INFO, &mut derived)
        .map_err(|err| MlDsaError::MasterDerivationFailed(format!("HKDF expand failed: {err:?}")))?;
    let keypair = keypair_from_seed_bytes(&derived, level);
    derived.zeroize();
    Ok(keypair)
}

/// Convenience wrapper accepting [`MasterSeed`].
pub fn derive_keypair_from_master_seed(master_seed: &MasterSeed, level: MlDsaLevel) -> Result<MlDsaKeypair> {
    derive_keypair_from_seed(master_seed.as_bytes(), level)
}

mod serde_seed {
    use super::*;
    use std::borrow::Cow;

    pub fn serialize<S>(bytes: &[u8; MASTER_SEED_LEN], serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_bytes(bytes)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> std::result::Result<[u8; MASTER_SEED_LEN], D::Error>
    where
        D: Deserializer<'de>,
    {
        let data: Cow<'de, [u8]> = Deserialize::deserialize(deserializer)?;
        if data.len() != MASTER_SEED_LEN {
            return Err(de::Error::invalid_length(data.len(), &format!("expected {MASTER_SEED_LEN} bytes").as_str()));
        }
        let mut out = [0u8; MASTER_SEED_LEN];
        out.copy_from_slice(&data);
        Ok(out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sha3::{Digest, Sha3_256};

    const TEST_SEED: [u8; MASTER_SEED_LEN] = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14,
        0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
        0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
    ];

    fn hash256(data: &[u8]) -> String {
        let mut hasher = Sha3_256::new();
        hasher.update(data);
        hex::encode(hasher.finalize())
    }

    #[test]
    fn determinism_known_answer_level2() {
        let seed = MasterSeed::from_slice(&TEST_SEED).unwrap();
        let keypair = derive_keypair_from_master_seed(&seed, MlDsaLevel::Level2).unwrap();
        let second = derive_keypair_from_master_seed(&seed, MlDsaLevel::Level2).unwrap();
        assert_eq!(keypair.public_key, second.public_key);
        assert_eq!(keypair.secret_key.as_bytes(), second.secret_key.as_bytes());

        let pk_hash = hash256(keypair.public_key.as_bytes());
        let sk_hash = hash256(keypair.secret_key.as_bytes());

        assert_eq!(pk_hash, "652f4587e2feb8bfa9f4b2637ea5945e9e4d5f2b972f9a72e02c86a232a79098");
        assert_eq!(sk_hash, "9a2b6811d9b0305d9d1fd6b9d102c22c86bebc9dd6b99b1845b597e33680c743");
    }

    #[test]
    fn rejects_wrong_length_seed() {
        let err = derive_keypair_from_seed(&TEST_SEED[..10], MlDsaLevel::Level2).unwrap_err();
        assert!(matches!(err, MlDsaError::InvalidMasterSeedLength { .. }));
    }

    #[test]
    fn zeroize_master_seed() {
        let mut seed = MasterSeed::new(TEST_SEED);
        seed.zeroize();
        const ZEROES: [u8; MASTER_SEED_LEN] = [0u8; MASTER_SEED_LEN];
        assert_eq!(seed.as_bytes(), &ZEROES);
    }
}
