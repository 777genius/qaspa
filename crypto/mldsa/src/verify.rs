//! ML-DSA signature verification

use crate::{
    keypair::PublicKey,
    sign::Signature,
};

/// Verifies an ML-DSA signature
///
/// # Arguments
///
/// * `message` - The message that was signed
/// * `signature` - The signature to verify
/// * `public_key` - The public key to verify against
///
/// # Returns
///
/// `true` if the signature is valid, `false` otherwise
///
/// # Example
///
/// ```
/// use kaspa_mldsa::{generate_keypair, sign, verify, MlDsaLevel};
///
/// let keypair = generate_keypair(MlDsaLevel::Level2);
/// let message = b"Hello, quantum world!";
/// let signature = sign(message, &keypair.secret_key);
///
/// assert!(verify(message, &signature, &keypair.public_key));
///
/// // Wrong message
/// assert!(!verify(b"Wrong message", &signature, &keypair.public_key));
/// ```
pub fn verify(message: &[u8], signature: &Signature, public_key: &PublicKey) -> bool {
    use pqcrypto_traits::sign::{DetachedSignature as _, PublicKey as _};

    // Security check: signature and public key must be from same level
    if signature.level() != public_key.level() {
        return false;
    }

    let level = public_key.level();

    match level {
        crate::params::MlDsaLevel::Level2 => {
            let pk = match pqcrypto_dilithium::dilithium2::PublicKey::from_bytes(public_key.as_bytes()) {
                Ok(pk) => pk,
                Err(_) => return false,
            };

            let sig = match pqcrypto_dilithium::dilithium2::DetachedSignature::from_bytes(signature.as_bytes()) {
                Ok(sig) => sig,
                Err(_) => return false,
            };

            pqcrypto_dilithium::dilithium2::verify_detached_signature(&sig, message, &pk).is_ok()
        }
        crate::params::MlDsaLevel::Level3 => {
            let pk = match pqcrypto_dilithium::dilithium3::PublicKey::from_bytes(public_key.as_bytes()) {
                Ok(pk) => pk,
                Err(_) => return false,
            };

            let sig = match pqcrypto_dilithium::dilithium3::DetachedSignature::from_bytes(signature.as_bytes()) {
                Ok(sig) => sig,
                Err(_) => return false,
            };

            pqcrypto_dilithium::dilithium3::verify_detached_signature(&sig, message, &pk).is_ok()
        }
        crate::params::MlDsaLevel::Level5 => {
            let pk = match pqcrypto_dilithium::dilithium5::PublicKey::from_bytes(public_key.as_bytes()) {
                Ok(pk) => pk,
                Err(_) => return false,
            };

            let sig = match pqcrypto_dilithium::dilithium5::DetachedSignature::from_bytes(signature.as_bytes()) {
                Ok(sig) => sig,
                Err(_) => return false,
            };

            pqcrypto_dilithium::dilithium5::verify_detached_signature(&sig, message, &pk).is_ok()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{keypair::generate_keypair, params::MlDsaLevel, sign::sign};

    #[test]
    fn test_verify_valid_signature() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"test message";
        let sig = sign(msg, &kp.secret_key);

        assert!(verify(msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_invalid_signature_wrong_message() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"original message";
        let sig = sign(msg, &kp.secret_key);

        let wrong_msg = b"tampered message";
        assert!(!verify(wrong_msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_invalid_signature_corrupted() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"test message";
        let mut sig = sign(msg, &kp.secret_key);

        // Corrupt the signature
        sig.bytes[0] ^= 0xFF;

        assert!(!verify(msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_wrong_public_key() {
        let kp1 = generate_keypair(MlDsaLevel::Level2);
        let kp2 = generate_keypair(MlDsaLevel::Level2);

        let msg = b"test message";
        let sig = sign(msg, &kp1.secret_key);

        // Signature from kp1, but verifying with kp2's public key
        assert!(!verify(msg, &sig, &kp2.public_key));
    }

    #[test]
    fn test_verify_mismatched_levels() {
        let kp2 = generate_keypair(MlDsaLevel::Level2);
        let kp3 = generate_keypair(MlDsaLevel::Level3);

        let msg = b"test";
        let sig2 = sign(msg, &kp2.secret_key);

        // Level 2 signature with Level 3 public key
        assert!(!verify(msg, &sig2, &kp3.public_key));
    }

    #[test]
    fn test_verify_all_levels() {
        for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
            let kp = generate_keypair(level);
            let msg = b"test for all levels";
            let sig = sign(msg, &kp.secret_key);

            assert!(verify(msg, &sig, &kp.public_key));
        }
    }

    #[test]
    fn test_verify_empty_message() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = b"";
        let sig = sign(msg, &kp.secret_key);

        assert!(verify(msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_large_message() {
        let kp = generate_keypair(MlDsaLevel::Level2);
        let msg = vec![0x42u8; 1_000_000]; // 1 MB message
        let sig = sign(&msg, &kp.secret_key);

        assert!(verify(&msg, &sig, &kp.public_key));
    }
}
