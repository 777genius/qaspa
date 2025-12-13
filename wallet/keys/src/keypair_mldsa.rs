//!
//! [`keypair_mldsa`](mod@self) module encapsulates ML-DSA (post-quantum) keypairs.
//!
//! # Example
//!
//! ```rust
//! use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
//! use kaspa_mldsa::MlDsaLevel;
//!
//! // Generate a new ML-DSA Level 2 keypair
//! let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
//!
//! // Get the public key
//! let public_key = keypair.public_key();
//!
//! // Create an address
//! let address = keypair.to_address(kaspa_addresses::Prefix::Mainnet).unwrap();
//! ```
//!

use crate::{
    error::Error,
    imports::{Deserialize, Serialize},
};
use blake2b_simd::Params as Blake2bParams;
use hkdf::Hkdf;
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_mldsa::{
    derive_keypair_from_master_seed, generate_keypair, MasterSeed, MlDsaKeypair as CryptoMlDsaKeypair, MlDsaLevel, PublicKey,
    SecretKey, MASTER_SEED_LEN,
};
use kaspa_utils::hex::ToHex;
use sha3::Sha3_512;
use std::fmt;
use zeroize::Zeroize;

/// ML-DSA (post-quantum) keypair for wallet use.
///
/// This wraps the crypto-level [`kaspa_mldsa::MlDsaKeypair`] and provides
/// wallet-specific functionality like address generation.
///
/// # Security Levels
///
/// ML-DSA supports three security levels:
/// - **Level 2**: Recommended (1312-byte pubkey, 2420-byte signature)
/// - Level 3: Higher security (1952-byte pubkey, 3293-byte signature)
/// - Level 5: Maximum security (2592-byte pubkey, 4595-byte signature)
///
/// Level 2 provides 128-bit post-quantum security and is suitable for most applications.
#[derive(Debug, Clone)]
pub struct MlDsaKeypair {
    /// The underlying crypto keypair
    keypair: CryptoMlDsaKeypair,
    /// Security level (affects key and signature sizes)
    level: MlDsaLevel,
}

const ANCHOR_DOMAIN: &[u8] = b"mldsa-anchor";
const BIP39_TO_MASTER_SALT: &[u8] = b"kaspa.bip39->mldsa";
const BIP39_TO_MASTER_INFO_PREFIX: &[u8] = b"kaspa.account";
pub const BIP39_ROOT_SEED_LEN: usize = 64;

/// 32-byte hash of the master public key used as on-chain anchor.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MasterAnchor([u8; 32]);

impl MasterAnchor {
    pub const fn new(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub const fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl fmt::Debug for MasterAnchor {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "MasterAnchor({})", self.0.to_vec().to_hex())
    }
}

impl fmt::Display for MasterAnchor {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0.to_vec().to_hex())
    }
}

impl MlDsaKeypair {
    /// Create a new [`MlDsaKeypair`] from a crypto keypair.
    pub fn new(keypair: CryptoMlDsaKeypair, level: MlDsaLevel) -> Self {
        Self { keypair, level }
    }

    /// Generate a new random [`MlDsaKeypair`] at the specified security level.
    ///
    /// # Example
    ///
    /// ```rust
    /// use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
    /// use kaspa_mldsa::MlDsaLevel;
    ///
    /// let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
    /// ```
    pub fn random(level: MlDsaLevel) -> Self {
        let keypair = generate_keypair(level);
        Self::new(keypair, level)
    }

    /// Get a reference to the public key.
    pub fn public_key(&self) -> &PublicKey {
        &self.keypair.public_key
    }

    /// Get a reference to the secret key.
    pub fn secret_key(&self) -> &SecretKey {
        &self.keypair.secret_key
    }

    /// Get the security level of this keypair.
    pub fn level(&self) -> MlDsaLevel {
        self.level
    }

    /// Get the underlying crypto keypair.
    pub fn inner(&self) -> &CryptoMlDsaKeypair {
        &self.keypair
    }

    /// Create a Kaspa address from this keypair's public key.
    ///
    /// # Example
    ///
    /// ```rust
    /// use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
    /// use kaspa_addresses::Prefix;
    /// use kaspa_mldsa::MlDsaLevel;
    ///
    /// let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
    /// let address = keypair.to_address(Prefix::Mainnet).unwrap();
    /// ```
    pub fn to_address(&self, prefix: Prefix) -> Result<Address, Error> {
        // `Version::PubKeyMLDSA` в Kaspa адресах фиксирован на ML-DSA Level 2 (1312 bytes).
        // Для уровней 3/5 on-chain адрес сформировать нельзя — возвращаем ошибку вместо panic.
        if self.level != MlDsaLevel::Level2 {
            return Err(Error::custom(format!(
                "MLDSA address generation is only supported for Level2; current level is {:?}",
                self.level
            )));
        }

        let bytes = self.keypair.public_key.as_bytes();
        if bytes.len() != Version::PubKeyMLDSA.public_key_len() {
            return Err(Error::custom(format!(
                "invalid MLDSA public key length for PubKeyMLDSA address: expected {}, got {}",
                Version::PubKeyMLDSA.public_key_len(),
                bytes.len()
            )));
        }

        Ok(Address::new(prefix, Version::PubKeyMLDSA, bytes))
    }

    /// Get the public key as bytes.
    pub fn public_key_bytes(&self) -> &[u8] {
        self.keypair.public_key.as_bytes()
    }

    /// Get the size of the public key in bytes.
    pub fn public_key_size(&self) -> usize {
        self.keypair.public_key.len()
    }

    /// Get the size of the secret key in bytes.
    pub fn secret_key_size(&self) -> usize {
        self.keypair.secret_key.len()
    }

    /// Get the expected signature size for this keypair in bytes.
    pub fn signature_size(&self) -> usize {
        self.level.signature_len()
    }

    /// Returns the anchor hash for this keypair (BLAKE2b-256 with domain separation).
    pub fn anchor(&self) -> MasterAnchor {
        MasterAnchor::new(compute_anchor(self.public_key()))
    }

    /// Build a keypair from a deterministic master seed returned by [`kaspa_mldsa`].
    pub fn from_master_seed(master_seed: &MasterSeed, level: MlDsaLevel) -> Result<(Self, MasterAnchor), Error> {
        let crypto = derive_keypair_from_master_seed(master_seed, level)?;
        let wallet_pair = Self::new(crypto, level);
        let anchor = wallet_pair.anchor();
        Ok((wallet_pair, anchor))
    }

    /// Derive a master seed from the BIP39 root seed + account index, then return the MLDSA keypair and anchor.
    pub fn from_bip39_root_seed(
        root_seed: &[u8],
        account_index: u32,
        level: MlDsaLevel,
    ) -> Result<(Self, MasterAnchor, MasterSeed), Error> {
        let master_seed = derive_master_seed_from_bip39(root_seed, account_index)?;
        let (pair, anchor) = Self::from_master_seed(&master_seed, level)?;
        Ok((pair, anchor, master_seed))
    }
}

fn compute_anchor(public_key: &PublicKey) -> [u8; 32] {
    let mut state = Blake2bParams::new().hash_length(32).to_state();
    state.update(ANCHOR_DOMAIN);
    state.update(public_key.as_bytes());
    let hash = state.finalize();
    let mut bytes = [0u8; 32];
    bytes.copy_from_slice(hash.as_bytes());
    bytes
}

fn derive_master_seed_from_bip39(root_seed: &[u8], account_index: u32) -> Result<MasterSeed, Error> {
    if root_seed.len() != BIP39_ROOT_SEED_LEN {
        return Err(Error::custom(format!("invalid root seed length: expected {}, got {}", BIP39_ROOT_SEED_LEN, root_seed.len())));
    }

    let mut info = [0u8; BIP39_TO_MASTER_INFO_PREFIX.len() + 4];
    info[..BIP39_TO_MASTER_INFO_PREFIX.len()].copy_from_slice(BIP39_TO_MASTER_INFO_PREFIX);
    info[BIP39_TO_MASTER_INFO_PREFIX.len()..].copy_from_slice(&account_index.to_be_bytes());

    let mut okm = [0u8; MASTER_SEED_LEN];
    Hkdf::<Sha3_512>::new(Some(BIP39_TO_MASTER_SALT), root_seed)
        .expand(&info, &mut okm)
        .map_err(|_| Error::custom("failed to derive MLDSA master seed"))?;

    let master_seed = MasterSeed::from_slice(&okm).map_err(|err| Error::custom(format!("invalid MLDSA master seed: {err}")));
    okm.zeroize();
    master_seed
}

impl std::fmt::Display for MlDsaKeypair {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "MlDsaKeypair {{ level: {:?}, pubkey_size: {}, seckey_size: {} }}",
            self.level,
            self.public_key_size(),
            self.secret_key_size()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mldsa_keypair_generation() {
        // Test all three security levels
        for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
            let keypair = MlDsaKeypair::random(level);

            // Verify keypair properties
            assert_eq!(keypair.level(), level);
            assert_eq!(keypair.public_key_size(), level.public_key_len());
            assert_eq!(keypair.secret_key_size(), level.secret_key_len());
            assert_eq!(keypair.signature_size(), level.signature_len());

            println!(
                "✓ Generated {} keypair: pubkey={} bytes, seckey={} bytes, sig={} bytes",
                match level {
                    MlDsaLevel::Level2 => "Level 2",
                    MlDsaLevel::Level3 => "Level 3",
                    MlDsaLevel::Level5 => "Level 5",
                },
                keypair.public_key_size(),
                keypair.secret_key_size(),
                keypair.signature_size()
            );
        }
    }

    #[test]
    fn test_mldsa_address_generation() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);

        // Test address generation for all network types
        for prefix in [Prefix::Mainnet, Prefix::Testnet, Prefix::Simnet, Prefix::Devnet] {
            let address = keypair.to_address(prefix).expect("address");

            // Verify address properties
            assert_eq!(address.prefix, prefix);
            assert_eq!(address.version, Version::PubKeyMLDSA);
            assert_eq!(address.payload.len(), keypair.public_key_size());

            println!("✓ Generated address for {:?}: {}", prefix, address);
        }
    }

    #[test]
    fn to_address_rejects_non_level2() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level3);
        let err = keypair.to_address(Prefix::Mainnet).expect_err("must fail");
        assert!(err.to_string().contains("only supported for Level2"));
    }

    #[test]
    fn test_mldsa_level2_sizes() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);

        // Verify Level 2 specific sizes (from NIST FIPS 204)
        assert_eq!(keypair.public_key_size(), 1312, "ML-DSA Level 2 public key should be 1312 bytes");
        assert_eq!(keypair.secret_key_size(), 2560, "ML-DSA Level 2 secret key should be 2560 bytes");
        assert_eq!(keypair.signature_size(), 2420, "ML-DSA Level 2 signature should be 2420 bytes");
    }

    #[test]
    fn test_mldsa_keypair_display() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
        let display_str = format!("{}", keypair);

        // Verify display format
        assert!(display_str.contains("MlDsaKeypair"));
        assert!(display_str.contains("Level2"));
        assert!(display_str.contains("1312")); // pubkey size
        assert!(display_str.contains("2560")); // seckey size

        println!("✓ Display format: {}", display_str);
    }

    #[test]
    fn test_from_bip39_root_seed_deterministic() {
        let mut root_seed = [0u8; BIP39_ROOT_SEED_LEN];
        for (i, byte) in root_seed.iter_mut().enumerate() {
            *byte = i as u8;
        }

        let (kp1, anchor1, seed1) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 0, MlDsaLevel::Level2).unwrap();
        let (kp2, anchor2, seed2) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 0, MlDsaLevel::Level2).unwrap();

        assert_eq!(kp1.public_key(), kp2.public_key());
        assert_eq!(kp1.secret_key().as_bytes(), kp2.secret_key().as_bytes());
        assert_eq!(anchor1, anchor2);
        assert_eq!(seed1.as_bytes(), seed2.as_bytes());

        assert_eq!(anchor1.to_string(), "0a816d89bab3d6c2b3ea27151efbcbf8224afe628a1120892ba7068a3264a3f5");
    }

    #[test]
    fn anchor_deterministic_for_same_input() {
        let mut root_seed = [0u8; BIP39_ROOT_SEED_LEN];
        for (i, byte) in root_seed.iter_mut().enumerate() {
            *byte = (i as u8).wrapping_mul(3);
        }

        let (kp1, anchor1, seed1) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 5, MlDsaLevel::Level3).unwrap();
        let (kp2, anchor2, seed2) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 5, MlDsaLevel::Level3).unwrap();

        assert_eq!(anchor1, anchor2);
        assert_eq!(kp1.public_key(), kp2.public_key());
        assert_eq!(kp1.secret_key().as_bytes(), kp2.secret_key().as_bytes());
        assert_eq!(seed1.as_bytes(), seed2.as_bytes());
    }

    #[test]
    fn anchor_changes_when_account_or_level_differs() {
        let mut root_seed = [0u8; BIP39_ROOT_SEED_LEN];
        for (i, byte) in root_seed.iter_mut().enumerate() {
            *byte = (i as u8).wrapping_add(7);
        }

        let (_, anchor_l2_idx0, _) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 0, MlDsaLevel::Level2).unwrap();
        let (_, anchor_l2_idx1, _) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 1, MlDsaLevel::Level2).unwrap();
        let (_, anchor_l5_idx0, _) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 0, MlDsaLevel::Level5).unwrap();

        assert_ne!(anchor_l2_idx0, anchor_l2_idx1, "account index should alter anchor");
        assert_ne!(anchor_l2_idx0, anchor_l5_idx0, "security level should alter anchor");
    }

    #[test]
    fn anchor_matches_manual_domain_hash() {
        let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);
        let anchor = keypair.anchor();

        let manual = compute_anchor(keypair.public_key());
        assert_eq!(anchor.as_bytes(), &manual);
    }

    #[test]
    fn derive_master_seed_from_bip39_rejects_wrong_length() {
        let res = derive_master_seed_from_bip39(&[1u8; 10], 0);
        assert!(res.is_err());
    }

    #[test]
    fn derive_master_seed_from_bip39_is_deterministic() {
        let mut root_seed = [0u8; BIP39_ROOT_SEED_LEN];
        for (i, byte) in root_seed.iter_mut().enumerate() {
            *byte = (255u8).wrapping_sub(i as u8);
        }

        let seed1 = derive_master_seed_from_bip39(&root_seed, 42).unwrap();
        let seed2 = derive_master_seed_from_bip39(&root_seed, 42).unwrap();
        assert_eq!(seed1.as_bytes(), seed2.as_bytes());
    }

    #[test]
    fn derive_master_seed_from_bip39_account_index_affects_seed() {
        let mut root_seed = [0u8; BIP39_ROOT_SEED_LEN];
        for (i, byte) in root_seed.iter_mut().enumerate() {
            *byte = (i as u8).wrapping_mul(11);
        }

        let seed1 = derive_master_seed_from_bip39(&root_seed, 1).unwrap();
        let seed2 = derive_master_seed_from_bip39(&root_seed, 2).unwrap();
        assert_ne!(seed1.as_bytes(), seed2.as_bytes());
    }

    #[test]
    fn master_seed_zeroize_clears_bytes() {
        let mut root_seed = [0u8; BIP39_ROOT_SEED_LEN];
        for (i, byte) in root_seed.iter_mut().enumerate() {
            *byte = i as u8;
        }
        let (_, _, master_seed) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 0, MlDsaLevel::Level2).unwrap();
        let mut seed_copy = master_seed.clone();
        seed_copy.zeroize();
        assert_eq!(seed_copy.as_bytes(), &[0u8; MASTER_SEED_LEN]);
    }
}

#[cfg(all(test, feature = "proptest"))]
mod prop_tests {
    use super::*;
    use proptest::collection::vec;
    use proptest::prelude::*;
    use std::collections::HashSet;

    fn level_strategy() -> impl Strategy<Value = MlDsaLevel> {
        prop_oneof![Just(MlDsaLevel::Level2), Just(MlDsaLevel::Level3), Just(MlDsaLevel::Level5),]
    }

    proptest! {
        #![proptest_config(ProptestConfig { cases: 48, .. ProptestConfig::default() })]

        #[test]
        fn prop_master_seed_deterministic(root in any::<[u8; BIP39_ROOT_SEED_LEN]>(), idx in any::<u32>()) {
            let seed1 = derive_master_seed_from_bip39(&root, idx).unwrap();
            let seed2 = derive_master_seed_from_bip39(&root, idx).unwrap();
            prop_assert_eq!(seed1.as_bytes(), seed2.as_bytes());
        }

        #[test]
        fn prop_master_seed_unique_across_account_index(root in any::<[u8; BIP39_ROOT_SEED_LEN]>(), idx1 in any::<u32>(), idx2 in any::<u32>()) {
            prop_assume!(idx1 != idx2);
            let s1 = derive_master_seed_from_bip39(&root, idx1).unwrap();
            let s2 = derive_master_seed_from_bip39(&root, idx2).unwrap();
            prop_assert_ne!(s1.as_bytes(), s2.as_bytes());
        }

        #[test]
        fn prop_anchor_unique_for_random_pubkeys(samples in vec(level_strategy(), 6)) {
            let mut anchors = HashSet::new();
            for (idx, level) in samples.into_iter().enumerate() {
                let keypair = MlDsaKeypair::random(level);
                anchors.insert((idx, keypair.anchor()));
            }
            prop_assert!(anchors.len() >= 5, "anchors should remain unique in small sample");
        }
    }
}
