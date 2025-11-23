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

use kaspa_addresses::{Address, Prefix, Version};
use kaspa_mldsa::{generate_keypair, MlDsaKeypair as CryptoMlDsaKeypair, MlDsaLevel, PublicKey, SecretKey};

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
}
