# Qaspa Makefile

.PHONY: help build test testnet testnet-build testnet-stop testnet-logs testnet-txgen clean

# Default target
help:
	@echo "Qaspa Makefile"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  build           Build the project (cargo build --release)"
	@echo "  test            Run tests (cargo test)"
	@echo "  clean           Clean build artifacts"
	@echo ""
	@echo "Testnet targets:"
	@echo "  testnet         Start local devnet (seed + 2 peers)"
	@echo "  testnet-build   Build testnet Docker images"
	@echo "  testnet-stop    Stop testnet and cleanup"
	@echo "  testnet-logs    Show testnet logs"
	@echo "  testnet-txgen   Start testnet with transaction generator"
	@echo ""

# Build targets
build:
	cargo build --release

test:
	cargo test

clean:
	cargo clean

# Testnet targets
testnet:
	./testnet/scripts/run.sh

testnet-build:
	./testnet/scripts/run.sh --build

testnet-stop:
	docker compose -f testnet/compose/docker-compose.devnet.yml down -v --remove-orphans
	docker ps -aq --filter "label=qaspa.cluster=testnet_local" | xargs -r docker rm -f 2>/dev/null || true

testnet-logs:
	docker compose -f testnet/compose/docker-compose.devnet.yml logs -f

testnet-txgen:
	./testnet/scripts/run.sh --with-txgen

testnet-controller:
	./testnet/scripts/run.sh --with-controller
