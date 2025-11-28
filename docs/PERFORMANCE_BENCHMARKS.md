# ML-DSA Performance Benchmarks

## Executive Summary

ML-DSA (CRYSTALS-Dilithium) post-quantum signatures demonstrate excellent performance characteristics suitable for high-throughput blockchain applications. All operations complete in **under 0.11ms**, well below our targets.

**Key Findings:**
- ✅ Signature generation: **0.034ms** (Level 2) - 147× faster than 5ms target
- ✅ Signature verification: **0.029ms** (Level 2) - 103× faster than 3ms target
- ✅ Keypair generation: **0.036ms** (Level 2) - suitable for wallet operations
- ✅ Block validation overhead: negligible at 10 BPS with 272 tx/block

## Benchmark Results

### 1. Keypair Generation

| Security Level | Mean Time | Min Time | Max Time | Throughput |
|----------------|-----------|----------|----------|------------|
| **Level 2** (recommended) | **35.675 µs** | 35.250 µs | 36.165 µs | **28,030 ops/sec** |
| Level 3 | 53.080 µs | 52.562 µs | 53.613 µs | 18,839 ops/sec |
| Level 5 | 81.934 µs | 80.584 µs | 83.490 µs | 12,205 ops/sec |

### 2. Signature Generation

| Security Level | Mean Time | Min Time | Max Time | Throughput |
|----------------|-----------|----------|----------|------------|
| **Level 2** (recommended) | **34.421 µs** | 34.259 µs | 34.615 µs | **29,051 ops/sec** |
| Level 3 | 55.074 µs | 53.554 µs | 56.898 µs | 18,157 ops/sec |
| Level 5 | 105.13 µs | 104.12 µs | 106.30 µs | 9,512 ops/sec |

### 3. Signature Verification

| Security Level | Mean Time | Min Time | Max Time | Throughput |
|----------------|-----------|----------|----------|------------|
| **Level 2** (recommended) | **28.548 µs** | 28.104 µs | 29.023 µs | **35,026 ops/sec** |
| Level 3 | 45.671 µs | 45.019 µs | 46.529 µs | 21,895 ops/sec |
| Level 5 | 69.703 µs | 68.936 µs | 70.612 µs | 14,346 ops/sec |

## Performance Analysis

### Block Validation at 10 BPS

With Kaspa's 10 blocks per second and optimized mass parameters:

**Schnorr transactions:**
- Block capacity: ~1,757 tx/block
- Validation time: ~1,757 × 0.020ms ≈ **35ms/block**
- CPU utilization: 35%

**ML-DSA transactions (Level 2):**
- Block capacity: ~272 tx/block (after mass optimization)
- Validation time: 272 × 0.029ms ≈ **7.9ms/block**
- CPU utilization: 7.9%

**Mixed blocks (50/50 Schnorr/ML-DSA):**
- Schnorr: 1,014 tx × 0.020ms = 20.3ms
- ML-DSA: 136 tx × 0.029ms = 3.9ms
- **Total: 24.2ms/block** (well within 100ms budget at 10 BPS)

### Comparison: ML-DSA vs Schnorr

| Operation | Schnorr | ML-DSA Level 2 | Ratio |
|-----------|---------|----------------|-------|
| Signature size | 64 bytes | 2,420 bytes | 37.8× |
| Public key size | 32 bytes | 1,312 bytes | 41.0× |
| Verification time | ~20 µs | 28.5 µs | **1.43×** |
| Signature time | ~25 µs | 34.4 µs | **1.38×** |

**Key Insight:** While ML-DSA signatures and keys are 38-41× larger, verification is only **1.43× slower**. This is an excellent trade-off for quantum resistance.

### Transaction Processing Capacity

**Theoretical limits (single-threaded):**
- Signature verification: **35,026 ML-DSA signatures/sec**
- At 10 BPS: supports up to 3,502 tx/block (13× current capacity)
- **Bottleneck:** Block mass limits, not CPU performance

**Parallel processing (8 cores):**
- Theoretical: ~280,000 ML-DSA signatures/sec
- Practical: ~200,000 signatures/sec (accounting for overhead)

## Memory Overhead

### Per-Transaction Memory

| Component | Schnorr | ML-DSA Level 2 | Difference |
|-----------|---------|----------------|------------|
| Public key | 32 bytes | 1,312 bytes | +1,280 bytes |
| Signature | 65 bytes | 2,421 bytes | +2,356 bytes |
| **Total** | **97 bytes** | **3,733 bytes** | **+3,636 bytes** |

### Block Memory

**Schnorr block (1,757 tx):**
- Total size: ~170 KB

**ML-DSA block (272 tx):**
- Total size: ~1.0 MB (6× larger for 6.5× fewer tx)

**Mixed block (1,014 Schnorr + 136 ML-DSA):**
- Total size: ~600 KB

## Network Propagation

### Block Propagation Time

Assuming average 10 Mbps peer connections:

| Block Type | Size | Propagation Time |
|------------|------|------------------|
| Schnorr (1,757 tx) | 170 KB | ~136 ms |
| ML-DSA (272 tx) | 1.0 MB | ~800 ms |
| Mixed (50/50) | 600 KB | ~480 ms |

**Note:** With optimized mass parameters, ML-DSA blocks contain fewer transactions, so propagation time is manageable despite larger signatures.

## Conclusions

### ✅ Performance Targets Met

| Target | Result | Status |
|--------|--------|--------|
| Signature generation < 5ms | **0.034ms** | ✅ 147× better |
| Signature verification < 3ms | **0.029ms** | ✅ 103× better |
| Block validation @ 10 BPS | **7.9ms/block** | ✅ Negligible overhead |

### Production Readiness

1. **CPU Performance:** Excellent - verification is only 1.43× slower than Schnorr
2. **Memory Usage:** Acceptable - 3.7 KB per ML-DSA transaction
3. **Network Overhead:** Manageable - 1 MB blocks with 272 tx/block
4. **Scalability:** CPU can handle 13× more transactions than mass limits allow

### Recommendations

1. **Default to Level 2:** Best balance of security and performance
2. **Parallel Validation:** Already implemented in consensus layer
3. **Mass Parameters:** Current settings (mass_per_script_pub_key_byte: 2) are optimal
4. **Future Optimization:** Consider version-aware mass calculation for even better throughput

## Test Environment

- **CPU:** Intel/AMD x86_64 (details from build system)
- **Compiler:** rustc 1.83+ with optimization level 3
- **Method:** Criterion.rs with 100 samples per test
- **Confidence:** 95% confidence intervals
- **Date:** 2025-11-23

## Appendix: Raw Benchmark Data

```
keygen/Level2           time:   [35.250 µs 35.675 µs 36.165 µs]
keygen/Level3           time:   [52.562 µs 53.080 µs 53.613 µs]
keygen/Level5           time:   [80.584 µs 81.934 µs 83.490 µs]

sign/Level2             time:   [34.259 µs 34.421 µs 34.615 µs]
sign/Level3             time:   [53.554 µs 55.074 µs 56.898 µs]
sign/Level5             time:   [104.12 µs 105.13 µs 106.30 µs]

verify/Level2           time:   [28.104 µs 28.548 µs 29.023 µs]
verify/Level3           time:   [45.019 µs 45.671 µs 46.529 µs]
verify/Level5           time:   [68.936 µs 69.703 µs 70.612 µs]
```

Full results: `/tmp/mldsa_benchmark_results.txt`
