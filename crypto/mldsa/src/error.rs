//! Error types for ML-DSA operations

use thiserror::Error;

/// Result type for ML-DSA operations
pub type Result<T> = std::result::Result<T, MlDsaError>;

/// Errors that can occur during ML-DSA operations
#[derive(Error, Debug, Clone, PartialEq, Eq)]
pub enum MlDsaError {
    /// Invalid public key length
    #[error("Invalid public key length: expected {expected}, got {actual}")]
    InvalidPublicKeyLength { expected: usize, actual: usize },

    /// Invalid secret key length
    #[error("Invalid secret key length: expected {expected}, got {actual}")]
    InvalidSecretKeyLength { expected: usize, actual: usize },

    /// Invalid signature length
    #[error("Invalid signature length: expected {expected}, got {actual}")]
    InvalidSignatureLength { expected: usize, actual: usize },

    /// Signature verification failed
    #[error("Signature verification failed")]
    VerificationFailed,

    /// Invalid security level
    #[error("Invalid security level: {0}")]
    InvalidSecurityLevel(u8),

    /// Key generation failed
    #[error("Key generation failed: {0}")]
    KeyGenerationFailed(String),

    /// Signing failed
    #[error("Signing failed: {0}")]
    SigningFailed(String),

    /// Serialization error
    #[error("Serialization error: {0}")]
    SerializationError(String),

    /// Deserialization error
    #[error("Deserialization error: {0}")]
    DeserializationError(String),
}
