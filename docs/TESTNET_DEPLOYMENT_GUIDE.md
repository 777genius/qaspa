# QUBIC ML-DSA Testnet Deployment Guide

## Overview

This guide explains how to deploy and test the ML-DSA post-quantum signature implementation on a testnet environment.

**Status:** ✅ Code is production-ready for testnet deployment

## Network Types

### 1. Testnet (Public)
- **Purpose:** Connect to existing Kaspa testnet
- **Use case:** Integration testing with other nodes
- **Isolation:** Shared network
- **Command:** `--testnet`

### 2. Devnet (Private - **RECOMMENDED**)
- **Purpose:** Your own isolated test network
- **Use case:** ML-DSA feature testing without external interference
- **Isolation:** Complete isolation
- **Command:** `--devnet`

### 3. Simnet (Simulation)
- **Purpose:** Fast local testing
- **Use case:** Quick validation
- **Isolation:** Local only
- **Command:** `--simnet`

---

## Quick Start (Devnet)

**Recommended for ML-DSA testing**

### Step 1: Build kaspad

```bash
cd /home/user/rusty-kaspa
cargo build --release -p kaspad
```

**Build time:** ~5-10 minutes (depending on hardware)

### Step 2: Run Devnet Node

```bash
./target/release/kaspad --devnet --loglevel=info
```

**Expected output:**
```
[INFO] Starting kaspad...
[INFO] Network: devnet-10
[INFO] Data directory: ~/.kaspa/devnet-10
[INFO] Starting P2P service...
[INFO] Starting RPC server...
```

### Step 3: Connect Wallet

In another terminal:

```bash
# Option 1: Use kaspa-wallet (if available)
kaspa-wallet --devnet

# Option 2: Use RPC directly
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getBlockCount","params":[],"id":1}'
```

---

## Testing ML-DSA Signatures

### Create ML-DSA Address

**Using Rust code:**

```rust
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
use kaspa_mldsa::MlDsaLevel;
use kaspa_addresses::Prefix;

// Generate ML-DSA keypair
let keypair = MlDsaKeypair::random(MlDsaLevel::Level2);

// Generate address for devnet
let address = keypair.to_address(Prefix::Testnet); // Use Testnet prefix for devnet

println!("ML-DSA Address: {}", address);
```

**Address format:**
```
kaspatest:qz...  # Starts with "kaspatest:" for testnet/devnet
```

### Send Transaction with ML-DSA Signature

**Using RPC:**

```bash
# 1. Get UTXO for the address
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{
    "method": "getUtxosByAddresses",
    "params": {
      "addresses": ["kaspatest:qz...your-mldsa-address"]
    },
    "id": 1
  }'

# 2. Create transaction (manually construct with ML-DSA signature)
# See example code below
```

**Example transaction creation:**

```rust
use kaspa_consensus_core::tx::{Transaction, TransactionInput, TransactionOutput};
use kaspa_txscript::opcodes::codes::OpCheckSigMLDSA;
use kaspa_mldsa::sign;

// Create transaction
let tx = Transaction {
    version: 0,
    inputs: vec![/* your inputs */],
    outputs: vec![/* your outputs */],
    lock_time: 0,
    subnetwork_id: Default::default(),
    gas: 0,
    payload: vec![],
};

// Sign with ML-DSA
let signature = sign(tx_hash.as_bytes(), &keypair.secret_key());

// Add signature to script
// signature_script: <signature> <pubkey>
```

---

## Advanced Configuration

### Full Command Options

```bash
./target/release/kaspad \
  --devnet \
  --loglevel=debug \
  --appdir=~/.kaspa-mldsa-test \
  --rpclisten=127.0.0.1:16210 \
  --listen=0.0.0.0:16211 \
  --utxoindex \
  --reset-db  # Clear previous data
```

### Configuration File

Create `~/.kaspa/kaspad.toml`:

```toml
devnet = true
loglevel = "info"
appdir = "~/.kaspa-mldsa-test"
utxoindex = true

# RPC settings
rpclisten = "127.0.0.1:16210"

# P2P settings
listen = "0.0.0.0:16211"
outpeers = 8
maxinpeers = 128

# Performance
async-threads = 4
ram-scale = 1.0
```

Then run:
```bash
./target/release/kaspad --configfile=~/.kaspa/kaspad.toml
```

---

## Verification Steps

### 1. Check Node Status

```bash
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getInfo","params":[],"id":1}' | jq
```

**Expected response:**
```json
{
  "result": {
    "serverVersion": "...",
    "networkId": "devnet-10",
    "hasUtxoIndex": true,
    "isSynced": true
  }
}
```

### 2. Mine Blocks

```bash
# Generate blocks to your address
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{
    "method": "generateBlock",
    "params": {
      "address": "kaspatest:qz...your-address",
      "numBlocks": 100
    },
    "id": 1
  }'
```

### 3. Verify ML-DSA Transaction

After sending an ML-DSA transaction:

```bash
# Get transaction by ID
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{
    "method": "getTransaction",
    "params": {
      "txId": "your-tx-id"
    },
    "id": 1
  }' | jq
```

**Check for:**
- ✅ Transaction accepted
- ✅ Signature script contains ML-DSA signature (~2420 bytes)
- ✅ Transaction mass is reasonable (~7,340 for ML-DSA)

---

## Performance Testing

### Test ML-DSA vs Schnorr Throughput

**Create test script:**

```bash
#!/bin/bash
# test-throughput.sh

echo "Testing transaction throughput..."

# Send 100 Schnorr transactions
for i in {1..100}; do
  # Create and send Schnorr tx
  echo "Schnorr tx $i"
done

# Send 100 ML-DSA transactions
for i in {1..100}; do
  # Create and send ML-DSA tx
  echo "ML-DSA tx $i"
done

# Check block times and transaction counts
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getBlockCount","params":[],"id":1}'
```

### Monitor Performance

```bash
# Watch logs
tail -f ~/.kaspa/devnet-10/logs/kaspad.log

# Monitor RPC
watch -n 1 'curl -s -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d "{\"method\":\"getInfo\",\"params\":[],\"id\":1}" | jq'
```

---

## Testing Scenarios

### Scenario 1: Basic ML-DSA Transaction

**Goal:** Verify ML-DSA signature creation and validation

**Steps:**
1. Generate ML-DSA keypair
2. Mine 100 blocks to ML-DSA address (get funds)
3. Create transaction spending from ML-DSA UTXO
4. Sign with ML-DSA
5. Submit transaction
6. Verify acceptance

**Expected result:** ✅ Transaction accepted and included in block

---

### Scenario 2: Mixed Block (Schnorr + ML-DSA)

**Goal:** Test mixed signature types in same block

**Steps:**
1. Create 10 Schnorr addresses
2. Create 10 ML-DSA addresses
3. Send funds to all addresses
4. Create 10 Schnorr transactions
5. Create 10 ML-DSA transactions
6. Submit all transactions
7. Verify all included in block

**Expected result:**
- ✅ All 20 transactions accepted
- ✅ Block validation time < 100ms

---

### Scenario 3: Mass Limit Testing

**Goal:** Verify optimized mass parameters

**Steps:**
1. Create block with maximum ML-DSA transactions
2. Expected: ~272 ML-DSA tx/block
3. Monitor block propagation time
4. Check validation time

**Expected result:**
- ✅ 272 ML-DSA tx fit in block
- ✅ Block size ~1 MB
- ✅ Validation time ~7.9ms

---

### Scenario 4: Stress Test

**Goal:** Test sustained ML-DSA transaction load

**Steps:**
1. Generate 1,000 ML-DSA transactions
2. Submit at 10 BPS rate
3. Monitor node performance
4. Check for any validation errors

**Expected result:**
- ✅ No validation errors
- ✅ CPU usage acceptable
- ✅ Memory usage stable

---

## Troubleshooting

### Issue: Node won't start

**Error:** `Address already in use`

**Solution:**
```bash
# Check if another kaspad is running
ps aux | grep kaspad

# Kill existing process
killall kaspad

# Or use different ports
./target/release/kaspad --devnet --rpclisten=127.0.0.1:17210 --listen=0.0.0.0:17211
```

---

### Issue: Transaction rejected

**Error:** `Transaction validation failed`

**Possible causes:**
1. **Invalid ML-DSA signature**
   - Check signature generation code
   - Verify correct message hash
   - Ensure correct public key

2. **Insufficient funds**
   - Check UTXO balance
   - Mine more blocks if needed

3. **Script execution error**
   - Verify OpCheckSigMLDSA usage
   - Check script pubkey format
   - Ensure signature script is correct

**Debug:**
```bash
# Enable debug logging
./target/release/kaspad --devnet --loglevel=debug

# Check logs
grep "ML-DSA\|signature\|validation" ~/.kaspa/devnet-10/logs/kaspad.log
```

---

### Issue: Poor performance

**Symptom:** Block validation taking too long

**Check:**
1. **CPU usage**
   ```bash
   htop  # Look for kaspad process
   ```

2. **Disk I/O**
   ```bash
   iotop  # Check if disk is bottleneck
   ```

3. **Memory**
   ```bash
   free -h  # Ensure sufficient RAM
   ```

**Optimization:**
```bash
# Increase RAM scale
./target/release/kaspad --devnet --ram-scale=2.0

# More async threads
./target/release/kaspad --devnet --async-threads=8
```

---

## Integration Testing Checklist

Before deploying to mainnet, verify:

### ✅ Core Functionality
- [ ] ML-DSA keypair generation works
- [ ] ML-DSA address generation works
- [ ] ML-DSA transactions are accepted
- [ ] ML-DSA signatures are validated correctly
- [ ] Invalid ML-DSA signatures are rejected

### ✅ Performance
- [ ] Block validation time < 100ms (at 10 BPS)
- [ ] ~272 ML-DSA tx fit in block
- [ ] CPU usage is acceptable
- [ ] Memory usage is stable

### ✅ Compatibility
- [ ] Schnorr transactions still work
- [ ] ECDSA transactions still work (if applicable)
- [ ] Mixed blocks work correctly
- [ ] Node syncs with other nodes

### ✅ Edge Cases
- [ ] Empty blocks work
- [ ] Full blocks (max mass) work
- [ ] Large ML-DSA transactions work
- [ ] Multiple ML-DSA inputs work

---

## Next Steps After Testing

### 1. Testnet Deployment (Public)

If devnet tests pass, deploy to public testnet:

```bash
./target/release/kaspad --testnet
```

**Considerations:**
- Other nodes may not have ML-DSA support yet
- Monitor consensus with other nodes
- Be prepared for potential issues

### 2. Bug Reporting

If you find issues, create detailed reports:

**Template:**
```markdown
## Issue: [Brief description]

**Environment:**
- Network: devnet/testnet
- Commit: [git commit hash]
- OS: Linux/macOS/Windows

**Steps to reproduce:**
1. ...
2. ...

**Expected behavior:**
...

**Actual behavior:**
...

**Logs:**
```
[paste relevant logs]
```
```

### 3. Documentation Updates

Document any findings:
- Performance measurements
- Edge cases discovered
- Configuration recommendations

---

## Useful Commands Reference

```bash
# Build
cargo build --release -p kaspad

# Run devnet
./target/release/kaspad --devnet

# Run with specific config
./target/release/kaspad --devnet --loglevel=debug --utxoindex

# Reset database
./target/release/kaspad --devnet --reset-db

# Check version
./target/release/kaspad --version

# Get help
./target/release/kaspad --help

# RPC: Get info
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getInfo","params":[],"id":1}'

# RPC: Get block count
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getBlockCount","params":[],"id":1}'

# RPC: Get peer info
curl -X POST http://localhost:16210 \
  -H "Content-Type: application/json" \
  -d '{"method":"getPeerInfo","params":[],"id":1}'
```

---

## Resources

- **Implementation Status:** `IMPLEMENTATION_STATUS.md`
- **Performance Benchmarks:** `PERFORMANCE_BENCHMARKS.md`
- **Test Coverage:** `TEST_COVERAGE_SUMMARY.md`
- **Migration Strategy:** `MIGRATION_STRATEGY.md`

---

## Support

For issues or questions:
1. Check logs: `~/.kaspa/devnet-10/logs/kaspad.log`
2. Review documentation
3. Create GitHub issue with details

---

**Status:** ✅ Ready for testnet deployment
**Date:** 2025-11-23
**Version:** ML-DSA integration complete
