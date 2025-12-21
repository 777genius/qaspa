#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTNET_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$TESTNET_DIR")"
COMPOSE_FILE="$TESTNET_DIR/compose/docker-compose.devnet.yml"
NETWORK="qaspa_testnet_net"
CLUSTER_LABEL="testnet_local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Stopping testnet..."

    # Stop docker-compose services
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true

    # Remove any dynamic containers by label
    DYNAMIC_CONTAINERS=$(docker ps -aq --filter "label=qaspa.cluster=$CLUSTER_LABEL" 2>/dev/null || true)
    if [ -n "$DYNAMIC_CONTAINERS" ]; then
        log_info "Removing dynamic containers..."
        echo "$DYNAMIC_CONTAINERS" | xargs -r docker rm -f 2>/dev/null || true
    fi

    # Remove orphaned volumes
    docker volume prune -f --filter "label=qaspa.cluster=$CLUSTER_LABEL" 2>/dev/null || true

    log_success "Cleanup complete"
}

# Set up cleanup on exit
trap cleanup EXIT INT TERM

# Check for required tools
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi

# Parse arguments
PROFILE=""
BUILD_ONLY=false
NO_CONTROLLER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-txgen)
            PROFILE="--profile txgen"
            shift
            ;;
        --with-controller)
            PROFILE="$PROFILE --profile controller"
            shift
            ;;
        --build)
            BUILD_ONLY=true
            shift
            ;;
        --no-controller)
            NO_CONTROLLER=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --with-txgen       Enable transaction generator (rothschild)"
            echo "  --with-controller  Enable controller service in Docker"
            echo "  --build            Build images only, don't start"
            echo "  --no-controller    Run without controller (nodes only)"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

# Build images
log_info "Building Docker images..."
docker compose -f "$COMPOSE_FILE" $PROFILE build

if [ "$BUILD_ONLY" = true ]; then
    log_success "Build complete"
    exit 0
fi

# Start base cluster
log_info "Starting testnet cluster..."
docker compose -f "$COMPOSE_FILE" $PROFILE up -d

# Wait for seed node to be healthy
log_info "Waiting for seed node to be ready..."
RETRIES=30
while [ $RETRIES -gt 0 ]; do
    # Use docker inspect to check health status (defined in compose healthcheck)
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' qaspa_seed 2>/dev/null || echo "starting")
    if [ "$HEALTH" = "healthy" ]; then
        break
    fi
    # Fallback: try direct connection check
    if docker compose -f "$COMPOSE_FILE" exec -T seed nc -z localhost 16210 2>/dev/null; then
        break
    fi
    RETRIES=$((RETRIES - 1))
    sleep 2
done

if [ $RETRIES -eq 0 ]; then
    log_error "Seed node failed to start"
    exit 1
fi

log_success "Seed node is ready"

# Wait for peers
log_info "Waiting for peer nodes..."
sleep 5

# Print status
echo ""
log_success "Testnet is running!"
echo ""
echo -e "  ${GREEN}Seed Node:${NC}"
echo -e "    gRPC:  localhost:16210"
echo -e "    P2P:   localhost:16211"
echo ""
echo -e "  ${GREEN}Peer 1:${NC}"
echo -e "    gRPC:  localhost:16310"
echo -e "    P2P:   localhost:16311"
echo ""
echo -e "  ${GREEN}Peer 2:${NC}"
echo -e "    gRPC:  localhost:16410"
echo -e "    P2P:   localhost:16411"
echo ""

if echo "$PROFILE" | grep -q "controller"; then
    echo -e "  ${GREEN}Controller:${NC}"
    echo -e "    HTTP:  http://localhost:8080"
    echo ""
fi

if echo "$PROFILE" | grep -q "txgen"; then
    echo -e "  ${GREEN}TX Generator:${NC} Running"
    echo ""
fi

echo -e "Press ${YELLOW}Ctrl+C${NC} to stop the testnet"
echo ""

# Keep running and show logs
docker compose -f "$COMPOSE_FILE" logs -f
