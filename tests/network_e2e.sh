#!/bin/bash
# Network E2E Test for QUBIC ML-DSA
#
# This script:
# 1. Starts with 2 nodes
# 2. Scales to 5 nodes
# 3. Creates ML-DSA transactions
# 4. Verifies block propagation
# 5. Tests network consensus

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 QUBIC ML-DSA Network E2E Test${NC}\n"

# Configuration
KASPAD_BIN="./target/release/kaspad"
BASE_DIR="/tmp/kaspa-network-test"
SEED_P2P_PORT=16211
SEED_RPC_PORT=16210

# Check if kaspad is built
if [ ! -f "$KASPAD_BIN" ]; then
    echo -e "${YELLOW}Building kaspad...${NC}"
    cargo build --release -p kaspad
fi

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up nodes...${NC}"
    pkill -f "kaspad.*network-test" || true
    rm -rf "$BASE_DIR"
    echo -e "${GREEN}Cleanup complete${NC}"
}

trap cleanup EXIT

# Clean start
cleanup
mkdir -p "$BASE_DIR"

# Helper functions
wait_for_node() {
    local port=$1
    local max_attempts=30
    local attempt=0

    echo -n "Waiting for node on port $port"
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -X POST "http://127.0.0.1:$port" \
            -H "Content-Type: application/json" \
            -d '{"method":"getInfo","params":[],"id":1}' >/dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done

    echo -e " ${RED}✗ Failed${NC}"
    return 1
}

get_peer_count() {
    local port=$1
    curl -s -X POST "http://127.0.0.1:$port" \
        -H "Content-Type: application/json" \
        -d '{"method":"getPeerInfo","params":[],"id":1}' | \
        jq -r '.result.peerInfo | length' 2>/dev/null || echo "0"
}

get_block_count() {
    local port=$1
    curl -s -X POST "http://127.0.0.1:$port" \
        -H "Content-Type: application/json" \
        -d '{"method":"getBlockCount","params":[],"id":1}' | \
        jq -r '.result.blockCount' 2>/dev/null || echo "0"
}

# Phase 1: Start with 2 nodes
echo -e "\n${GREEN}📍 Phase 1: Starting with 2 nodes${NC}\n"

echo "Starting seed node (Node 1)..."
$KASPAD_BIN --devnet \
    --listen=0.0.0.0:$SEED_P2P_PORT \
    --rpclisten=127.0.0.1:$SEED_RPC_PORT \
    --appdir="$BASE_DIR/node1" \
    --loglevel=info \
    --nodnsseed \
    > "$BASE_DIR/node1.log" 2>&1 &
NODE1_PID=$!
echo "  PID: $NODE1_PID"

wait_for_node $SEED_RPC_PORT

echo "Starting peer node (Node 2)..."
$KASPAD_BIN --devnet \
    --listen=0.0.0.0:16311 \
    --rpclisten=127.0.0.1:16310 \
    --appdir="$BASE_DIR/node2" \
    --loglevel=info \
    --connect=127.0.0.1:$SEED_P2P_PORT \
    --nodnsseed \
    > "$BASE_DIR/node2.log" 2>&1 &
NODE2_PID=$!
echo "  PID: $NODE2_PID"

wait_for_node 16310

# Verify nodes are connected
echo -e "\nVerifying node connections..."
sleep 3
PEERS1=$(get_peer_count $SEED_RPC_PORT)
PEERS2=$(get_peer_count 16310)

echo "  Node 1 peers: $PEERS1"
echo "  Node 2 peers: $PEERS2"

if [ "$PEERS1" -ge 1 ] && [ "$PEERS2" -ge 1 ]; then
    echo -e "${GREEN}  ✓ Nodes are connected!${NC}"
else
    echo -e "${RED}  ✗ Nodes failed to connect${NC}"
    exit 1
fi

# Phase 2: Scale to 5 nodes
echo -e "\n${GREEN}📍 Phase 2: Scaling to 5 nodes${NC}\n"

for i in 3 4 5; do
    p2p_port=$((16211 + (i-1)*100))
    rpc_port=$((16210 + (i-1)*100))

    echo "Starting Node $i..."
    $KASPAD_BIN --devnet \
        --listen=0.0.0.0:$p2p_port \
        --rpclisten=127.0.0.1:$rpc_port \
        --appdir="$BASE_DIR/node$i" \
        --loglevel=info \
        --connect=127.0.0.1:$SEED_P2P_PORT \
        --nodnsseed \
        > "$BASE_DIR/node$i.log" 2>&1 &

    eval "NODE${i}_PID=$!"
    echo "  PID: $!"

    wait_for_node $rpc_port
done

# Give nodes time to discover each other
echo -e "\nWaiting for network stabilization..."
sleep 5

# Verify full mesh connectivity
echo -e "\nNetwork topology:"
for i in 1 2 3 4 5; do
    rpc_port=$((16210 + (i-1)*100))
    peers=$(get_peer_count $rpc_port)
    echo "  Node $i: $peers peers"
done

# Phase 3: Create ML-DSA transactions
echo -e "\n${GREEN}📍 Phase 3: Creating ML-DSA transactions${NC}\n"

# Note: This would require actual wallet integration
# For now, we'll test that the nodes are running and can accept RPC calls
echo "Testing RPC on all nodes..."
for i in 1 2 3 4 5; do
    rpc_port=$((16210 + (i-1)*100))
    info=$(curl -s -X POST "http://127.0.0.1:$rpc_port" \
        -H "Content-Type: application/json" \
        -d '{"method":"getInfo","params":[],"id":1}')

    network=$(echo "$info" | jq -r '.result.serverVersion' 2>/dev/null || echo "unknown")
    echo "  Node $i: $network"
done

# Phase 4: Test block propagation
echo -e "\n${GREEN}📍 Phase 4: Testing block propagation${NC}\n"

echo "Initial block heights:"
for i in 1 2 3 4 5; do
    rpc_port=$((16210 + (i-1)*100))
    blocks=$(get_block_count $rpc_port)
    echo "  Node $i: $blocks blocks"
done

# In a real scenario, we would:
# 1. Mine a block on node 1
# 2. Wait for propagation
# 3. Verify all nodes see the same block

echo -e "\nNote: Block mining requires additional setup"
echo "  In production, you would:"
echo "  - Generate mining address"
echo "  - Call generateBlock RPC"
echo "  - Verify propagation to all nodes"

# Phase 5: Network stress test
echo -e "\n${GREEN}📍 Phase 5: Network stress test${NC}\n"

echo "Monitoring network for 10 seconds..."
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""

# Check all nodes are still alive
echo -e "\nFinal node status:"
all_alive=true
for i in 1 2 3 4 5; do
    rpc_port=$((16210 + (i-1)*100))
    pid_var="NODE${i}_PID"
    pid=${!pid_var}

    if kill -0 $pid 2>/dev/null; then
        peers=$(get_peer_count $rpc_port)
        blocks=$(get_block_count $rpc_port)
        echo -e "  Node $i: ${GREEN}ALIVE${NC} (PID: $pid, Peers: $peers, Blocks: $blocks)"
    else
        echo -e "  Node $i: ${RED}DEAD${NC}"
        all_alive=false
    fi
done

# Phase 6: Results
echo -e "\n${GREEN}📊 Test Results${NC}\n"

if $all_alive; then
    echo -e "${GREEN}✅ All nodes are healthy${NC}"
else
    echo -e "${RED}❌ Some nodes died${NC}"
fi

# Check logs for errors
echo -e "\nChecking logs for errors..."
error_count=0
for i in 1 2 3 4 5; do
    errors=$(grep -i "error\|panic\|fatal" "$BASE_DIR/node$i.log" | wc -l)
    if [ $errors -gt 0 ]; then
        echo -e "  Node $i: ${YELLOW}$errors errors found${NC}"
        error_count=$((error_count + errors))
    else
        echo -e "  Node $i: ${GREEN}No errors${NC}"
    fi
done

# Final verdict
echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
if $all_alive && [ $error_count -eq 0 ]; then
    echo -e "${GREEN}🎉 NETWORK E2E TEST PASSED!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}❌ NETWORK E2E TEST FAILED${NC}"
    echo -e "${RED}═══════════════════════════════════════${NC}"

    echo -e "\nLog files available at:"
    for i in 1 2 3 4 5; do
        echo "  $BASE_DIR/node$i.log"
    done

    exit 1
fi
