//! ML-DSA signature verification

use crate::{keypair::PublicKey, sign::Signature};

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
/// let keypair = generate_keypair(MlDsaLevel::Level2).unwrap();
/// let message = b"Hello, quantum world!";
/// let signature = sign(message, &keypair.secret_key).unwrap();
///
/// assert!(verify(message, &signature, &keypair.public_key));
///
/// // Wrong message
/// assert!(!verify(b"Wrong message", &signature, &keypair.public_key));
/// ```
pub fn verify(message: &[u8], signature: &Signature, public_key: &PublicKey) -> bool {
    use ml_dsa::{MlDsa44, MlDsa65, MlDsa87};
    use signature::Verifier;

    // Security check: signature and public key must be from same level
    if signature.level() != public_key.level() {
        return false;
    }

    let level = public_key.level();

    match level {
        crate::params::MlDsaLevel::Level2 => {
            let pk_encoded = match ml_dsa::EncodedVerifyingKey::<MlDsa44>::try_from(public_key.as_bytes()) {
                Ok(enc) => enc,
                Err(_) => return false,
            };
            let pk = ml_dsa::VerifyingKey::<MlDsa44>::decode(&pk_encoded);

            let sig_encoded = match ml_dsa::EncodedSignature::<MlDsa44>::try_from(signature.as_bytes()) {
                Ok(enc) => enc,
                Err(_) => return false,
            };
            let sig = match ml_dsa::Signature::<MlDsa44>::decode(&sig_encoded) {
                Some(sig) => sig,
                None => return false,
            };

            pk.verify(message, &sig).is_ok()
        }
        crate::params::MlDsaLevel::Level3 => {
            let pk_encoded = match ml_dsa::EncodedVerifyingKey::<MlDsa65>::try_from(public_key.as_bytes()) {
                Ok(enc) => enc,
                Err(_) => return false,
            };
            let pk = ml_dsa::VerifyingKey::<MlDsa65>::decode(&pk_encoded);

            let sig_encoded = match ml_dsa::EncodedSignature::<MlDsa65>::try_from(signature.as_bytes()) {
                Ok(enc) => enc,
                Err(_) => return false,
            };
            let sig = match ml_dsa::Signature::<MlDsa65>::decode(&sig_encoded) {
                Some(sig) => sig,
                None => return false,
            };

            pk.verify(message, &sig).is_ok()
        }
        crate::params::MlDsaLevel::Level5 => {
            let pk_encoded = match ml_dsa::EncodedVerifyingKey::<MlDsa87>::try_from(public_key.as_bytes()) {
                Ok(enc) => enc,
                Err(_) => return false,
            };
            let pk = ml_dsa::VerifyingKey::<MlDsa87>::decode(&pk_encoded);

            let sig_encoded = match ml_dsa::EncodedSignature::<MlDsa87>::try_from(signature.as_bytes()) {
                Ok(enc) => enc,
                Err(_) => return false,
            };
            let sig = match ml_dsa::Signature::<MlDsa87>::decode(&sig_encoded) {
                Some(sig) => sig,
                None => return false,
            };

            pk.verify(message, &sig).is_ok()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{keypair::generate_keypair, params::MlDsaLevel, sign::sign};

    #[test]
    fn test_verify_valid_signature() {
        let kp = generate_keypair(MlDsaLevel::Level2).unwrap();
        let msg = b"test message";
        let sig = sign(msg, &kp.secret_key).unwrap();

        assert!(verify(msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_invalid_signature_wrong_message() {
        let kp = generate_keypair(MlDsaLevel::Level2).unwrap();
        let msg = b"original message";
        let sig = sign(msg, &kp.secret_key).unwrap();

        let wrong_msg = b"tampered message";
        assert!(!verify(wrong_msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_invalid_signature_corrupted() {
        let kp = generate_keypair(MlDsaLevel::Level2).unwrap();
        let msg = b"test message";
        let mut sig = sign(msg, &kp.secret_key).unwrap();

        // Corrupt the signature
        sig.bytes[0] ^= 0xFF;

        assert!(!verify(msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_wrong_public_key() {
        let kp1 = generate_keypair(MlDsaLevel::Level2).unwrap();
        let kp2 = generate_keypair(MlDsaLevel::Level2).unwrap();

        let msg = b"test message";
        let sig = sign(msg, &kp1.secret_key).unwrap();

        // Signature from kp1, but verifying with kp2's public key
        assert!(!verify(msg, &sig, &kp2.public_key));
    }

    #[test]
    fn test_verify_mismatched_levels() {
        let kp2 = generate_keypair(MlDsaLevel::Level2).unwrap();
        let kp3 = generate_keypair(MlDsaLevel::Level3).unwrap();

        let msg = b"test";
        let sig2 = sign(msg, &kp2.secret_key).unwrap();

        // Level 2 signature with Level 3 public key
        assert!(!verify(msg, &sig2, &kp3.public_key));
    }

    #[test]
    fn test_verify_all_levels() {
        for level in [MlDsaLevel::Level2, MlDsaLevel::Level3, MlDsaLevel::Level5] {
            let kp = generate_keypair(level).unwrap();
            let msg = b"test for all levels";
            let sig = sign(msg, &kp.secret_key).unwrap();

            assert!(verify(msg, &sig, &kp.public_key));
        }
    }

    #[test]
    fn test_verify_empty_message() {
        let kp = generate_keypair(MlDsaLevel::Level2).unwrap();
        let msg = b"";
        let sig = sign(msg, &kp.secret_key).unwrap();

        assert!(verify(msg, &sig, &kp.public_key));
    }

    #[test]
    fn test_verify_large_message() {
        let kp = generate_keypair(MlDsaLevel::Level2).unwrap();
        let msg = vec![0x42u8; 1_000_000]; // 1 MB message
        let sig = sign(&msg, &kp.secret_key).unwrap();

        assert!(verify(&msg, &sig, &kp.public_key));
    }
}
