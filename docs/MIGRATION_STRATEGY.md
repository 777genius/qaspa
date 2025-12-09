# QUBIC Address Migration Strategy

## Executive Summary

QUBIC will support **all three signature types in parallel** to ensure smooth migration:
- **PubKey (Schnorr)** - Legacy, quantum-vulnerable
- **PubKeyECDSA** - Legacy, quantum-vulnerable
- **PubKeyMLDSA** - Post-quantum secure ✅

## Technical Implementation

### 1. All Opcodes Remain Active

```rust
// crypto/txscript/src/opcodes/mod.rs

opcode OpCheckSig<0xac, 1>(self, vm) {
    // Schnorr signature verification
    // Status: ACTIVE (for backward compatibility)
}

opcode OpCheckSigECDSA<0xab, 1>(self, vm) {
    // ECDSA signature verification
    // Status: ACTIVE (for backward compatibility)
}

opcode OpCheckSigMLDSA<0xa7, 1>(self, vm) {
    // ML-DSA signature verification
    // Status: ACTIVE (recommended for new addresses)
}
```

### 2. Mass Incentivization

Adjust mass parameters to make ML-DSA transactions economically attractive:

```rust
// consensus/core/src/config/params.rs

pub const QUBIC_PARAMS: Params = Params {
    // Base parameters
    mass_per_tx_byte: 1,

    // REDUCED for ML-DSA to offset larger signature size
    mass_per_script_pub_key_byte: 2,  // Was: 10
    mass_per_sig_op: 800,              // Was: 1000

    // Increased to fit more ML-DSA transactions per block
    max_block_mass: 5_000_000,         // Was: 500_000

    // ...
};
```

**Economic result:**
- Schnorr tx: ~1000 mass → higher fee
- ML-DSA tx: ~1200 mass → similar fee (due to reduced coefficients)

### 3. Wallet UI Recommendations

```rust
// wallet/core/src/address.rs

pub struct AddressRecommendation {
    pub version: Version,
    pub security_level: SecurityLevel,
    pub is_default: bool,
}

pub enum SecurityLevel {
    Legacy,          // Schnorr/ECDSA - quantum vulnerable
    PostQuantum,     // ML-DSA - quantum secure
}

impl AddressRecommendation {
    pub fn get_default() -> Self {
        // Recommend ML-DSA by default
        AddressRecommendation {
            version: Version::PubKeyMLDSA,
            security_level: SecurityLevel::PostQuantum,
            is_default: true,
        }
    }

    pub fn display_warning(&self) -> Option<&str> {
        match self.security_level {
            SecurityLevel::Legacy => Some(
                "⚠️ This address type is vulnerable to quantum computers. \
                 Consider upgrading to ML-DSA for better security."
            ),
            SecurityLevel::PostQuantum => None,
        }
    }
}
```

### 4. Migration Tools

```rust
// wallet/core/src/migration.rs

/// Creates a transaction to move funds from legacy to ML-DSA address
pub fn create_migration_tx(
    old_address: &Address,  // Schnorr/ECDSA
    new_mldsa_key: &MlDsaKeypair,
) -> Result<Transaction> {
    // 1. Find all UTXOs for old_address
    let utxos = find_utxos(old_address)?;

    // 2. Create new ML-DSA address
    let new_address = Address::new(
        old_address.prefix,
        Version::PubKeyMLDSA,
        new_mldsa_key.public_key.as_bytes(),
    );

    // 3. Create transaction spending all UTXOs to new address
    let tx = Transaction {
        inputs: utxos.into_iter().map(|utxo| TransactionInput {
            previous_outpoint: utxo.outpoint,
            signature_script: vec![],  // Will be signed
            sequence: 0,
            sig_op_count: 1,
        }).collect(),
        outputs: vec![TransactionOutput {
            value: total_value - fee,
            script_pubkey: pay_to_address_script(&new_address),
        }],
        // ...
    };

    // 4. Sign with old key (Schnorr/ECDSA)
    sign_transaction(&tx, old_private_key)?;

    Ok(tx)
}
```

## Migration Timeline

### Phase 0: Pre-Launch (Now)
- ✅ Implement all three signature types
- ✅ Set up mass parameters
- ⏳ Build migration tools
- ⏳ Create educational materials

### Phase 1: Mainnet Launch (Week 24)
- Launch with all 3 types supported
- Default to ML-DSA for new wallets
- Show warnings for legacy addresses
- **Target:** 20% ML-DSA adoption

### Phase 2: Economic Incentives (Months 1-6)
- Monitor migration rate
- Adjust mass parameters if needed
- Community education campaigns
- **Target:** 60% ML-DSA adoption

### Phase 3: Soft Deprecation (Year 1, if needed)
- Announce timeline for legacy deprecation
- Intensify migration campaigns
- **Target:** 90% ML-DSA adoption

### Phase 4: Hard Fork (Year 2-3, optional)
- Only if quantum threat becomes imminent
- Disable OpCheckSig and OpCheckSigECDSA
- Give 6-month warning period
- **Target:** 99% ML-DSA adoption

## Metrics to Track

```rust
// consensus/core/src/metrics.rs

pub struct SignatureTypeMetrics {
    pub schnorr_count: u64,
    pub ecdsa_count: u64,
    pub mldsa_count: u64,
    pub total_count: u64,
}

impl SignatureTypeMetrics {
    pub fn mldsa_percentage(&self) -> f64 {
        (self.mldsa_count as f64 / self.total_count as f64) * 100.0
    }

    pub fn is_migration_complete(&self) -> bool {
        self.mldsa_percentage() > 95.0
    }
}
```

## Risk Assessment

### Low Risk: Parallel Support ✅ (Recommended)
- **Pros:**
  - No one loses funds
  - Smooth migration
  - User choice
- **Cons:**
  - Larger codebase
  - More testing needed
  - Quantum vulnerability persists for legacy users

### High Risk: ML-DSA Only ❌ (Not Recommended)
- **Pros:**
  - Simpler code
  - 100% quantum secure
- **Cons:**
  - Hard fork from Kaspa
  - All old wallets incompatible
  - High barrier to entry
  - Potential legal issues (user funds locked)

## Conclusion

**Recommendation:** Implement **parallel support** for all signature types.

This approach:
1. ✅ Maintains backward compatibility
2. ✅ Allows gradual migration
3. ✅ Provides economic incentives
4. ✅ Preserves user freedom
5. ✅ Minimizes legal risk

The quantum threat is not immediate, so we have time for a careful, user-friendly migration.
