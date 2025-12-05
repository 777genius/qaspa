/**
 * @file mldsa.h
 * @brief C API for Kaspa ML-DSA (CRYSTALS-Dilithium) signatures
 *
 * This header provides C-compatible functions for ML-DSA signature operations.
 * Designed for use with Go via CGO, but compatible with any C/C++ project.
 *
 * @example
 * ```c
 * // Verify a signature
 * bool valid = kaspa_mldsa_verify(
 *     message, message_len,
 *     signature, signature_len,
 *     public_key, public_key_len
 * );
 * ```
 */

#ifndef KASPA_MLDSA_H
#define KASPA_MLDSA_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Verify an ML-DSA signature
 *
 * Verifies a signature against a message and public key. Supports all three
 * ML-DSA security levels (2, 3, 5) automatically based on signature/key sizes.
 *
 * @param message Pointer to message bytes (must not be NULL)
 * @param message_len Length of message in bytes
 * @param signature Pointer to signature bytes (must not be NULL)
 * @param signature_len Length of signature (2420/3309/4627 for Level 2/3/5)
 * @param public_key Pointer to public key bytes (must not be NULL)
 * @param public_key_len Length of public key (1312/1952/2592 for Level 2/3/5)
 *
 * @return true if signature is valid, false otherwise
 *
 * @note Returns false if any pointer is NULL or lengths are invalid
 */
bool kaspa_mldsa_verify(
    const uint8_t* message,
    size_t message_len,
    const uint8_t* signature,
    size_t signature_len,
    const uint8_t* public_key,
    size_t public_key_len
);

/**
 * @brief Detect ML-DSA security level from public key size
 *
 * @param public_key_len Size of public key in bytes
 * @return 2, 3, or 5 for valid levels; 0 for unknown size
 */
uint8_t kaspa_mldsa_detect_level(size_t public_key_len);

/**
 * @brief Generate an ML-DSA keypair
 *
 * @param level Security level (2, 3, or 5)
 * @param public_key_out Buffer to receive public key (must be large enough)
 * @param public_key_len Size of public_key_out buffer
 * @param secret_key_out Buffer to receive secret key (must be large enough)
 * @param secret_key_len Size of secret_key_out buffer
 *
 * @return true on success, false on failure
 *
 * @note Use kaspa_mldsa_get_level*_pubkey_size() and
 *       kaspa_mldsa_get_level*_secretkey_size() to determine buffer sizes
 */
bool kaspa_mldsa_generate_keypair(
    uint8_t level,
    uint8_t* public_key_out,
    size_t public_key_len,
    uint8_t* secret_key_out,
    size_t secret_key_len
);

/**
 * @brief Deterministically derive a keypair from a master seed (48 bytes)
 *
 * @param seed Pointer to master seed bytes (must be 48 bytes)
 * @param seed_len Length of the seed buffer
 * @param level Security level (2, 3, or 5)
 * @param public_key_out Output buffer for public key
 * @param public_key_len Size of public_key_out buffer
 * @param secret_key_out Output buffer for secret key
 * @param secret_key_len Size of secret_key_out buffer
 *
 * @return true on success, false otherwise
 */
bool kaspa_mldsa_derive_keypair(
    const uint8_t* seed,
    size_t seed_len,
    uint8_t level,
    uint8_t* public_key_out,
    size_t public_key_len,
    uint8_t* secret_key_out,
    size_t secret_key_len
);

/**
 * @brief Sign a message with ML-DSA
 *
 * @param message Pointer to message bytes (must not be NULL)
 * @param message_len Length of message in bytes
 * @param secret_key Pointer to secret key bytes (must not be NULL)
 * @param secret_key_len Length of secret key
 * @param signature_out Buffer to receive signature (must be large enough)
 * @param signature_len Size of signature_out buffer
 *
 * @return true on success, false on failure
 *
 * @note Use kaspa_mldsa_get_level*_signature_size() to determine buffer size
 */
bool kaspa_mldsa_sign(
    const uint8_t* message,
    size_t message_len,
    const uint8_t* secret_key,
    size_t secret_key_len,
    uint8_t* signature_out,
    size_t signature_len
);

/* Size getters for ML-DSA Level 2 (128-bit security, recommended) */

/**
 * @brief Get public key size for ML-DSA Level 2
 * @return 1312 bytes
 */
size_t kaspa_mldsa_get_level2_pubkey_size(void);

/**
 * @brief Get signature size for ML-DSA Level 2
 * @return 2420 bytes
 */
size_t kaspa_mldsa_get_level2_signature_size(void);

/**
 * @brief Get secret key size for ML-DSA Level 2
 * @return 2560 bytes
 */
size_t kaspa_mldsa_get_level2_secretkey_size(void);

/* Size getters for ML-DSA Level 3 (192-bit security) */

/**
 * @brief Get public key size for ML-DSA Level 3
 * @return 1952 bytes
 */
size_t kaspa_mldsa_get_level3_pubkey_size(void);

/**
 * @brief Get signature size for ML-DSA Level 3
 * @return 3309 bytes
 */
size_t kaspa_mldsa_get_level3_signature_size(void);

/**
 * @brief Get secret key size for ML-DSA Level 3
 * @return 4032 bytes
 */
size_t kaspa_mldsa_get_level3_secretkey_size(void);

/* Size getters for ML-DSA Level 5 (256-bit security) */

/**
 * @brief Get public key size for ML-DSA Level 5
 * @return 2592 bytes
 */
size_t kaspa_mldsa_get_level5_pubkey_size(void);

/**
 * @brief Get signature size for ML-DSA Level 5
 * @return 4627 bytes
 */
size_t kaspa_mldsa_get_level5_signature_size(void);

/**
 * @brief Get secret key size for ML-DSA Level 5
 * @return 4896 bytes
 */
size_t kaspa_mldsa_get_level5_secretkey_size(void);

/**
 * @brief Get the length of the master seed (bytes)
 * @return 48 bytes
 */
size_t kaspa_mldsa_master_seed_len(void);

#ifdef __cplusplus
}
#endif

#endif /* KASPA_MLDSA_H */
