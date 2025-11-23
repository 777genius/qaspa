# 🚀 Quick Start: Run ML-DSA Tests in Docker

## One-Command Test

```bash
./test-docker.sh
```

That's it! This will:
- ✅ Check Docker is installed and running
- ✅ Build the test environment (10-15 min first time, then cached)
- ✅ Run ML-DSA transaction E2E test (~2 minutes)
- ✅ Show you real ML-DSA transactions being created and mined!

---

## Expected Output

```
🐳 ML-DSA Docker Test Runner
============================

✓ Docker found: Docker version 24.0.7
✓ Docker daemon running

📦 Running test: mldsa-transaction-test

Starting Docker Compose...

[+] Building 0.0s (0/0)
[+] Running 1/1
 ✔ Container rusty-kaspa-mldsa-transaction-test-1  Created

Attaching to mldsa-transaction-test-1

mldsa-transaction-test-1  | 🚀 E2E Test: ML-DSA Transaction Creation and Mining
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 1: Starting network
mldsa-transaction-test-1  |   Starting node 1...
mldsa-transaction-test-1  |     Waiting for node 1 to be ready ✓
mldsa-transaction-test-1  |   Starting node 2...
mldsa-transaction-test-1  |     Waiting for node 2 to be ready ✓
mldsa-transaction-test-1  |
mldsa-transaction-test-1  |   Waiting for network connectivity...
mldsa-transaction-test-1  |   ✓ All nodes connected
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 2: Creating ML-DSA wallet
mldsa-transaction-test-1  |   ✓ Created ML-DSA wallet
mldsa-transaction-test-1  |     Address: kaspadev:qz<1312-byte-pubkey>
mldsa-transaction-test-1  |     Public key size: 1312 bytes
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 3: Funding ML-DSA address
mldsa-transaction-test-1  |   Mining 10 blocks to ML-DSA address...
mldsa-transaction-test-1  |   ✓ Mined 10 blocks
mldsa-transaction-test-1  |   Mining additional 100 blocks for coinbase maturity...
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 4: Checking UTXOs
mldsa-transaction-test-1  |   ✓ Found 110 UTXOs
mldsa-transaction-test-1  |     Total balance: 1100000000000 sompi
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 5: Creating recipient wallet
mldsa-transaction-test-1  |   ✓ Created recipient wallet
mldsa-transaction-test-1  |     Address: kaspadev:qz<another-1312-byte-pubkey>
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 6: Creating ML-DSA transaction
mldsa-transaction-test-1  |   Creating transaction:
mldsa-transaction-test-1  |     From: kaspadev:qz...
mldsa-transaction-test-1  |     To: kaspadev:qz...
mldsa-transaction-test-1  |     Amount: 1000000000 sompi
mldsa-transaction-test-1  |     Fee: 1000 sompi
mldsa-transaction-test-1  |   ✓ Transaction created
mldsa-transaction-test-1  |     Size: 3847 bytes (ML-DSA signature: 2420 bytes!)
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 7: Submitting transaction to network
mldsa-transaction-test-1  |   ✓ Transaction submitted
mldsa-transaction-test-1  |     TX ID: abc123def456...
mldsa-transaction-test-1  |   Checking transaction propagation to node 2...
mldsa-transaction-test-1  |   ✓ Transaction propagated to node 2
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 8: Mining block with ML-DSA transaction
mldsa-transaction-test-1  |   ✓ Mined block: 789xyz...
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 📍 Phase 9: Verifying recipient balance
mldsa-transaction-test-1  |   Recipient UTXOs: 1
mldsa-transaction-test-1  |   Recipient balance: 1000000000 sompi
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | 🎉 ML-DSA Transaction E2E Test PASSED!
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | Summary:
mldsa-transaction-test-1  |   ✓ Created ML-DSA wallets
mldsa-transaction-test-1  |   ✓ Funded ML-DSA address via mining
mldsa-transaction-test-1  |   ✓ Created ML-DSA signed transaction
mldsa-transaction-test-1  |   ✓ Submitted to network
mldsa-transaction-test-1  |   ✓ Transaction mined in block
mldsa-transaction-test-1  |   ✓ Recipient received funds
mldsa-transaction-test-1  |   ✓ Multi-node network functioning
mldsa-transaction-test-1  |
mldsa-transaction-test-1  | test result: ok. 1 passed; 0 failed; 0 ignored

mldsa-transaction-test-1 exited with code 0

🎉 Test completed successfully!
```

---

## Other Available Tests

```bash
# Test transaction propagation (3 nodes)
./test-docker.sh mldsa-propagation-test

# Run all ML-DSA tests
./test-docker.sh all-mldsa-tests

# Run complete test suite (10+ minutes)
./test-docker.sh all-integration-tests

# Interactive debugging shell
./test-docker.sh shell
```

---

## First Time Setup

### Install Docker

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER  # Add yourself to docker group
# Logout and login again
```

**macOS:**
```bash
brew install --cask docker
# Start Docker Desktop from Applications
```

**Windows:**
1. Download Docker Desktop from https://www.docker.com/products/docker-desktop
2. Install and start Docker Desktop

### Verify Installation

```bash
docker --version
docker-compose --version
```

---

## Manual Docker Commands

If you prefer manual control:

```bash
# Build image
docker build -f Dockerfile.test -t kaspa-mldsa-test .

# Run single test
docker run --rm kaspa-mldsa-test

# Or use docker-compose
docker-compose -f docker-compose.test.yml up mldsa-transaction-test
```

---

## What Happens Inside

1. **Base Image:** Pulls `rust:1.82-slim` (~1GB)
2. **Install deps:** Installs protoc and build tools (~500MB)
3. **Copy code:** Copies your rusty-kaspa code
4. **Build kaspad:** Compiles kaspad with protoc (~5-10 min)
5. **Build tests:** Compiles all tests (~2 min)
6. **Run test:** Executes ML-DSA E2E test (~2 min)

**Total first run:** ~15 minutes
**Subsequent runs:** ~2 minutes (cached!)

---

## Troubleshooting

### Docker not found
```bash
# Install Docker (see above)
```

### Docker daemon not running
```bash
# Linux
sudo systemctl start docker

# macOS/Windows
# Start Docker Desktop application
```

### Permission denied
```bash
# Linux - add yourself to docker group
sudo usermod -aG docker $USER
# Then logout and login again
```

### Out of disk space
```bash
# Clean up old images
docker system prune -a
```

---

## Next Steps

- ✅ Run the test with `./test-docker.sh`
- ✅ See real ML-DSA transactions in action!
- ✅ Check `DOCKER_TESTING.md` for advanced usage
- ✅ Set up CI/CD with GitHub Actions (already configured!)

---

**Ready to see quantum-resistant signatures in action?**

```bash
./test-docker.sh
```

🚀 Let's go!
