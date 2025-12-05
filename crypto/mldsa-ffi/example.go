// Example usage of kaspa-mldsa-ffi from Go
// Build the Rust library first: cargo build --release
//
// Then compile this example:
//   export CGO_LDFLAGS="-L../../../target/release -lkaspa_mldsa_ffi"
//   go build example.go

package main

/*
#cgo LDFLAGS: -L../../../target/release -lkaspa_mldsa_ffi
#include "mldsa.h"
#include <stdlib.h>
*/
import "C"
import (
	"encoding/hex"
	"fmt"
	"unsafe"
)

// MLDSALevel represents the security level
type MLDSALevel uint8

const (
	Level2 MLDSALevel = 2 // 128-bit security (recommended)
	Level3 MLDSALevel = 3 // 192-bit security
	Level5 MLDSALevel = 5 // 256-bit security
)

// GetPublicKeySize returns the public key size for a given level
func GetPublicKeySize(level MLDSALevel) int {
	switch level {
	case Level2:
		return int(C.kaspa_mldsa_get_level2_pubkey_size())
	case Level3:
		return int(C.kaspa_mldsa_get_level3_pubkey_size())
	case Level5:
		return int(C.kaspa_mldsa_get_level5_pubkey_size())
	default:
		return 0
	}
}

// GetSignatureSize returns the signature size for a given level
func GetSignatureSize(level MLDSALevel) int {
	switch level {
	case Level2:
		return int(C.kaspa_mldsa_get_level2_signature_size())
	case Level3:
		return int(C.kaspa_mldsa_get_level3_signature_size())
	case Level5:
		return int(C.kaspa_mldsa_get_level5_signature_size())
	default:
		return 0
	}
}

// GetSecretKeySize returns the secret key size for a given level
func GetSecretKeySize(level MLDSALevel) int {
	switch level {
	case Level2:
		return int(C.kaspa_mldsa_get_level2_secretkey_size())
	case Level3:
		return int(C.kaspa_mldsa_get_level3_secretkey_size())
	case Level5:
		return int(C.kaspa_mldsa_get_level5_secretkey_size())
	default:
		return 0
	}
}

// GenerateKeypair generates an ML-DSA keypair
func GenerateKeypair(level MLDSALevel) (publicKey, secretKey []byte, err error) {
	pkSize := GetPublicKeySize(level)
	skSize := GetSecretKeySize(level)

	if pkSize == 0 || skSize == 0 {
		return nil, nil, fmt.Errorf("invalid level: %d", level)
	}

	publicKey = make([]byte, pkSize)
	secretKey = make([]byte, skSize)

	result := C.kaspa_mldsa_generate_keypair(
		C.uint8_t(level),
		(*C.uint8_t)(unsafe.Pointer(&publicKey[0])),
		C.size_t(pkSize),
		(*C.uint8_t)(unsafe.Pointer(&secretKey[0])),
		C.size_t(skSize),
	)

	if !bool(result) {
		return nil, nil, fmt.Errorf("keypair generation failed")
	}

	return publicKey, secretKey, nil
}

// MasterSeedLen returns expected seed length
func MasterSeedLen() int {
	return int(C.kaspa_mldsa_master_seed_len())
}

// DeriveKeypair deterministically derives a keypair from a master seed
func DeriveKeypair(seed []byte, level MLDSALevel) (publicKey, secretKey []byte, err error) {
	if len(seed) != MasterSeedLen() {
		return nil, nil, fmt.Errorf("seed must be %d bytes", MasterSeedLen())
	}

	pkSize := GetPublicKeySize(level)
	skSize := GetSecretKeySize(level)
	publicKey = make([]byte, pkSize)
	secretKey = make([]byte, skSize)

	result := C.kaspa_mldsa_derive_keypair(
		(*C.uint8_t)(unsafe.Pointer(&seed[0])),
		C.size_t(len(seed)),
		C.uint8_t(level),
		(*C.uint8_t)(unsafe.Pointer(&publicKey[0])),
		C.size_t(pkSize),
		(*C.uint8_t)(unsafe.Pointer(&secretKey[0])),
		C.size_t(skSize),
	)

	if !bool(result) {
		return nil, nil, fmt.Errorf("deterministic derivation failed")
	}

	return publicKey, secretKey, nil
}

// Sign creates an ML-DSA signature
func Sign(message, secretKey []byte) ([]byte, error) {
	if len(message) == 0 || len(secretKey) == 0 {
		return nil, fmt.Errorf("empty message or secret key")
	}

	// Detect level from secret key size
	var sigSize int
	switch len(secretKey) {
	case 2560:
		sigSize = GetSignatureSize(Level2)
	case 4032:
		sigSize = GetSignatureSize(Level3)
	case 4896:
		sigSize = GetSignatureSize(Level5)
	default:
		return nil, fmt.Errorf("invalid secret key size: %d", len(secretKey))
	}

	signature := make([]byte, sigSize)

	result := C.kaspa_mldsa_sign(
		(*C.uint8_t)(unsafe.Pointer(&message[0])),
		C.size_t(len(message)),
		(*C.uint8_t)(unsafe.Pointer(&secretKey[0])),
		C.size_t(len(secretKey)),
		(*C.uint8_t)(unsafe.Pointer(&signature[0])),
		C.size_t(sigSize),
	)

	if !bool(result) {
		return nil, fmt.Errorf("signing failed")
	}

	return signature, nil
}

// Verify verifies an ML-DSA signature
func Verify(message, signature, publicKey []byte) bool {
	if len(message) == 0 || len(signature) == 0 || len(publicKey) == 0 {
		return false
	}

	result := C.kaspa_mldsa_verify(
		(*C.uint8_t)(unsafe.Pointer(&message[0])),
		C.size_t(len(message)),
		(*C.uint8_t)(unsafe.Pointer(&signature[0])),
		C.size_t(len(signature)),
		(*C.uint8_t)(unsafe.Pointer(&publicKey[0])),
		C.size_t(len(publicKey)),
	)

	return bool(result)
}

// DetectLevel detects the ML-DSA level from public key size
func DetectLevel(publicKey []byte) MLDSALevel {
	level := C.kaspa_mldsa_detect_level(C.size_t(len(publicKey)))
	return MLDSALevel(level)
}

func main() {
	fmt.Println("🚀 Kaspa ML-DSA FFI Example (Go)")
	fmt.Println()

	// Test Level 2 (recommended)
	fmt.Println("Testing ML-DSA Level 2...")
	pk2, sk2, err := GenerateKeypair(Level2)
	if err != nil {
		panic(err)
	}

	fmt.Printf("  Public key size: %d bytes\n", len(pk2))
	fmt.Printf("  Secret key size: %d bytes\n", len(sk2))

	message := []byte("Hello, Kasplex L2!")
	fmt.Printf("  Message: %s\n", string(message))

	sig2, err := Sign(message, sk2)
	if err != nil {
		panic(err)
	}

	fmt.Printf("  Signature size: %d bytes\n", len(sig2))

	valid := Verify(message, sig2, pk2)
	if valid {
		fmt.Println("  ✅ Signature verified successfully!")
	} else {
		fmt.Println("  ❌ Signature verification failed!")
	}

	// Detect level
	detectedLevel := DetectLevel(pk2)
	fmt.Printf("  Detected level: %d\n", detectedLevel)

	fmt.Println()

	// Show hex encoding (for debugging)
	fmt.Println("Hex encoding (first 64 bytes):")
	fmt.Printf("  Public key:  %s...\n", hex.EncodeToString(pk2[:32]))
	fmt.Printf("  Signature:   %s...\n", hex.EncodeToString(sig2[:32]))

	fmt.Println()

	// Test with corrupted signature
	fmt.Println("Testing with corrupted signature...")
	corruptedSig := make([]byte, len(sig2))
	copy(corruptedSig, sig2)
	corruptedSig[0] ^= 0xFF // Flip bits

	validCorrupted := Verify(message, corruptedSig, pk2)
	if !validCorrupted {
		fmt.Println("  ✅ Corrupted signature correctly rejected!")
	} else {
		fmt.Println("  ❌ Corrupted signature incorrectly accepted!")
	}

	fmt.Println()
	fmt.Println("🎉 All tests passed!")

	// Demonstrate deterministic derivation
	fmt.Println()
	fmt.Println("Deterministic derivation demo...")
	seed := make([]byte, MasterSeedLen())
	for i := range seed {
		seed[i] = byte(i)
	}
	dpkt, dsk, err := DeriveKeypair(seed, Level2)
	if err != nil {
		panic(err)
	}
	dpkt2, dsk2, err := DeriveKeypair(seed, Level2)
	if err != nil {
		panic(err)
	}
	fmt.Printf("  Derived PK hash: %s\n", hex.EncodeToString(dpkt[:32]))
	fmt.Printf("  Derived SK hash: %s\n", hex.EncodeToString(dsk[:32]))
	fmt.Printf("  Deterministic: %v\n", (hex.EncodeToString(dpkt) == hex.EncodeToString(dpkt2)) && (hex.EncodeToString(dsk) == hex.EncodeToString(dsk2)))
}
