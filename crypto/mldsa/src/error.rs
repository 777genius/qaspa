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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = MlDsaError::InvalidPublicKeyLength { expected: 1312, actual: 100 };
        assert_eq!(err.to_string(), "Invalid public key length: expected 1312, got 100");

        let err = MlDsaError::InvalidSecretKeyLength { expected: 2560, actual: 200 };
        assert_eq!(err.to_string(), "Invalid secret key length: expected 2560, got 200");

        let err = MlDsaError::InvalidSignatureLength { expected: 2420, actual: 64 };
        assert_eq!(err.to_string(), "Invalid signature length: expected 2420, got 64");

        let err = MlDsaError::VerificationFailed;
        assert_eq!(err.to_string(), "Signature verification failed");

        let err = MlDsaError::InvalidSecurityLevel(4);
        assert_eq!(err.to_string(), "Invalid security level: 4");
    }

    #[test]
    fn test_error_clone_eq() {
        let err1 = MlDsaError::InvalidPublicKeyLength { expected: 1312, actual: 100 };
        let err2 = err1.clone();
        assert_eq!(err1, err2);

        let err3 = MlDsaError::VerificationFailed;
        let err4 = err3.clone();
        assert_eq!(err3, err4);
    }

    #[test]
    fn test_result_type() {
        let ok_result: Result<u32> = Ok(42);
        assert!(ok_result.is_ok());
        assert_eq!(ok_result, Ok(42));

        let err_result: Result<u32> = Err(MlDsaError::VerificationFailed);
        assert!(err_result.is_err());
        assert_eq!(err_result, Err(MlDsaError::VerificationFailed));
    }

    #[test]
    fn test_all_error_variants() {
        // Test all error variants for completeness
        let errors = vec![
            MlDsaError::InvalidPublicKeyLength { expected: 100, actual: 50 },
            MlDsaError::InvalidSecretKeyLength { expected: 200, actual: 100 },
            MlDsaError::InvalidSignatureLength { expected: 300, actual: 150 },
            MlDsaError::VerificationFailed,
            MlDsaError::InvalidSecurityLevel(7),
            MlDsaError::KeyGenerationFailed("test".into()),
            MlDsaError::SigningFailed("test".into()),
            MlDsaError::SerializationError("test".into()),
            MlDsaError::DeserializationError("test".into()),
        ];

        for err in errors {
            // All errors should be cloneable
            let _cloned = err.clone();
            // All errors should have a string representation
            let _string = err.to_string();
            // All errors should be debug formattable
            let _debug = format!("{:?}", err);
        }
    }
}
