# Docker Testing Guide for ML-DSA

Comprehensive guide for running ML-DSA tests in Docker with full isolation and all dependencies.

## Why Docker?

✅ **Reproducible environment** - Same results on any machine
✅ **All dependencies included** - protoc, build tools, etc.
✅ **Isolation** - No conflicts with host system
✅ **CI/CD ready** - Easy integration with GitHub Actions
✅ **Clean slate** - Fresh environment every time

---

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
# Run ML-DSA transaction E2E test
docker-compose -f docker-compose.test.yml up mldsa-transaction-test

# Run transaction propagation test
docker-compose -f docker-compose.test.yml up mldsa-propagation-test

# Run all ML-DSA E2E tests
docker-compose -f docker-compose.test.yml up all-mldsa-tests

# Run all integration tests (comprehensive)
docker-compose -f docker-compose.test.yml up all-integration-tests
```

### Option 2: Docker CLI

```bash
# Build image
docker build -f Dockerfile.test -t kaspa-mldsa-test .

# Run test
docker run --rm kaspa-mldsa-test
```

---

## Available Test Services

### 1. ML-DSA Transaction Creation Test

**What it does:**
- Spawns 2 kaspad nodes
- Creates ML-DSA wallet (Level 2)
- Mines 110 blocks for funding
- Creates and signs ML-DSA transaction
- Submits to network
- Verifies mining and propagation

**Run:**
```bash
docker-compose -f docker-compose.test.yml up mldsa-transaction-test
```

**Duration:** ~120 seconds

---

### 2. ML-DSA Transaction Propagation Test

**What it does:**
- Sets up 3-node network
- Creates and submits ML-DSA transaction
- Verifies propagation to all nodes

**Run:**
```bash
docker-compose -f docker-compose.test.yml up mldsa-propagation-test
```

**Duration:** ~90 seconds

---

### 3. All ML-DSA E2E Tests

**What it does:**
- Runs all ML-DSA transaction tests
- Includes creation, propagation, and edge cases

**Run:**
```bash
docker-compose -f docker-compose.test.yml up all-mldsa-tests
```

**Duration:** ~5 minutes

---

### 4. Comprehensive Integration Suite

**What it does:**
- ML-DSA unit tests (57 tests)
- ML-DSA integration tests (3 tests)
- ML-DSA E2E comprehensive tests (6 tests)
- ML-DSA transaction E2E tests (3 tests)

**Run:**
```bash
docker-compose -f docker-compose.test.yml up all-integration-tests
```

**Duration:** ~10 minutes

**Expected output:**
```
===== ML-DSA Unit Tests =====
test result: ok. 57 passed; 0 failed; 0 ignored

===== ML-DSA Integration Tests =====
test result: ok. 3 passed; 0 failed; 0 ignored

===== ML-DSA E2E Comprehensive Tests =====
test result: ok. 6 passed; 0 failed; 0 ignored

===== ML-DSA Transaction E2E Tests =====
🚀 E2E Test: ML-DSA Transaction Creation and Mining
  ✓ Created ML-DSA wallets
  ✓ Funded ML-DSA address via mining
  ✓ Created ML-DSA signed transaction
  ✓ Submitted to network
  ✓ Transaction mined in block
  ✓ Recipient received funds
🎉 ML-DSA Transaction E2E Test PASSED!

test result: ok. 3 passed; 0 failed; 0 ignored

🎉 All tests completed!
```

---

### 5. Network Integration Tests

**What it does:**
- Runs bash script network tests
- Tests network scaling and connectivity

**Run:**
```bash
docker-compose -f docker-compose.test.yml up network-tests
```

---

### 6. Interactive Shell (Debugging)

**Use for:**
- Debugging test failures
- Exploring the environment
- Manual test execution

**Run:**
```bash
docker-compose -f docker-compose.test.yml run shell
```

**Inside container:**
```bash
# Run specific test
cargo test -p kaspa-txscript --release test_mldsa_transaction_creation_and_mining -- --ignored --nocapture

# Check kaspad
./target/release/kaspad --version

# Run custom commands
cargo test -p kaspa-mldsa --release

# Exit
exit
```

---

## Build Details

### Dockerfile.test

**Base image:** `rust:1.82-slim`

**Installed dependencies:**
- protobuf-compiler (protoc)
- libprotobuf-dev
- pkg-config
- libssl-dev
- build-essential
- curl
- git

**Build steps:**
1. Install system dependencies
2. Copy project files
3. Build kaspad (~5-10 minutes)
4. Build tests
5. Ready to run

**Total build time:** ~10-15 minutes (first time)
**Image size:** ~3-4 GB (includes Rust toolchain + built binaries)

---

## Advanced Usage

### Run with Custom Arguments

```bash
docker run --rm kaspa-mldsa-test \
  cargo test -p kaspa-txscript --release \
  test_mldsa_transaction_propagation \
  -- --ignored --nocapture --test-threads=1
```

### Mount Local Code (for development)

```bash
docker run --rm \
  -v $(pwd):/app \
  -w /app \
  kaspa-mldsa-test \
  cargo test -p kaspa-mldsa --release
```

### Save Test Results

```bash
docker run --rm \
  -v $(pwd)/test-results:/app/test-results \
  kaspa-mldsa-test \
  bash -c "cargo test --release 2>&1 | tee /app/test-results/output.log"
```

### Parallel Test Execution

```bash
# Run multiple test suites in parallel
docker-compose -f docker-compose.test.yml up -d mldsa-transaction-test mldsa-propagation-test

# Check status
docker-compose -f docker-compose.test.yml ps

# View logs
docker-compose -f docker-compose.test.yml logs -f
```

---

## Performance Optimization

### Use Build Cache

Docker caches layers, so subsequent builds are faster:

```bash
# First build: ~10-15 minutes
docker build -f Dockerfile.test -t kaspa-mldsa-test .

# Rebuild (no code changes): ~30 seconds
docker build -f Dockerfile.test -t kaspa-mldsa-test .

# Rebuild (code changes): ~2-5 minutes
docker build -f Dockerfile.test -t kaspa-mldsa-test .
```

### Use Cargo Cache Volumes

Docker Compose automatically uses volumes for cargo cache:

```yaml
volumes:
  - cargo-cache:/usr/local/cargo/registry
  - cargo-git:/usr/local/cargo/git
```

This speeds up dependency downloads between runs.

### Pre-built Image

For CI/CD, push pre-built image to registry:

```bash
# Build and tag
docker build -f Dockerfile.test -t ghcr.io/yourname/kaspa-mldsa-test:latest .

# Push to registry
docker push ghcr.io/yourname/kaspa-mldsa-test:latest

# Use in CI
docker pull ghcr.io/yourname/kaspa-mldsa-test:latest
docker run --rm ghcr.io/yourname/kaspa-mldsa-test:latest
```

---

## Troubleshooting

### Build Fails: "protoc not found"

**Problem:** protoc not installed in container

**Solution:** Already fixed in Dockerfile.test. If using custom Dockerfile, add:
```dockerfile
RUN apt-get update && apt-get install -y protobuf-compiler
```

### Test Timeout

**Problem:** Tests take too long

**Solution:** Increase Docker resources:
- Docker Desktop → Settings → Resources
- Increase CPUs to 4+
- Increase Memory to 8GB+

### Out of Disk Space

**Problem:** Docker images too large

**Solution:**
```bash
# Clean up old images
docker system prune -a

# Remove specific image
docker rmi kaspa-mldsa-test

# Remove volumes
docker volume prune
```

### Tests Fail: "Address already in use"

**Problem:** Ports conflict with host

**Solution:** Tests use dynamic port allocation, should not conflict. If it does:
```bash
# Stop all containers
docker-compose -f docker-compose.test.yml down

# Kill kaspad processes on host
pkill kaspad
```

### Permission Denied

**Problem:** Cannot access /app in container

**Solution:**
```bash
# Run with user mapping
docker run --rm --user $(id -u):$(id -g) kaspa-mldsa-test
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: ML-DSA E2E Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Build Docker image
        run: docker build -f Dockerfile.test -t kaspa-mldsa-test .

      - name: Run ML-DSA transaction tests
        run: |
          docker run --rm kaspa-mldsa-test \
            cargo test -p kaspa-txscript --release \
            mldsa_transactions_e2e \
            -- --ignored --nocapture

      - name: Run all integration tests
        run: |
          docker-compose -f docker-compose.test.yml up \
            --abort-on-container-exit \
            all-integration-tests
```

### GitLab CI

```yaml
test:mldsa:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -f Dockerfile.test -t kaspa-mldsa-test .
    - docker run --rm kaspa-mldsa-test cargo test -p kaspa-txscript --release mldsa_transactions_e2e -- --ignored --nocapture
```

---

## Comparison: Docker vs Local

| Aspect | Docker | Local |
|--------|--------|-------|
| **Setup Time** | 10-15 min (first build) | 5 min (install protoc) |
| **Reproducibility** | ✅ 100% | ⚠️ Depends on system |
| **Isolation** | ✅ Full | ❌ None |
| **Dependencies** | ✅ Automatic | ⚠️ Manual install |
| **CI/CD** | ✅ Easy | ⚠️ Harder |
| **Performance** | ⚠️ Slightly slower | ✅ Native speed |
| **Disk Space** | ⚠️ ~4GB | ✅ ~2GB |

**Recommendation:**
- **Development:** Local (faster iteration)
- **Testing/CI:** Docker (reproducible)
- **Production validation:** Docker (clean environment)

---

## Best Practices

### 1. Clean Builds

```bash
# Remove all containers and volumes
docker-compose -f docker-compose.test.yml down -v

# Rebuild from scratch
docker build --no-cache -f Dockerfile.test -t kaspa-mldsa-test .
```

### 2. Resource Limits

```yaml
services:
  mldsa-transaction-test:
    # ... other config
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
```

### 3. Multi-stage Builds (for smaller images)

See `Dockerfile.test.optimized` (if created) for production-ready multi-stage build.

### 4. Test Reports

```bash
# Generate JUnit XML reports
docker run --rm \
  -v $(pwd)/test-results:/app/test-results \
  kaspa-mldsa-test \
  cargo test --release -- -Z unstable-options --format junit > test-results/junit.xml
```

---

## Next Steps

1. **Run your first test:**
   ```bash
   docker-compose -f docker-compose.test.yml up mldsa-transaction-test
   ```

2. **Integrate with CI/CD:**
   - Add GitHub Actions workflow
   - Configure automatic testing on PR

3. **Optimize builds:**
   - Use multi-stage Dockerfile
   - Cache dependencies

4. **Monitor performance:**
   - Track test execution times
   - Set up alerts for failures

---

## Support

**Issues:** Report at https://github.com/777genius/rusty-kaspa/issues
**Documentation:** See NETWORK_TESTING.md for test details
**Docker Hub:** (Coming soon)

---

**Status:** ✅ Ready for production testing
**Last updated:** 2025-11-23
