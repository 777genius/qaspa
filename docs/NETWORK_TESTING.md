# Network E2E Testing Guide

## Overview

This guide covers the network-level end-to-end tests for QUBIC ML-DSA implementation. These tests spawn multiple nodes and verify network behavior, block propagation, and transaction handling.

### Observability (Iteration 10)
- Метрики кошелька `wallet_master_*` экспортируются через `Events::Metrics`; экспортер должен маппить `network`/`instance` и строить графики `rate(sign_ops_total)`, `rate(rotations_total)`, `delegations_{issued,revoked,expiring_soon}`, `delegation_responses_failed_total`, `healthcheck_failures_total`.
- Алерты: рост `delegations_expiring_soon_total` без компенсирующих `issued/revoked` в окне, доля `delegation_responses_failed_total` >5% за 15m, любой рост `healthcheck_failures_total` на mainnet.
- Логи: поиск по `master_anchor=<hex8>` для корреляции метрик с конкретным мастером/делегацией.
- Статус: блок наблюдаемости Iteration 10 сейчас в отладке (не выкатываем); включение master-метрик и алертов делаем по готовности после фичефлага TLV/notify.

## Available Tests

### 1. Bash Script Test (`tests/network_e2e.sh`)

**Purpose:** Quick network test using bash orchestration

**What it does:**
- ✅ Starts with 2 nodes
- ✅ Scales to 5 nodes
- ✅ Verifies P2P connectivity
- ✅ Monitors network health
- ✅ Checks for errors in logs

**Run:**
```bash
# Simple run
./tests/network_e2e.sh

# With debug output
bash -x ./tests/network_e2e.sh
```

**Duration:** ~30 seconds

**Output:**
```
🚀 QUBIC ML-DSA Network E2E Test

📍 Phase 1: Starting with 2 nodes
Starting seed node (Node 1)...
  PID: 12345
Waiting for node on port 16210 ✓
Starting peer node (Node 2)...
  PID: 12346
Waiting for node on port 16310 ✓

Verifying node connections...
  Node 1 peers: 1
  Node 2 peers: 1
  ✓ Nodes are connected!

📍 Phase 2: Scaling to 5 nodes
...

🎉 NETWORK E2E TEST PASSED!
```

---

### 2. Rust Integration Tests (`tests/network_integration.rs`)

**Purpose:** Programmatic network testing with full control

**Available tests:**
- `test_network_scaling` - Start with 2, scale to 5 nodes
- `test_network_block_propagation` - Test block propagation
- `test_network_partition_recovery` - Test node restart/recovery

**Run:**
```bash
# All network tests
cargo test --test network_integration --release -- --ignored --nocapture

# Specific test
cargo test --test network_integration --release test_network_scaling -- --ignored --nocapture
```

**Duration:** ~60 seconds per test

**Output:**
```
🚀 Network Integration Test: Scaling

📍 Phase 1: Starting with 2 nodes

  Starting node 1...
    Waiting for node 1 to be ready ✓
  Starting node 2...
    Waiting for node 2 to be ready ✓

  Waiting for initial connection...

  Verifying network connectivity:
    Node 1: 1 peers ✓
    Node 2: 1 peers ✓

📍 Phase 2: Scaling to 5 nodes
...

🎉 Network scaling test PASSED!
  ✓ Started with 2 nodes
  ✓ Scaled to 5 nodes
  ✓ All nodes connected
  ✓ Network stable for 10s
```

---

### 3. ML-DSA Transactions E2E (`tests/mldsa_transactions_e2e.rs`)

**Purpose:** Real ML-DSA transaction creation, submission, and mining

**Available tests:**
- `test_mldsa_transaction_creation_and_mining` - Full ML-DSA transaction lifecycle
- `test_mldsa_transaction_propagation` - Transaction propagation across 3 nodes
- `test_mixed_schnorr_mldsa_block` - Mixed signature types (planned)

**Run:**
```bash
# All ML-DSA transaction tests
cargo test --test mldsa_transactions_e2e --release -- --ignored --nocapture

# Specific test
cargo test --test mldsa_transactions_e2e --release test_mldsa_transaction_creation_and_mining -- --ignored --nocapture
```

**Duration:** ~120 seconds per test (includes mining for coinbase maturity)

**Output:**
```
🚀 E2E Test: ML-DSA Transaction Creation and Mining

📍 Phase 1: Starting network

  Starting node 1...
    Waiting for node 1 to be ready ✓
  Starting node 2...
    Waiting for node 2 to be ready ✓

  Waiting for network connectivity...
  ✓ All nodes connected

📍 Phase 2: Creating ML-DSA wallet

  ✓ Created ML-DSA wallet
    Address: kaspadev:qz<1312-byte-address>
    Public key size: 1312 bytes

📍 Phase 3: Funding ML-DSA address

  Mining 10 blocks to ML-DSA address...
  ✓ Mined 10 blocks

  Mining additional 100 blocks for coinbase maturity...

📍 Phase 4: Checking UTXOs

  ✓ Found 110 UTXOs
    Total balance: 1100000000000 sompi

📍 Phase 5: Creating recipient wallet

  ✓ Created recipient wallet
    Address: kaspadev:qz<another-address>

📍 Phase 6: Creating ML-DSA transaction

  Creating transaction:
    From: kaspadev:qz...
    To: kaspadev:qz...
    Amount: 1000000000 sompi
    Fee: 1000 sompi
  ✓ Transaction created
    Size: 3847 bytes

📍 Phase 7: Submitting transaction to network

  ✓ Transaction submitted
    TX ID: abc123...

  Checking transaction propagation to node 2...
  ✓ Transaction propagated to node 2

📍 Phase 8: Mining block with ML-DSA transaction

  ✓ Mined block: def456...

📍 Phase 9: Verifying recipient balance

  Recipient UTXOs: 1
  Recipient balance: 1000000000 sompi

🎉 ML-DSA Transaction E2E Test PASSED!

Summary:
  ✓ Created ML-DSA wallets
  ✓ Funded ML-DSA address via mining
  ✓ Created ML-DSA signed transaction
  ✓ Submitted to network
  ✓ Transaction mined in block
  ✓ Recipient received funds
  ✓ Multi-node network functioning
```

**What this test does:**
1. Spawns 2 kaspad nodes
2. Generates ML-DSA Level 2 keypair
3. Creates ML-DSA address
4. Mines blocks to fund the address
5. Waits for coinbase maturity (100 blocks)
6. Creates a second ML-DSA wallet (recipient)
7. Creates a real ML-DSA transaction
8. Signs with ML-DSA (2420-byte signature)
9. Submits to network via RPC
10. Verifies propagation to all nodes
11. Mines a block containing the transaction
12. Verifies recipient received the funds

**Requirements:**
- `kaspad` built with: `cargo build --release -p kaspad`
- Ports 17210-17410 must be free
- ~2 minutes runtime

---

## Test Scenarios

### Scenario 1: Basic Network Formation

**Test:** `./tests/network_e2e.sh` or `test_network_scaling`

**Steps:**
1. Start seed node
2. Start peer node
3. Verify P2P connection
4. Add 3 more nodes
5. Verify full mesh

**Success criteria:**
- All nodes connect to seed
- All nodes stay alive for 10s
- No errors in logs

---

### Scenario 2: Block Propagation

**Test:** `test_network_block_propagation`

**Steps:**
1. Set up 3-node network
2. Mine block on node 1 (future: with ML-DSA)
3. Wait for propagation
4. Verify all nodes see block

**Success criteria:**
- Block propagates to all nodes
- All nodes reach same height
- Propagation time < 5s

---

### Scenario 3: Network Resilience

**Test:** `test_network_partition_recovery`

**Steps:**
1. Set up 4-node network
2. Kill node 2
3. Verify remaining nodes continue
4. Restart node 2
5. Verify it rejoins network

**Success criteria:**
- Network continues without node 2
- Node 2 successfully rejoins
- All nodes reconnect

---

## Configuration

### Environment Variables

```bash
# Custom kaspad binary
export KASPAD_BIN=/path/to/kaspad

# Custom test directory
export TEST_DIR=/custom/test/dir

# Increase timeout for slow machines
export NODE_START_TIMEOUT=60
```

### Ports Used

```
Node 1: P2P 16211, RPC 16210
Node 2: P2P 16311, RPC 16310
Node 3: P2P 16411, RPC 16410
Node 4: P2P 16511, RPC 16510
Node 5: P2P 16611, RPC 16610
```

Make sure these ports are free before running tests.

---

## Troubleshooting

### Issue: "kaspad not found"

**Solution:**
```bash
cargo build --release -p kaspad
```

### Issue: "Port already in use"

**Solution:**
```bash
# Kill any running kaspad processes
pkill kaspad

# Or kill specific ports
lsof -ti:16210 | xargs kill -9
```

### Issue: "Nodes not connecting"

**Check:**
1. Firewall settings (allow local connections)
2. Check logs: `/tmp/kaspa-network-test/node*.log`
3. Verify kaspad version supports ML-DSA

**Debug:**
```bash
# Run node manually to see errors
./target/release/kaspad --devnet --listen=0.0.0.0:16211 --loglevel=debug
```

### Issue: Test hangs/timeout

**Possible causes:**
- Slow machine (increase timeouts)
- kaspad compilation issue
- Network problems

**Debug:**
```bash
# Check if nodes are running
ps aux | grep kaspad

# Check RPC manually
curl -X POST http://127.0.0.1:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getInfo","params":[],"id":1}'
```

---

## Adding ML-DSA Transaction Tests

To add actual ML-DSA transaction testing, you need:

### 1. Create ML-DSA Address

```rust
use kaspa_mldsa::{generate_keypair, MlDsaLevel};
use kaspa_addresses::{Address, Prefix, Version};

let keypair = generate_keypair(MlDsaLevel::Level2);
let address = Address::new(
    Prefix::Testnet,
    Version::PubKeyMLDSA,
    keypair.public_key.as_bytes()
);
```

### 2. Fund Address (via mining)

```bash
curl -X POST http://127.0.0.1:16210 \
  -H "Content-Type: application/json" \
  -d '{
    "method": "generateBlock",
    "params": {
      "address": "kaspatest:qz...",
      "numBlocks": 100
    },
    "id": 1
  }'
```

### 3. Create Transaction

```rust
// Build transaction with ML-DSA signature
let tx = create_mldsa_transaction(&keypair, &utxos, outputs);

// Submit to network
submit_transaction(&node, &tx);
```

### 4. Verify Propagation

```rust
// Check all nodes received it
for node in &network.nodes {
    assert!(node.has_transaction(&tx_id));
}
```

---

## Performance Benchmarks

Expected performance for network tests:

| Metric | Target | Actual |
|--------|--------|--------|
| Node startup | < 3s | ~2s |
| P2P connection | < 5s | ~2-3s |
| Network formation (5 nodes) | < 15s | ~10s |
| Block propagation | < 5s | ~2-3s |
| Transaction propagation | < 3s | ~1-2s |

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Network E2E Tests

on: [push, pull_request]

jobs:
  network-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build kaspad
        run: cargo build --release -p kaspad
      - name: Run bash tests
        run: ./tests/network_e2e.sh
      - name: Run Rust tests
        run: cargo test --test network_integration --release -- --ignored
```

### Docker

```dockerfile
FROM rust:latest

WORKDIR /app
COPY . .

RUN cargo build --release -p kaspad

CMD ["./tests/network_e2e.sh"]
```

---

## Future Enhancements

### Planned Features:

1. **ML-DSA Transaction Pool**
   - Create 100 ML-DSA transactions
   - Submit to different nodes
   - Verify all nodes receive them

2. **Mixed Transaction Blocks**
   - Mine blocks with Schnorr + ML-DSA
   - Verify validation on all nodes
   - Measure propagation time

3. **Network Stress Test**
   - Spawn 20+ nodes
   - High transaction rate
   - Measure throughput

4. **Byzantine Fault Tolerance**
   - Malicious node behavior
   - Invalid signatures
   - Network recovery

5. **Cross-Version Compatibility**
   - Old nodes (Schnorr only)
   - New nodes (ML-DSA support)
   - Verify interop

---

## Contributing

To add new network tests:

1. **Bash tests**: Edit `tests/network_e2e.sh`
2. **Rust tests**: Add to `tests/network_integration.rs`
3. **Documentation**: Update this file

**Test template:**
```rust
#[test]
#[ignore]
fn test_my_network_scenario() {
    println!("\n🚀 My Network Test\n");

    let mut network = TestNetwork::new();

    // Setup
    network.add_node(None).unwrap();

    // Test logic
    // ...

    // Verify
    assert!(condition);

    println!("\n🎉 Test PASSED!\n");
}
```

---

## FAQ

**Q: How long do these tests take?**
A: Bash test ~30s, Rust tests ~60s each

**Q: Can I run tests in parallel?**
A: No, they use the same ports. Run sequentially.

**Q: Do I need root/sudo?**
A: No, tests use high ports (>1024)

**Q: Will tests interfere with my local node?**
A: No, they use different ports and data directories

**Q: Can I run on macOS/Windows?**
A: Yes, but bash script may need modifications for Windows

---

## Summary

**Quick test:**
```bash
./tests/network_e2e.sh
```

**Full test suite:**
```bash
cargo test --test network_integration --release -- --ignored --nocapture
```

**Expected result:** ✅ All nodes connect, network stable, no errors

---

**Status:** ✅ Network E2E tests available
**Date:** 2025-11-23
**Branch:** claude/kaspa-rust-quantum-01GbScjmf7uqkVZddjhQaGhr
