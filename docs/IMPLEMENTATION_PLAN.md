# QUBIC Implementation Plan
## Quantum-Resistant BlockDAG with ML-DSA

**Version:** 1.0
**Date:** 2025-11-23
**Status:** In Development
**Target Launch:** Q4 2025

---

## Executive Summary

This document outlines the implementation plan for QUBIC (Quantum-resistant Blockchain), a fork of rusty-kaspa with ML-DSA (CRYSTALS-Dilithium) post-quantum signatures. The architecture is designed for extensibility to support future privacy layers (Confidential Transactions, Ring Signatures).

**Core Principles:**
- Security First: Post-quantum cryptography from day one
- Extensible Architecture: Built for Layer 0 → Layer 1 → Layer 2 evolution
- Performance: Maintain high throughput (~1000+ tx/sec @ 10 BPS)
- Compatibility: Leverage proven Kaspa BlockDAG consensus

---

## Phase 1: Foundation (Weeks 1-3)

### 1.1 Project Setup & Dependencies

**Objective:** Establish clean development environment with proper tooling

**Tasks:**
- [x] Fork rusty-kaspa → qubic-blockchain
- [ ] Update Cargo.toml workspace dependencies
- [ ] Add pqcrypto-dilithium crate
- [ ] Set up feature flags for extensibility
- [ ] Configure CI/CD pipeline
- [ ] Set up development documentation

**Files to modify:**
```
Cargo.toml
.github/workflows/ci.yml
README.md → QUBIC_README.md
```

**Dependencies to add:**
```toml
pqcrypto-dilithium = "0.5"
pqcrypto-traits = "0.3"
```

### 1.2 Crypto Module Foundation

**Objective:** Create isolated, well-tested ML-DSA crypto module

**New files:**
```
crypto/mldsa/
├── Cargo.toml
├── src/
│   ├── lib.rs           # Public API
│   ├── keypair.rs       # Key generation
│   ├── sign.rs          # Signing
│   ├── verify.rs        # Verification
│   └── params.rs        # ML-DSA parameters (2,3,5)
├── tests/
│   ├── integration.rs
│   └── vectors.rs       # NIST test vectors
└── benches/
    └── bench.rs
```

**API Design:**
```rust
pub enum MlDsaLevel {
    Level2,  // dilithium2 (1312-byte pk, 2420-byte sig)
    Level3,  // dilithium3 (1952-byte pk, 3293-byte sig)
    Level5,  // dilithium5 (2592-byte pk, 4595-byte sig)
}

pub struct MlDsaKeypair {
    pub public_key: PublicKey,
    pub secret_key: SecretKey,
}

pub fn generate_keypair(level: MlDsaLevel) -> MlDsaKeypair;
pub fn sign(message: &[u8], sk: &SecretKey) -> Signature;
pub fn verify(message: &[u8], sig: &Signature, pk: &PublicKey) -> bool;
```

**Test Coverage Required:** >90%

### 1.3 Transaction Versioning System

**Objective:** Design extensible transaction format

**Files to modify:**
```
consensus/core/src/tx.rs
```

**New structures:**
```rust
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub enum TransactionVersion {
    /// ML-DSA transparent transactions (Layer 0)
    V0 = 0,

    /// Reserved: Confidential Transactions (Layer 1)
    V1 = 1,

    /// Reserved: Ring Signatures + CT (Layer 2)
    V2 = 2,
}

pub struct Transaction {
    pub version: u16,
    pub inputs: Vec<TransactionInput>,
    pub outputs: Vec<TransactionOutput>,
    pub lock_time: u64,
    pub subnetwork_id: SubnetworkId,
    pub gas: u64,
    pub payload: Vec<u8>,
    // Cached/computed fields
    mass: TransactionMass,
}

// Input/Output remain compatible but versioned
pub struct TransactionInput {
    pub previous_outpoint: TransactionOutpoint,
    pub signature_script: Vec<u8>,  // ML-DSA sig for V0
    pub sequence: u64,
    pub sig_op_count: u8,
}
```

**Backward Compatibility:**
- V0 transactions are the ONLY valid type initially
- Structure allows future V1/V2 without breaking changes
- Version field checked in all validation paths

---

## Phase 2: Core Implementation (Weeks 4-9)

### 2.1 Address System (V3 - PubKeyMLDSA)

**Objective:** Add new address type for ML-DSA public keys

**Files to modify:**
```
crypto/addresses/src/lib.rs
```

**Changes:**
```rust
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Version {
    PubKey = 0,        // Schnorr (legacy)
    PubKeyECDSA = 1,   // ECDSA (legacy)
    ScriptHash = 2,    // P2SH
    PubKeyMLDSA = 3,   // ML-DSA (NEW)
}

impl Version {
    pub fn public_key_len(&self) -> usize {
        match self {
            Version::PubKey => 32,
            Version::PubKeyECDSA => 33,
            Version::ScriptHash => 32,
            Version::PubKeyMLDSA => 1312,  // dilithium2
        }
    }
}
```

**Bech32m Encoding:**
- Use Bech32m (not Bech32) for new addresses
- Prefix: `qubic:` (mainnet) / `qubictest:` (testnet)
- Format: `qubic:qm1<1312-byte-pubkey-encoded>`

### 2.2 Script System (OpCheckSigMLDSA)

**Objective:** Add ML-DSA signature verification opcode

**Files to modify:**
```
crypto/txscript/src/opcodes/mod.rs
crypto/txscript/src/lib.rs
```

**New opcode:**
```rust
opcode OpCheckSigMLDSA<0xb5, 1>(self, vm) {
    let [mut sig, key] = vm.dstack.pop_raw()?;

    // Pop sighash type
    match sig.pop() {
        Some(typ) => {
            let hash_type = SigHashType::from_u8(typ)
                .map_err(|_| TxScriptError::InvalidSigHashType(typ))?;

            match vm.check_mldsa_signature(hash_type, key.as_slice(), sig.as_slice()) {
                Ok(valid) => {
                    vm.dstack.push_item(valid)?;
                    Ok(())
                }
                Err(e) => Err(e)
            }
        }
        None => {
            vm.dstack.push_item(false)?;
            Ok(())
        }
    }
}
```

**Signature verification:**
```rust
impl<T: VerifiableTransaction, Reused: SigHashReusedValues> TxScriptEngine<T, Reused> {
    fn check_mldsa_signature(
        &mut self,
        hash_type: SigHashType,
        key: &[u8],
        sig: &[u8]
    ) -> Result<bool, TxScriptError> {
        self.runtime_sig_op_counter.consume_sig_op()?;

        match self.script_source {
            ScriptSource::TxInput { tx, idx, .. } => {
                // Validate signature length (dilithium2 = 2420 bytes)
                if sig.len() != 2420 {
                    return Err(TxScriptError::SigLength(sig.len()));
                }

                // Validate public key length
                Self::check_mldsa_pub_key_encoding(key)?;

                // Parse public key
                let pk = mldsa::PublicKey::from_bytes(key)
                    .map_err(TxScriptError::InvalidPublicKey)?;

                // Parse signature
                let signature = mldsa::Signature::from_bytes(sig)
                    .map_err(TxScriptError::InvalidSignature)?;

                // Calculate sighash
                let sig_hash = calc_mldsa_signature_hash(tx, idx, hash_type, self.reused_values);

                // Create cache key
                let sig_cache_key = SigCacheKey {
                    signature: Signature::MlDsa(signature),
                    pub_key: PublicKey::MlDsa(pk),
                    message: sig_hash,
                };

                // Check cache first
                match self.sig_cache.get(&sig_cache_key) {
                    Some(valid) => Ok(valid),
                    None => {
                        // Verify signature
                        let valid = mldsa::verify(&sig_hash.as_bytes(), &signature, &pk);

                        // Cache result
                        self.sig_cache.insert(sig_cache_key, valid);

                        Ok(valid)
                    }
                }
            }
            _ => Err(TxScriptError::NotATransactionInput),
        }
    }

    fn check_mldsa_pub_key_encoding(key: &[u8]) -> Result<(), TxScriptError> {
        // dilithium2 public key is exactly 1312 bytes
        if key.len() != 1312 {
            return Err(TxScriptError::PubKeyLength(key.len()));
        }
        Ok(())
    }
}
```

### 2.3 Standard Scripts

**Files to modify:**
```
crypto/txscript/src/standard.rs
```

**New functions:**
```rust
/// Creates a pay-to-pubkey script for ML-DSA
fn pay_to_pub_key_mldsa(address_payload: &[u8]) -> ScriptVec {
    assert_eq!(address_payload.len(), 1312);

    // OpPushData + 1312-byte pubkey + OpCheckSigMLDSA
    let mut script = SmallVec::new();
    script.push(opcodes::codes::OpPushData2);
    script.extend_from_slice(&(1312u16).to_le_bytes());
    script.extend_from_slice(address_payload);
    script.push(opcodes::codes::OpCheckSigMLDSA);

    script
}

pub fn pay_to_address_script(address: &Address) -> ScriptPublicKey {
    let script = match address.version {
        Version::PubKey => pay_to_pub_key(address.payload.as_slice()),
        Version::PubKeyECDSA => pay_to_pub_key_ecdsa(address.payload.as_slice()),
        Version::ScriptHash => pay_to_script_hash(address.payload.as_slice()),
        Version::PubKeyMLDSA => pay_to_pub_key_mldsa(address.payload.as_slice()),
    };
    ScriptPublicKey::new(ScriptClass::from(address.version).version(), script)
}
```

### 2.4 Mass Calculation

**Objective:** Adjust mass parameters for larger ML-DSA transactions

**Files to modify:**
```
consensus/core/src/config/params.rs
consensus/core/src/mass/mod.rs
wallet/core/src/tx/mass.rs
```

**New parameters (EXPERIMENTAL - need tuning):**
```rust
pub const QUBIC_PARAMS: Params = Params {
    // ... other params same as Kaspa

    mass_per_tx_byte: 1,
    mass_per_script_pub_key_byte: 2,  // Reduced from 10!
    mass_per_sig_op: 800,              // Reduced from 1000
    max_block_mass: 5_000_000,         // Increased from 500_000 (10x)

    // ...
};
```

**Rationale:**
- `mass_per_script_pub_key_byte` reduced because ML-DSA pubkeys are large
- `max_block_mass` increased to maintain reasonable tx/block count
- Will be tuned based on testnet data

### 2.5 Wallet Integration

**Objective:** Support ML-DSA key generation and signing in wallet

**Files to modify:**
```
wallet/keys/src/
wallet/core/src/
```

**New modules:**
```
wallet/keys/src/mldsa.rs
wallet/keys/src/derivation_mldsa.rs
```

**Key derivation:**
```rust
// BIP32-style derivation for ML-DSA (adapted)
pub struct MlDsaExtendedKey {
    pub key: MlDsaKeypair,
    pub chain_code: [u8; 32],
    pub depth: u8,
    pub parent_fingerprint: [u8; 4],
    pub child_index: u32,
}

impl MlDsaExtendedKey {
    pub fn derive_child(&self, index: u32) -> Result<Self>;
    pub fn derive_path(&self, path: &DerivationPath) -> Result<Self>;
}
```

---

## Phase 3: Testing & Validation (Weeks 10-17)

### 3.1 Unit Tests

**Coverage Target:** >85% for all new code

**Test files:**
```
crypto/mldsa/tests/
crypto/txscript/tests/ (extended)
consensus/core/src/mass/tests.rs
wallet/keys/tests/
```

**Critical test cases:**
- [ ] ML-DSA keypair generation (100 iterations)
- [ ] Signature generation and verification
- [ ] Invalid signature rejection
- [ ] Malformed public key rejection
- [ ] Transaction serialization/deserialization
- [ ] Mass calculation edge cases
- [ ] Script execution (OpCheckSigMLDSA)
- [ ] Address encoding/decoding
- [ ] Wallet key derivation

### 3.2 Integration Tests

**Files:**
```
testing/integration/src/mldsa_integration_tests.rs
```

**Scenarios:**
- [ ] Full transaction lifecycle (create → sign → verify → mine)
- [ ] Block validation with ML-DSA transactions
- [ ] Mempool acceptance
- [ ] UTXO spending
- [ ] Multi-input transactions
- [ ] Mixed legacy (if kept) and ML-DSA transactions

### 3.3 Performance Benchmarks

**Files:**
```
crypto/mldsa/benches/bench.rs
consensus/benches/check_scripts.rs
```

**Metrics to measure:**
- Signature generation time (target: <5ms)
- Signature verification time (target: <3ms)
- Transaction validation time
- Block processing time @ 10 BPS
- Memory usage

### 3.4 Testnet Deployment

**Infrastructure:**
- 5+ seed nodes (geo-distributed)
- Block explorer (fork kaspa-explorer)
- Public RPC endpoints
- Faucet service

**Testnet Parameters:**
```rust
pub const TESTNET_PARAMS: Params = Params {
    dns_seeders: &[
        "seed1-testnet.qubic.network",
        "seed2-testnet.qubic.network",
    ],
    net: NetworkId::with_suffix(NetworkType::Testnet, 1),
    // ... same as mainnet but testnet network ID
};
```

**Testing Period:** Minimum 3 months before mainnet

---

## Phase 4: Security & Audit (Weeks 18-23)

### 4.1 Internal Security Review

**Checklist:**
- [ ] Crypto library usage audit (pqcrypto-dilithium)
- [ ] Consensus logic review
- [ ] Memory safety (no unsafe blocks without justification)
- [ ] Integer overflow checks
- [ ] Error handling (no panics in production paths)
- [ ] Input validation (all user inputs)

### 4.2 External Security Audit

**Recommended Firms:**
- Trail of Bits
- NCC Group
- Kudelski Security

**Budget:** $40,000-60,000

**Scope:**
- ML-DSA integration
- Consensus modifications
- Transaction validation
- Wallet key management
- Network protocol changes

### 4.3 Bug Bounty Program

**Launch:** During testnet phase

**Tiers:**
- Critical (consensus break): $10,000
- High (security issue): $5,000
- Medium (DOS vector): $1,000
- Low (minor bug): $250

**Platform:** HackerOne or ImmuneFi

---

## Phase 5: Mainnet Launch (Week 24)

### 5.1 Pre-Launch Checklist

- [ ] All tests passing (>85% coverage)
- [ ] External audit complete + fixes applied
- [ ] Testnet stable for 3+ months
- [ ] Documentation complete
- [ ] Block explorer ready
- [ ] Wallets ready (CLI + web)
- [ ] Mining pools committed (3+)
- [ ] Legal review complete
- [ ] Marketing materials ready

### 5.2 Genesis Block

**Parameters:**
```rust
pub const MAINNET_GENESIS: GenesisBlock = GenesisBlock {
    hash: Hash::from_bytes([/* computed hash */]),
    timestamp: 1735689600000, // 2025-12-31 00:00:00 UTC (example)
    bits: 0x1e7fffff, // Initial difficulty
    // ...
};
```

### 5.3 Launch Coordination

**T-24 hours:**
- Final code freeze
- Deploy seed nodes
- Notify mining pools

**T-0 (Genesis):**
- Start seed nodes
- Monitor network health
- 24/7 team availability

**T+7 days:**
- Network stability check
- Exchange listings begin
- Community AMA

---

## Architecture: Extensibility for Layer 1 & Layer 2

### Modular Validation System

**Design:**
```rust
// consensus/core/src/tx/validation.rs

pub trait TransactionValidator: Send + Sync {
    fn validate(&self, tx: &Transaction) -> Result<(), ValidationError>;
    fn calculate_mass(&self, tx: &Transaction) -> u64;
    fn verify_signatures(&self, tx: &Transaction) -> Result<bool, ValidationError>;
}

// Layer 0 - Transparent ML-DSA
pub struct TransparentValidator {
    mldsa_verifier: Arc<MlDsaVerifier>,
    mass_calculator: MassCalculator,
}

impl TransactionValidator for TransparentValidator {
    fn validate(&self, tx: &Transaction) -> Result<(), ValidationError> {
        match tx.version {
            0 => {
                // V0 validation logic
                self.validate_inputs(tx)?;
                self.validate_outputs(tx)?;
                self.verify_signatures(tx)?;
                Ok(())
            }
            _ => Err(ValidationError::UnsupportedVersion(tx.version))
        }
    }

    // ...
}

// Future: Layer 1 - Confidential Transactions
#[cfg(feature = "layer-1")]
pub struct ConfidentialValidator {
    transparent_validator: TransparentValidator,
    ct_verifier: ConfidentialTxVerifier,
}

// Future: Layer 2 - Ring Signatures
#[cfg(feature = "layer-2")]
pub struct RingSignatureValidator {
    confidential_validator: ConfidentialValidator,
    ring_verifier: RingSignatureVerifier,
}

// Factory
pub fn get_validator(version: u16, params: &ConsensusParams) -> Box<dyn TransactionValidator> {
    match version {
        0 => Box::new(TransparentValidator::new(params)),

        #[cfg(feature = "layer-1")]
        1 if params.confidential_tx_activation.is_some() => {
            Box::new(ConfidentialValidator::new(params))
        }

        #[cfg(feature = "layer-2")]
        2 if params.ring_sig_activation.is_some() => {
            Box::new(RingSignatureValidator::new(params))
        }

        _ => Box::new(UnsupportedVersionValidator),
    }
}
```

### Soft Fork Activation

**Parameters for future upgrades:**
```rust
pub struct ConsensusParams {
    // ... existing params

    /// DAA score at which V1 (Confidential TX) activates
    pub confidential_tx_activation: Option<u64>,

    /// DAA score at which V2 (Ring Signatures) activates
    pub ring_sig_activation: Option<u64>,
}

// In validation code:
fn is_version_active(version: u16, daa_score: u64, params: &ConsensusParams) -> bool {
    match version {
        0 => true, // Always active
        1 => params.confidential_tx_activation
            .map_or(false, |activation| daa_score >= activation),
        2 => params.ring_sig_activation
            .map_or(false, |activation| daa_score >= activation),
        _ => false,
    }
}
```

### Feature Flags

**Cargo.toml:**
```toml
[features]
default = ["layer-0"]

# Layer 0: ML-DSA Transparent (always enabled)
layer-0 = []

# Layer 1: Confidential Transactions (future)
layer-1 = [
    "layer-0",
    "bulletproofs",
    "curve25519-dalek",
]

# Layer 2: Ring Signatures (future)
layer-2 = [
    "layer-1",
    "lattice-crypto",
    "ring-signatures",
]

# All layers (development)
all-layers = ["layer-0", "layer-1", "layer-2"]
```

---

## Development Best Practices

### Code Style

**Follow Rust conventions:**
- `cargo fmt` before every commit
- `cargo clippy` with no warnings
- Documentation for all public APIs
- Examples for complex functions

### Git Workflow

**Branch Strategy:**
```
main              ← production-ready code
├── develop       ← integration branch
    ├── feature/mldsa-crypto
    ├── feature/opcodes
    ├── feature/addresses
    └── feature/wallet
```

**Commit Messages:**
```
type(scope): subject

[optional body]

[optional footer]
```

Types: feat, fix, docs, test, refactor, perf, chore

Example:
```
feat(crypto): add ML-DSA keypair generation

Implement dilithium2 keypair generation using pqcrypto-dilithium.
Includes comprehensive tests and benchmarks.

Closes #123
```

### Code Review

**Requirements:**
- All PRs require 1+ approval
- All tests must pass
- No clippy warnings
- Coverage must not decrease

### Performance Monitoring

**Metrics to track:**
- Signature verification time (p50, p95, p99)
- Block processing time
- Memory usage (UTXO set size)
- Network bandwidth

**Tools:**
- `cargo bench` for benchmarks
- `valgrind` for memory profiling
- `flamegraph` for CPU profiling

---

## Risk Mitigation

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Consensus bug | Critical | Medium | Extensive testing, external audit |
| Crypto library bug | Critical | Low | Use NIST standard library, audit |
| Performance degradation | High | Medium | Benchmark continuously, optimize |
| Wrong mass parameters | Medium | High | Long testnet, data-driven tuning |
| Incompatible with future layers | Medium | Low | Careful architectural design |

### Operational Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Low hashrate at launch | High | Medium | Pre-committed mining pools |
| Exchange listing delays | Medium | Medium | Start discussions early |
| Legal challenges | High | Low | Legal review, different branding |
| Community split | Medium | Medium | Clear communication, transparency |

---

## Success Metrics

### Technical KPIs

**Testnet (3 months):**
- Uptime: >99%
- Block time: 0.1s average (10 BPS)
- Transaction throughput: >1000 tx/sec
- Memory usage: <32 GB for full node
- Zero consensus bugs

**Mainnet (6 months):**
- Uptime: >99.9%
- Hashrate: >10 PH/s
- Active addresses: >1,000
- Daily transactions: >10,000
- Zero critical bugs

### Business KPIs

**Month 1:**
- Market cap: >$1M
- Exchange listings: 1+ (DEX minimum)
- Community size: >500 Discord members

**Month 6:**
- Market cap: >$10M
- Exchange listings: 2+ (including CEX)
- Community size: >5,000
- Developer activity: 10+ contributors

---

## Timeline Summary

```
Week 1-3:   Foundation & PoC
Week 4-9:   Core Implementation
Week 10-17: Testing & Testnet
Week 18-23: Security & Audit
Week 24:    Mainnet Launch 🚀

Total: ~6 months
```

---

## Next Steps (Immediate)

1. ✅ Review and approve this plan
2. ✅ Set up development environment
3. ✅ Create first PR: Add pqcrypto-dilithium dependency
4. ✅ Implement crypto/mldsa module
5. ✅ Write comprehensive tests
6. ✅ Begin transaction versioning

---

## Appendix

### A. References

- [NIST FIPS 204: ML-DSA](https://csrc.nist.gov/pubs/fips/204/final)
- [Kaspa BlockDAG](https://kaspa.org/)
- [pqcrypto-dilithium](https://crates.io/crates/pqcrypto-dilithium)

### B. Contact

- Technical Lead: [TBD]
- Security Contact: security@qubic.network
- Community: discord.gg/qubic

---

**Document Version:** 1.0
**Last Updated:** 2025-11-23
**Next Review:** Weekly during development
