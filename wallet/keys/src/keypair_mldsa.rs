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
//! let address = keypair.to_address(kaspa_addresses::Prefix::Mainnet);
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
    /// let address = keypair.to_address(Prefix::Mainnet);
    /// ```
    pub fn to_address(&self, prefix: Prefix) -> Address {
        Address::new(prefix, Version::PubKeyMLDSA, self.keypair.public_key.as_bytes())
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
            let address = keypair.to_address(prefix);

            // Verify address properties
            assert_eq!(address.prefix, prefix);
            assert_eq!(address.version, Version::PubKeyMLDSA);
            assert_eq!(address.payload.len(), keypair.public_key_size());

            println!("✓ Generated address for {:?}: {}", prefix, address);
        }
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
}
