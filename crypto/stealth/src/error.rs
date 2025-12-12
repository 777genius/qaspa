//! Stealth address error types

use thiserror::Error;

/// Result type for stealth address operations
pub type Result<T> = std::result::Result<T, StealthError>;

/// Errors that can occur during stealth address operations
#[derive(Error, Debug, Clone, PartialEq, Eq)]
pub enum StealthError {
    /// Cryptographically secure randomness is unavailable
    #[error("Randomness failed: {0}")]
    RandomnessFailed(String),

    /// Invalid public key bytes (wrong length or not on curve)
    #[error("Invalid public key: {0}")]
    InvalidPublicKey(String),

    /// Invalid secret key bytes
    #[error("Invalid secret key: {0}")]
    InvalidSecretKey(String),

    /// Invalid ephemeral output format
    #[error("Invalid ephemeral output: {0}")]
    InvalidEphemeralOutput(String),

    /// ECDH computation failed
    #[error("ECDH failed: {0}")]
    EcdhFailed(String),

    /// Tweak operation failed (result would be invalid point)
    #[error("Tweak operation failed: {0}")]
    TweakFailed(String),

    /// Serialization/deserialization error
    #[error("Serialization error: {0}")]
    SerializationError(String),

    /// View tag mismatch during scanning
    #[error("View tag mismatch")]
    ViewTagMismatch,

    /// Output does not belong to this address
    #[error("Output not owned by this address")]
    NotOwned,
}

impl From<secp256k1::Error> for StealthError {
    fn from(e: secp256k1::Error) -> Self {
        match e {
            secp256k1::Error::InvalidPublicKey => StealthError::InvalidPublicKey("secp256k1 validation failed".into()),
            secp256k1::Error::InvalidSecretKey => StealthError::InvalidSecretKey("secp256k1 validation failed".into()),
            secp256k1::Error::InvalidTweak => StealthError::TweakFailed("invalid tweak value".into()),
            _ => StealthError::InvalidPublicKey(e.to_string()),
        }
    }
}
