#!/bin/bash
# Quick Docker Test Script
# Run ML-DSA E2E test in Docker with one command

set -e

echo "🐳 ML-DSA Docker Test Runner"
echo "============================"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found!"
    echo ""
    echo "Install Docker:"
    echo "  - Ubuntu/Debian: sudo apt-get install docker.io"
    echo "  - macOS: brew install --cask docker"
    echo "  - Windows: Download from https://www.docker.com/products/docker-desktop"
    exit 1
fi

echo "✓ Docker found: $(docker --version)"
echo ""

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon not running!"
    echo ""
    echo "Start Docker:"
    echo "  - Linux: sudo systemctl start docker"
    echo "  - macOS/Windows: Start Docker Desktop"
    exit 1
fi

echo "✓ Docker daemon running"
echo ""

# Choose test to run
TEST="${1:-mldsa-transaction-test}"

echo "📦 Running test: $TEST"
echo ""
echo "Available tests:"
echo "  mldsa-transaction-test    - ML-DSA transaction creation and mining (default)"
echo "  mldsa-propagation-test    - Transaction propagation across nodes"
echo "  all-mldsa-tests          - All ML-DSA E2E tests"
echo "  all-integration-tests    - Complete test suite (10+ minutes)"
echo "  shell                    - Interactive shell for debugging"
echo ""

# Build and run
echo "Starting Docker Compose..."
echo ""

if [ "$TEST" = "shell" ]; then
    docker-compose -f docker-compose.test.yml run --rm shell
else
    docker-compose -f docker-compose.test.yml up --abort-on-container-exit "$TEST"
fi

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 Test completed successfully!"
else
    echo "❌ Test failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
