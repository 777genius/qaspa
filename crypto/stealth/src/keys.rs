//! Stealth address key types and structures
//!
//! This module defines the core cryptographic structures for stealth addresses:
//! - `StealthSecretKey`: The private keys (scan + spend) held by the recipient
//! - `StealthAddress`: The public address shared with senders
//! - `EphemeralOutput`: The data embedded in transaction outputs

use crate::error::{Result, StealthError};
use borsh::{BorshDeserialize, BorshSerialize};
use serde::{Deserialize, Serialize};
use std::fmt;
use zeroize::{Zeroize, ZeroizeOnDrop};

/// Size of a compressed public key (secp256k1)
pub const COMPRESSED_PUBKEY_SIZE: usize = 33;

/// Size of an x-only public key (secp256k1 Schnorr)
pub const XONLY_PUBKEY_SIZE: usize = 32;

/// Size of a secret key
pub const SECRET_KEY_SIZE: usize = 32;

/// Size of an ephemeral output in serialized form
/// [33 bytes R] + [1 byte view_tag] + [32 bytes P_dest]
pub const EPHEMERAL_OUTPUT_SIZE: usize = COMPRESSED_PUBKEY_SIZE + 1 + XONLY_PUBKEY_SIZE;

/// Size of a stealth address in serialized form
/// [32 bytes scan_pubkey] + [32 bytes spend_pubkey]
pub const STEALTH_ADDRESS_SIZE: usize = XONLY_PUBKEY_SIZE * 2;

/// Private keys for a stealth address.
///
/// The owner of these keys can:
/// - Scan the blockchain for incoming payments (using `scan_secret`)
/// - Spend received funds (using `spend_secret`)
///
/// # Security
///
/// - Keys are zeroized on drop to prevent memory leakage
/// - `scan_secret` can be shared with a view-only wallet for monitoring
/// - `spend_secret` must never leave the cold wallet
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct StealthSecretKey {
    /// Secret key for scanning incoming transactions
    /// Can be shared with a watch-only wallet
    scan_secret: [u8; SECRET_KEY_SIZE],

    /// Secret key for spending funds
    /// MUST be kept secure - this controls the money
    spend_secret: [u8; SECRET_KEY_SIZE],
}

impl StealthSecretKey {
    /// Creates a new stealth secret key from raw bytes.
    ///
    /// # Security
    ///
    /// Both keys are validated to ensure they are valid secp256k1 scalars.
    pub fn from_bytes(scan: [u8; SECRET_KEY_SIZE], spend: [u8; SECRET_KEY_SIZE]) -> Result<Self> {
        // Validate both keys are valid secp256k1 secret keys
        let _ = secp256k1::SecretKey::from_slice(&scan)?;
        let _ = secp256k1::SecretKey::from_slice(&spend)?;

        Ok(Self { scan_secret: scan, spend_secret: spend })
    }

    /// Generates a new random stealth secret key.
    ///
    /// Uses the system's cryptographically secure RNG.
    pub fn generate() -> Self {
        use rand::rngs::OsRng;

        let scan = secp256k1::SecretKey::new(&mut OsRng);
        let spend = secp256k1::SecretKey::new(&mut OsRng);

        Self { scan_secret: scan.secret_bytes(), spend_secret: spend.secret_bytes() }
    }

    /// Returns the scan secret key.
    ///
    /// This key can be shared with a watch-only wallet to monitor incoming payments.
    #[inline]
    pub fn scan_secret(&self) -> secp256k1::SecretKey {
        // SAFETY: We validated the key in from_bytes/generate
        secp256k1::SecretKey::from_slice(&self.scan_secret).expect("scan_secret was validated on construction")
    }

    /// Returns the spend secret key.
    ///
    /// # Security
    ///
    /// This key controls spending. Handle with extreme care.
    #[inline]
    pub fn spend_secret(&self) -> secp256k1::SecretKey {
        // SAFETY: We validated the key in from_bytes/generate
        secp256k1::SecretKey::from_slice(&self.spend_secret).expect("spend_secret was validated on construction")
    }

    /// Derives the public stealth address from these secret keys.
    pub fn to_address(&self) -> StealthAddress {
        let secp = secp256k1::Secp256k1::new();

        let scan_pubkey = self.scan_secret().public_key(&secp);
        let spend_pubkey = self.spend_secret().public_key(&secp);

        StealthAddress { scan_pubkey: scan_pubkey.x_only_public_key().0, spend_pubkey: spend_pubkey.x_only_public_key().0 }
    }

    /// Returns the raw scan secret bytes.
    ///
    /// # Security
    ///
    /// Handle returned bytes with care. Consider zeroizing after use.
    #[inline]
    pub fn scan_secret_bytes(&self) -> &[u8; SECRET_KEY_SIZE] {
        &self.scan_secret
    }

    /// Returns the raw spend secret bytes.
    ///
    /// # Security
    ///
    /// Handle returned bytes with extreme care. Consider zeroizing after use.
    #[inline]
    pub fn spend_secret_bytes(&self) -> &[u8; SECRET_KEY_SIZE] {
        &self.spend_secret
    }
}

impl fmt::Debug for StealthSecretKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Never expose secret key material in debug output
        f.debug_struct("StealthSecretKey").field("scan_secret", &"<redacted>").field("spend_secret", &"<redacted>").finish()
    }
}

/// A public stealth address that can be shared with senders.
///
/// Contains two x-only public keys:
/// - `scan_pubkey`: Used by senders to create shared secrets
/// - `spend_pubkey`: The base key from which one-time addresses are derived
///
/// # Address Format
///
/// When encoded as a string, uses Bech32m with HRP `qs` (mainnet) or `qstest` (testnet).
/// Payload is: [32 bytes scan_pubkey] [32 bytes spend_pubkey]
#[derive(Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct StealthAddress {
    /// Public key for scanning (x-only, 32 bytes)
    pub scan_pubkey: secp256k1::XOnlyPublicKey,

    /// Public key for spending (x-only, 32 bytes)
    pub spend_pubkey: secp256k1::XOnlyPublicKey,
}

impl StealthAddress {
    /// Creates a stealth address from raw x-only public key bytes.
    pub fn from_bytes(scan: [u8; XONLY_PUBKEY_SIZE], spend: [u8; XONLY_PUBKEY_SIZE]) -> Result<Self> {
        let scan_pubkey = secp256k1::XOnlyPublicKey::from_slice(&scan).map_err(|e| StealthError::InvalidPublicKey(e.to_string()))?;
        let spend_pubkey = secp256k1::XOnlyPublicKey::from_slice(&spend).map_err(|e| StealthError::InvalidPublicKey(e.to_string()))?;

        Ok(Self { scan_pubkey, spend_pubkey })
    }

    /// Serializes the address to bytes.
    ///
    /// Format: [32 bytes scan_pubkey] [32 bytes spend_pubkey]
    pub fn to_bytes(&self) -> [u8; STEALTH_ADDRESS_SIZE] {
        let mut bytes = [0u8; STEALTH_ADDRESS_SIZE];
        bytes[..XONLY_PUBKEY_SIZE].copy_from_slice(&self.scan_pubkey.serialize());
        bytes[XONLY_PUBKEY_SIZE..].copy_from_slice(&self.spend_pubkey.serialize());
        bytes
    }

    /// Deserializes an address from bytes.
    pub fn from_slice(bytes: &[u8]) -> Result<Self> {
        if bytes.len() != STEALTH_ADDRESS_SIZE {
            return Err(StealthError::InvalidPublicKey(format!("expected {} bytes, got {}", STEALTH_ADDRESS_SIZE, bytes.len())));
        }

        let mut scan = [0u8; XONLY_PUBKEY_SIZE];
        let mut spend = [0u8; XONLY_PUBKEY_SIZE];

        scan.copy_from_slice(&bytes[..XONLY_PUBKEY_SIZE]);
        spend.copy_from_slice(&bytes[XONLY_PUBKEY_SIZE..]);

        Self::from_bytes(scan, spend)
    }
}

impl fmt::Debug for StealthAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut scan_hex = [0u8; 64];
        let mut spend_hex = [0u8; 64];
        faster_hex::hex_encode(&self.scan_pubkey.serialize(), &mut scan_hex).ok();
        faster_hex::hex_encode(&self.spend_pubkey.serialize(), &mut spend_hex).ok();
        f.debug_struct("StealthAddress")
            .field("scan_pubkey", &std::str::from_utf8(&scan_hex).unwrap_or(""))
            .field("spend_pubkey", &std::str::from_utf8(&spend_hex).unwrap_or(""))
            .finish()
    }
}

impl fmt::Display for StealthAddress {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut scan_hex = [0u8; 64];
        let mut spend_hex = [0u8; 64];
        faster_hex::hex_encode(&self.scan_pubkey.serialize(), &mut scan_hex).ok();
        faster_hex::hex_encode(&self.spend_pubkey.serialize(), &mut spend_hex).ok();
        let scan_str = std::str::from_utf8(&scan_hex).unwrap_or("");
        let spend_str = std::str::from_utf8(&spend_hex).unwrap_or("");
        write!(f, "StealthAddr(scan:{}..{}, spend:{}..{})", &scan_str[..8], &scan_str[56..], &spend_str[..8], &spend_str[56..])
    }
}

// Manual Borsh implementation for StealthAddress
impl BorshSerialize for StealthAddress {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        writer.write_all(&self.scan_pubkey.serialize())?;
        writer.write_all(&self.spend_pubkey.serialize())?;
        Ok(())
    }
}

impl BorshDeserialize for StealthAddress {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let mut scan = [0u8; XONLY_PUBKEY_SIZE];
        let mut spend = [0u8; XONLY_PUBKEY_SIZE];

        reader.read_exact(&mut scan)?;
        reader.read_exact(&mut spend)?;

        Self::from_bytes(scan, spend).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))
    }
}

/// Data stored in a transaction output for a stealth payment.
///
/// Contains all information needed by the recipient to:
/// 1. Quickly filter using the view tag
/// 2. Verify ownership using ECDH
/// 3. Derive the spending key
///
/// # On-chain Format
///
/// This data is stored in `ScriptPublicKey` (version 16):
/// `[33 bytes R] [1 byte view_tag] [32 bytes P_dest]`
#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct EphemeralOutput {
    /// Ephemeral public key (R = r*G) created by sender
    /// 33 bytes compressed format
    pub ephemeral_pubkey: secp256k1::PublicKey,

    /// View tag for fast scanning (first byte of Hash(shared_secret))
    pub view_tag: u8,

    /// One-time destination public key (P_dest = P_spend + t*G)
    /// 32 bytes x-only format
    pub destination_pubkey: secp256k1::XOnlyPublicKey,
}

impl EphemeralOutput {
    /// Creates a new ephemeral output.
    pub fn new(ephemeral_pubkey: secp256k1::PublicKey, view_tag: u8, destination_pubkey: secp256k1::XOnlyPublicKey) -> Self {
        Self { ephemeral_pubkey, view_tag, destination_pubkey }
    }

    /// Serializes to bytes for inclusion in ScriptPublicKey.
    ///
    /// Format: [33 bytes R] [1 byte view_tag] [32 bytes P_dest]
    pub fn to_bytes(&self) -> [u8; EPHEMERAL_OUTPUT_SIZE] {
        let mut bytes = [0u8; EPHEMERAL_OUTPUT_SIZE];
        bytes[..COMPRESSED_PUBKEY_SIZE].copy_from_slice(&self.ephemeral_pubkey.serialize());
        bytes[COMPRESSED_PUBKEY_SIZE] = self.view_tag;
        bytes[COMPRESSED_PUBKEY_SIZE + 1..].copy_from_slice(&self.destination_pubkey.serialize());
        bytes
    }

    /// Deserializes from bytes (e.g., from ScriptPublicKey).
    pub fn from_slice(bytes: &[u8]) -> Result<Self> {
        if bytes.len() != EPHEMERAL_OUTPUT_SIZE {
            return Err(StealthError::InvalidEphemeralOutput(format!(
                "expected {} bytes, got {}",
                EPHEMERAL_OUTPUT_SIZE,
                bytes.len()
            )));
        }

        let ephemeral_pubkey = secp256k1::PublicKey::from_slice(&bytes[..COMPRESSED_PUBKEY_SIZE])
            .map_err(|e| StealthError::InvalidPublicKey(e.to_string()))?;

        let view_tag = bytes[COMPRESSED_PUBKEY_SIZE];

        let destination_pubkey = secp256k1::XOnlyPublicKey::from_slice(&bytes[COMPRESSED_PUBKEY_SIZE + 1..])
            .map_err(|e| StealthError::InvalidPublicKey(e.to_string()))?;

        Ok(Self { ephemeral_pubkey, view_tag, destination_pubkey })
    }
}

impl fmt::Debug for EphemeralOutput {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut eph_hex = [0u8; 66];
        let mut dest_hex = [0u8; 64];
        faster_hex::hex_encode(&self.ephemeral_pubkey.serialize(), &mut eph_hex).ok();
        faster_hex::hex_encode(&self.destination_pubkey.serialize(), &mut dest_hex).ok();
        f.debug_struct("EphemeralOutput")
            .field("ephemeral_pubkey", &std::str::from_utf8(&eph_hex).unwrap_or(""))
            .field("view_tag", &format!("0x{:02x}", self.view_tag))
            .field("destination_pubkey", &std::str::from_utf8(&dest_hex).unwrap_or(""))
            .finish()
    }
}

// Manual Borsh implementation for EphemeralOutput
impl BorshSerialize for EphemeralOutput {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        writer.write_all(&self.to_bytes())?;
        Ok(())
    }
}

impl BorshDeserialize for EphemeralOutput {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let mut bytes = [0u8; EPHEMERAL_OUTPUT_SIZE];
        reader.read_exact(&mut bytes)?;
        Self::from_slice(&bytes).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_secret_key_generation() {
        let sk = StealthSecretKey::generate();
        let address = sk.to_address();

        // Verify keys are valid
        let _ = sk.scan_secret();
        let _ = sk.spend_secret();

        // Address should be derivable
        assert_ne!(address.scan_pubkey.serialize(), [0u8; 32]);
        assert_ne!(address.spend_pubkey.serialize(), [0u8; 32]);
    }

    #[test]
    fn test_secret_key_from_bytes() {
        let sk1 = StealthSecretKey::generate();
        let sk2 = StealthSecretKey::from_bytes(*sk1.scan_secret_bytes(), *sk1.spend_secret_bytes()).unwrap();

        assert_eq!(sk1.to_address(), sk2.to_address());
    }

    #[test]
    fn test_address_serialization() {
        let sk = StealthSecretKey::generate();
        let address = sk.to_address();

        let bytes = address.to_bytes();
        let restored = StealthAddress::from_slice(&bytes).unwrap();

        assert_eq!(address, restored);
    }

    #[test]
    fn test_ephemeral_output_serialization() {
        use rand::rngs::OsRng;

        let secp = secp256k1::Secp256k1::new();
        let (secret, _) = secp.generate_keypair(&mut OsRng);
        let pubkey = secret.public_key(&secp);

        let output = EphemeralOutput { ephemeral_pubkey: pubkey, view_tag: 0x42, destination_pubkey: pubkey.x_only_public_key().0 };

        let bytes = output.to_bytes();
        assert_eq!(bytes.len(), EPHEMERAL_OUTPUT_SIZE);

        let restored = EphemeralOutput::from_slice(&bytes).unwrap();
        assert_eq!(output, restored);
    }

    #[test]
    fn test_invalid_key_bytes() {
        let invalid = [0u8; SECRET_KEY_SIZE]; // Zero is not a valid secret key
        let result = StealthSecretKey::from_bytes(invalid, invalid);
        assert!(result.is_err());
    }

    #[test]
    fn test_address_borsh_roundtrip() {
        let sk = StealthSecretKey::generate();
        let address = sk.to_address();

        let encoded = borsh::to_vec(&address).unwrap();
        let decoded: StealthAddress = borsh::from_slice(&encoded).unwrap();

        assert_eq!(address, decoded);
    }

    #[test]
    fn test_ephemeral_output_borsh_roundtrip() {
        use rand::rngs::OsRng;

        let secp = secp256k1::Secp256k1::new();
        let (secret, _) = secp.generate_keypair(&mut OsRng);
        let pubkey = secret.public_key(&secp);

        let output = EphemeralOutput { ephemeral_pubkey: pubkey, view_tag: 0xAB, destination_pubkey: pubkey.x_only_public_key().0 };

        let encoded = borsh::to_vec(&output).unwrap();
        let decoded: EphemeralOutput = borsh::from_slice(&encoded).unwrap();

        assert_eq!(output, decoded);
    }

    #[test]
    fn test_debug_does_not_leak_secrets() {
        let sk = StealthSecretKey::generate();
        let debug_str = format!("{:?}", sk);

        let mut scan_hex = [0u8; 64];
        let mut spend_hex = [0u8; 64];
        faster_hex::hex_encode(sk.scan_secret_bytes(), &mut scan_hex).ok();
        faster_hex::hex_encode(sk.spend_secret_bytes(), &mut spend_hex).ok();

        assert!(debug_str.contains("<redacted>"));
        assert!(!debug_str.contains(std::str::from_utf8(&scan_hex).unwrap()));
        assert!(!debug_str.contains(std::str::from_utf8(&spend_hex).unwrap()));
    }
}
