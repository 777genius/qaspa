//! FFI bindings for kaspa-mldsa
//!
//! This crate provides C-compatible FFI functions for ML-DSA signature verification.
//! Designed for integration with Go (evm-l2-relayer) and other languages via CGO.
//!
//! # Safety
//!
//! All functions perform null pointer checks and validate input lengths.
//!
//! # Example usage from Go:
//!
//! ```go
//! /*
//! #cgo LDFLAGS: -L. -lkaspa_mldsa_ffi
//! #include "mldsa.h"
//! */
//! import "C"
//!
//! func VerifyMLDSA(message, signature, publicKey []byte) bool {
//!     return bool(C.kaspa_mldsa_verify(...))
//! }
//! ```

use kaspa_mldsa::{verify, MlDsaLevel, PublicKey as MlDsaPublicKey, SecretKey as MlDsaSecretKey, Signature as MlDsaSignature};
use std::ptr;
use std::slice;

/// Verify ML-DSA signature
///
/// # Safety
///
/// All pointers must be valid and point to buffers of the specified lengths.
/// Returns true if signature is valid, false otherwise.
///
/// # Parameters
///
/// - `message`: Pointer to message bytes
/// - `message_len`: Length of message
/// - `signature`: Pointer to signature bytes
/// - `signature_len`: Length of signature (2420 for Level 2, 3309 for Level 3, 4627 for Level 5)
/// - `public_key`: Pointer to public key bytes
/// - `public_key_len`: Length of public key (1312 for Level 2, 1952 for Level 3, 2592 for Level 5)
#[no_mangle]
pub extern "C" fn kaspa_mldsa_verify(
    message: *const u8,
    message_len: usize,
    signature: *const u8,
    signature_len: usize,
    public_key: *const u8,
    public_key_len: usize,
) -> bool {
    // Null pointer checks
    if message.is_null() || signature.is_null() || public_key.is_null() {
        return false;
    }

    // Length validation
    if message_len == 0 || signature_len == 0 || public_key_len == 0 {
        return false;
    }

    // Convert C pointers to Rust slices
    let message_slice = unsafe { slice::from_raw_parts(message, message_len) };
    let signature_slice = unsafe { slice::from_raw_parts(signature, signature_len) };
    let pubkey_slice = unsafe { slice::from_raw_parts(public_key, public_key_len) };

    // Detect level from public key length
    let level = match detect_level_from_pubkey(public_key_len) {
        Some(l) => l,
        None => return false,
    };

    // Verify signature length matches level
    if detect_level_from_signature(signature_len) != Some(level) {
        return false;
    }

    // Parse signature
    let sig = match MlDsaSignature::from_bytes(signature_slice, level) {
        Ok(s) => s,
        Err(_) => return false,
    };

    // Parse public key
    let pk = match MlDsaPublicKey::from_bytes(pubkey_slice, level) {
        Ok(p) => p,
        Err(_) => return false,
    };

    // Verify
    verify(message_slice, &sig, &pk)
}

/// Detect ML-DSA level from public key size
///
/// Returns:
/// - 2 for Level 2 (1312 bytes)
/// - 3 for Level 3 (1952 bytes)
/// - 5 for Level 5 (2592 bytes)
/// - 0 for unknown size
#[no_mangle]
pub extern "C" fn kaspa_mldsa_detect_level(public_key_len: usize) -> u8 {
    match public_key_len {
        1312 => 2,
        1952 => 3,
        2592 => 5,
        _ => 0,
    }
}

/// Helper: Detect MlDsaLevel from public key length
fn detect_level_from_pubkey(len: usize) -> Option<MlDsaLevel> {
    match len {
        1312 => Some(MlDsaLevel::Level2),
        1952 => Some(MlDsaLevel::Level3),
        2592 => Some(MlDsaLevel::Level5),
        _ => None,
    }
}

/// Helper: Detect MlDsaLevel from signature length
fn detect_level_from_signature(len: usize) -> Option<MlDsaLevel> {
    match len {
        2420 => Some(MlDsaLevel::Level2),
        3309 => Some(MlDsaLevel::Level3),
        4627 => Some(MlDsaLevel::Level5),
        _ => None,
    }
}

/// Helper: Detect MlDsaLevel from secret key length
fn detect_level_from_secretkey(len: usize) -> Option<MlDsaLevel> {
    match len {
        2560 => Some(MlDsaLevel::Level2),
        4032 => Some(MlDsaLevel::Level3),
        4896 => Some(MlDsaLevel::Level5),
        _ => None,
    }
}

/// Get public key size for ML-DSA Level 2
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level2_pubkey_size() -> usize {
    1312
}

/// Get signature size for ML-DSA Level 2
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level2_signature_size() -> usize {
    2420
}

/// Get public key size for ML-DSA Level 3
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level3_pubkey_size() -> usize {
    1952
}

/// Get signature size for ML-DSA Level 3
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level3_signature_size() -> usize {
    3309
}

/// Get public key size for ML-DSA Level 5
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level5_pubkey_size() -> usize {
    2592
}

/// Get signature size for ML-DSA Level 5
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level5_signature_size() -> usize {
    4627
}

/// Generate ML-DSA keypair
///
/// # Safety
///
/// `public_key_out` and `secret_key_out` must point to buffers large enough
/// to hold the keys. Use get_*_pubkey_size() and get_*_secretkey_size() to
/// determine required sizes.
///
/// Returns true on success, false on failure.
#[no_mangle]
pub extern "C" fn kaspa_mldsa_generate_keypair(
    level: u8,
    public_key_out: *mut u8,
    public_key_len: usize,
    secret_key_out: *mut u8,
    secret_key_len: usize,
) -> bool {
    // Null pointer checks
    if public_key_out.is_null() || secret_key_out.is_null() {
        return false;
    }

    // Determine level
    let mldsa_level = match level {
        2 => MlDsaLevel::Level2,
        3 => MlDsaLevel::Level3,
        5 => MlDsaLevel::Level5,
        _ => return false,
    };

    // Generate keypair
    let keypair = kaspa_mldsa::generate_keypair(mldsa_level);

    // Check buffer sizes
    if public_key_len < keypair.public_key.len() || secret_key_len < keypair.secret_key.len() {
        return false;
    }

    // Copy to output buffers
    unsafe {
        ptr::copy_nonoverlapping(keypair.public_key.as_bytes().as_ptr(), public_key_out, keypair.public_key.len());
        ptr::copy_nonoverlapping(keypair.secret_key.as_bytes().as_ptr(), secret_key_out, keypair.secret_key.len());
    }

    true
}

/// Sign a message with ML-DSA
///
/// # Safety
///
/// `signature_out` must point to a buffer large enough to hold the signature.
/// Use get_*_signature_size() to determine required size.
///
/// Returns true on success, false on failure.
#[no_mangle]
pub extern "C" fn kaspa_mldsa_sign(
    message: *const u8,
    message_len: usize,
    secret_key: *const u8,
    secret_key_len: usize,
    signature_out: *mut u8,
    signature_len: usize,
) -> bool {
    // Null pointer checks
    if message.is_null() || secret_key.is_null() || signature_out.is_null() {
        return false;
    }

    // Convert to slices
    let message_slice = unsafe { slice::from_raw_parts(message, message_len) };
    let secret_key_slice = unsafe { slice::from_raw_parts(secret_key, secret_key_len) };

    // Detect level from secret key length
    let level = match detect_level_from_secretkey(secret_key_len) {
        Some(l) => l,
        None => return false,
    };

    // Parse secret key
    let sk = match MlDsaSecretKey::from_bytes(secret_key_slice, level) {
        Ok(s) => s,
        Err(_) => return false,
    };

    // Sign
    let signature = kaspa_mldsa::sign(message_slice, &sk);

    // Check buffer size
    if signature_len < signature.len() {
        return false;
    }

    // Copy to output buffer
    unsafe {
        ptr::copy_nonoverlapping(signature.as_bytes().as_ptr(), signature_out, signature.len());
    }

    true
}

/// Get secret key size for ML-DSA Level 2
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level2_secretkey_size() -> usize {
    2560
}

/// Get secret key size for ML-DSA Level 3
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level3_secretkey_size() -> usize {
    4032
}

/// Get secret key size for ML-DSA Level 5
#[no_mangle]
pub extern "C" fn kaspa_mldsa_get_level5_secretkey_size() -> usize {
    4896
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_verify_level2() {
        let keypair = kaspa_mldsa::generate_keypair(MlDsaLevel::Level2);
        let message = b"test message";
        let signature = kaspa_mldsa::sign(message, &keypair.secret_key);

        let result = kaspa_mldsa_verify(
            message.as_ptr(),
            message.len(),
            signature.as_bytes().as_ptr(),
            signature.len(),
            keypair.public_key.as_bytes().as_ptr(),
            keypair.public_key.len(),
        );

        assert!(result, "Valid signature should verify");
    }

    #[test]
    fn test_verify_invalid() {
        let keypair = kaspa_mldsa::generate_keypair(MlDsaLevel::Level2);
        let message = b"test message";
        let signature = kaspa_mldsa::sign(message, &keypair.secret_key);

        // Corrupt signature
        let mut corrupted = signature.as_bytes().to_vec();
        corrupted[0] ^= 0xFF;

        let result = kaspa_mldsa_verify(
            message.as_ptr(),
            message.len(),
            corrupted.as_ptr(),
            corrupted.len(),
            keypair.public_key.as_bytes().as_ptr(),
            keypair.public_key.len(),
        );

        assert!(!result, "Corrupted signature should fail");
    }

    #[test]
    fn test_null_pointers() {
        let result = kaspa_mldsa_verify(std::ptr::null(), 0, std::ptr::null(), 0, std::ptr::null(), 0);
        assert!(!result, "Null pointers should return false");
    }

    #[test]
    fn test_detect_level() {
        assert_eq!(kaspa_mldsa_detect_level(1312), 2);
        assert_eq!(kaspa_mldsa_detect_level(1952), 3);
        assert_eq!(kaspa_mldsa_detect_level(2592), 5);
        assert_eq!(kaspa_mldsa_detect_level(999), 0);
    }

    #[test]
    fn test_generate_and_sign() {
        let mut public_key = vec![0u8; 1312];
        let mut secret_key = vec![0u8; 2560];

        let gen_result =
            kaspa_mldsa_generate_keypair(2, public_key.as_mut_ptr(), public_key.len(), secret_key.as_mut_ptr(), secret_key.len());

        assert!(gen_result, "Keypair generation should succeed");

        let message = b"test message";
        let mut signature = vec![0u8; 2420];

        let sign_result = kaspa_mldsa_sign(
            message.as_ptr(),
            message.len(),
            secret_key.as_ptr(),
            secret_key.len(),
            signature.as_mut_ptr(),
            signature.len(),
        );

        assert!(sign_result, "Signing should succeed");

        let verify_result = kaspa_mldsa_verify(
            message.as_ptr(),
            message.len(),
            signature.as_ptr(),
            signature.len(),
            public_key.as_ptr(),
            public_key.len(),
        );

        assert!(verify_result, "Signature should verify");
    }
}
