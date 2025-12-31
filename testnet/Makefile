# Qaspa Testnet Development Makefile
# Usage: make <target>

.PHONY: help up down restart logs build-flutter build-controller build-miner dev dev-controller run-controller clean clean-chain clean-all add-miner add-miners up-dag status gen up-pool pool-up pool-down pool-logs pool-status down-all miner-pool miner-solo up-full build-pool pool-dev-infra pool-dev pool-dev-down pool-dev-reset-db e2e-test e2e-test-only e2e-test-pipeline e2e-test-integration e2e-test-fresh e2e-test-full e2e-miners-up e2e-miners-down e2e-miners-logs e2e-miners-status e2e-real-test

# Default target
help:
	@echo "Qaspa Testnet Commands:"
	@echo ""
	@echo "  Docker:"
	@echo "    make up              - Start all services (nodes + controller)"
	@echo "    make down            - Stop all services"
	@echo "    make restart         - Restart controller"
	@echo "    make logs            - View controller logs"
	@echo "    make logs-seed       - View seed node logs"
	@echo "    make logs-miner      - View miner logs (if running)"
	@echo ""
	@echo "  Build:"
	@echo "    make build-flutter   - Build Flutter web app"
	@echo "    make build-controller - Rebuild controller Docker image"
	@echo "    make build-miner     - Rebuild miner Docker image"
	@echo "    make build-all       - Build all images"
	@echo ""
	@echo "  Development:"
	@echo "    make dev             - Start Flutter dev server with hot reload"
	@echo "    make dev-controller  - Run controller locally with cargo-watch hot reload"
	@echo "    make run-controller  - Run controller locally (no hot reload, faster)"
	@echo "    make gen             - Run build_runner for code generation"
	@echo "    make clean           - Clean Flutter build artifacts"
	@echo "    make clean-chain     - Remove blockchain data (~2GB), keep postgres"
	@echo "    make clean-all       - Remove ALL data (blockchain + postgres)"
	@echo ""
	@echo "  Cluster:"
	@echo "    make status          - Show cluster status via API"
	@echo "    make add-miner       - Add a single test miner"
	@echo "    make add-miners      - Add 3 miners for DAG (or COUNT=N)"
	@echo "    make up-dag          - Start cluster + 3 miners for DAG"
	@echo ""
	@echo "  Pool:"
	@echo "    make up-pool         - Start nodes + pool (Stratum on :3333)"
	@echo "    make up-full         - Start nodes + pool + miner (pool mode)"
	@echo "    make pool-up         - Start pool (if nodes already running)"
	@echo "    make pool-down       - Stop pool only"
	@echo "    make pool-logs       - View pool logs"
	@echo "    make pool-status     - Check pool health"
	@echo "    make build-pool      - Build pool Docker image"
	@echo "    make down-all        - Stop everything (nodes + pool)"
	@echo ""
	@echo "  Miner Mode:"
	@echo "    make miner-pool      - Switch miner to pool mode (Stratum)"
	@echo "    make miner-solo      - Switch miner to solo mode (gRPC)"
	@echo ""
	@echo "  Pool Dev (Hot Reload):"
	@echo "    make pool-dev-infra  - Start infra for local pool dev"
	@echo "    make pool-dev        - Start infra + run pool locally"
	@echo "    make pool-dev-down   - Stop dev infrastructure"
	@echo "    make pool-dev-reset-db - Reset pool database"
	@echo ""
	@echo "  E2E Tests:"
	@echo "    make e2e-test        - Run E2E tests (starts pool if needed)"
	@echo "    make e2e-test-only   - Run E2E tests (assumes pool running)"
	@echo "    make e2e-test-pipeline - Run pipeline tests only (faster)"
	@echo "    make e2e-test-full   - Run full E2E with miner"
	@echo ""

# ============== Docker ==============

COMPOSE_FILE = compose/docker-compose.devnet.yml
COMPOSE = docker compose -f $(COMPOSE_FILE)

up:
	$(COMPOSE) up -d
	$(COMPOSE) --profile controller up -d

down:
	$(COMPOSE) --profile controller down
	$(COMPOSE) down

restart:
	docker restart qaspa_controller

logs:
	docker logs -f qaspa_controller

logs-seed:
	docker logs -f qaspa_seed

logs-miner:
	@docker ps --filter "label=qaspa.role=miner" --format "{{.Names}}" | head -1 | xargs -I {} docker logs -f {}

# ============== Build ==============

FLUTTER_DIR = admin_flutter/apps/admin
PROJECT_ROOT = ..

build-flutter:
	cd $(FLUTTER_DIR) && flutter build web --release
	@echo "Build complete: $(FLUTTER_DIR)/build/web"

build-controller:
	docker build -f docker/Dockerfile.controller -t qaspa/controller:latest $(PROJECT_ROOT)
	docker restart qaspa_controller || true

build-miner:
	docker build -f docker/Dockerfile.miner_agent -t qaspa/miner-agent:latest $(PROJECT_ROOT)
	docker tag qaspa/miner-agent:latest qaspa/miner_agent:latest

build-all: build-flutter build-controller build-miner

# ============== Development ==============

dev:
	cd $(FLUTTER_DIR) && flutter run -d chrome --web-port=3000

# Run controller locally with hot reload (requires: cargo install cargo-watch)
dev-controller:
	@echo "Stopping Docker controller if running..."
	@docker stop qaspa_controller 2>/dev/null || true
	@pkill -f testnet-controller 2>/dev/null || true
	@sleep 1
	@echo "Starting controller with hot reload..."
	@echo "Press Ctrl+C to stop"
	cd controller && \
	RUST_LOG=info \
	HTTP_BIND=127.0.0.1:8081 \
	STATIC_DIR=$(PWD)/admin_flutter/apps/admin/build/web \
	DATABASE_URL=postgres://qaspa:qaspa_dev@localhost:5434/qaspa_testnet \
	NETWORK_NAME=qaspa_testnet_net \
	CLUSTER_LABEL=testnet_local \
	SEED_GRPC_URL=grpc://localhost:16210 \
	LOCAL_MODE=true \
	cargo watch -x run

# Run controller locally without hot reload (faster startup)
run-controller:
	@docker stop qaspa_controller 2>/dev/null || true
	@pkill -f testnet-controller 2>/dev/null || true
	@sleep 1
	cd controller && \
	RUST_LOG=info \
	HTTP_BIND=127.0.0.1:8081 \
	STATIC_DIR=$(PWD)/admin_flutter/apps/admin/build/web \
	DATABASE_URL=postgres://qaspa:qaspa_dev@localhost:5434/qaspa_testnet \
	NETWORK_NAME=qaspa_testnet_net \
	CLUSTER_LABEL=testnet_local \
	SEED_GRPC_URL=grpc://localhost:16210 \
	LOCAL_MODE=true \
	cargo run

gen:
	cd admin_flutter && dart run build_runner build --delete-conflicting-outputs

clean:
	cd $(FLUTTER_DIR) && flutter clean
	cd admin_flutter && dart run build_runner clean

# ============== Cleanup ==============

# Remove all blockchain data (stops nodes first)
clean-chain:
	@echo "Stopping all services..."
	@$(COMPOSE) --profile controller down
	@$(COMPOSE) down
	@echo "Removing blockchain data volumes..."
	@docker volume rm compose_seed_data compose_peer1_data compose_peer2_data 2>/dev/null || true
	@echo "Done! Run 'make up' to start fresh."

# Full cleanup - remove all data including postgres
clean-all:
	@echo "Stopping all services..."
	@$(COMPOSE) --profile controller down
	@$(COMPOSE) down -v
	@echo "Removing all volumes..."
	@docker volume rm compose_seed_data compose_peer1_data compose_peer2_data compose_postgres_data 2>/dev/null || true
	@echo "Done! Run 'make up' to start fresh."

# ============== Cluster ==============

API_URL = http://localhost:8081/api/v1
MINER_COUNT ?= 3

status:
	@echo "=== Nodes ===" && curl -s $(API_URL)/nodes | jq '.[] | {name, status, metrics: .metrics | {blocks: .block_count, synced: .is_synced}}'
	@echo "\n=== Miners ===" && curl -s $(API_URL)/miners | jq '.[] | {name, status, hashrate, blocks_found}'

add-miner:
	@curl -s -X POST $(API_URL)/miners \
		-H "Content-Type: application/json" \
		-d '{"target_node": "$(shell curl -s $(API_URL)/nodes | jq -r '.[] | select(.name == "seed") | .id')", "payout_address": "kaspadev:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6cqmuuq4", "threads": 2}' | jq

add-miners:
	@echo "Adding $(MINER_COUNT) miners for DAG on seed node..."
	@SEED_ID=$$(curl -s $(API_URL)/nodes | jq -r '.[] | select(.name == "seed") | .id'); \
	for i in $$(seq 1 $(MINER_COUNT)); do \
		echo "Starting miner $$i..."; \
		curl -s -X POST $(API_URL)/miners \
			-H "Content-Type: application/json" \
			-d "{\"target_node\": \"$$SEED_ID\", \"payout_address\": \"kaspadev:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6cqmuuq4\", \"threads\": 2}" | jq -r '.name // .error'; \
		sleep 1; \
	done
	@echo "Done! Added $(MINER_COUNT) miners"

up-dag: up
	@echo "Waiting for cluster to be ready..."
	@sleep 10
	@$(MAKE) add-miners

# ============== Pool ==============

# Start nodes + pool together
up-pool:
	$(COMPOSE) up -d
	$(COMPOSE) --profile pool up -d
	@echo ""
	@echo "Testnet + Pool started!"
	@echo "  Stratum: localhost:3333 (VarDiff)"
	@echo "  Stratum: localhost:3334 (Static 512)"
	@echo "  Stratum: localhost:3335 (Static 2048)"
	@echo "  Pool health: http://localhost:9300/health"
	@echo "  Pool metrics: http://localhost:9300/metrics"
	@echo ""
	@echo "Connect miners: stratum+tcp://YOUR_ADDRESS@localhost:3333"

# Start pool only (if nodes already running)
pool-up:
	$(COMPOSE) --profile pool up -d
	@echo "Pool started on Stratum port 3333"

# Stop pool only
pool-down:
	$(COMPOSE) --profile pool stop pool-app pool-redis pool-db

# Pool logs
pool-logs:
	docker logs -f qaspa_pool_app

# Pool status
pool-status:
	@echo "=== Pool Health ===" && curl -s http://localhost:9300/health 2>/dev/null | jq . || echo "Pool not running"

# Stop everything (nodes + pool + controller + miners)
down-all:
	$(COMPOSE) --profile pool --profile miner --profile controller down

# Build pool image
build-pool:
	docker build -f ../repos/qaspa-pool/docker/Dockerfile -t qaspa/pool:latest ../repos/qaspa-pool
	@echo "Pool image built: qaspa/pool:latest"

# ============== Miner Mode Switching ==============

# Start miner in pool mode (requires pool to be running)
miner-pool:
	@echo "Starting miner in pool mode..."
	$(COMPOSE) --profile miner stop miner 2>/dev/null || true
	MINING_MODE=pool $(COMPOSE) --profile miner up -d miner
	@echo "Miner now mining via pool (Stratum)"
	@echo "Check logs: make logs-miner"

# Start miner in solo mode (default)
miner-solo:
	@echo "Starting miner in solo mode..."
	$(COMPOSE) --profile miner stop miner 2>/dev/null || true
	MINING_MODE=solo $(COMPOSE) --profile miner up -d miner
	@echo "Miner now solo mining via gRPC"
	@echo "Check logs: make logs-miner"

# Start nodes + pool + miner (pool mode)
up-full:
	$(COMPOSE) up -d
	$(COMPOSE) --profile pool up -d
	@echo "Waiting for pool to be ready..."
	@sleep 10
	MINING_MODE=pool $(COMPOSE) --profile miner up -d miner
	@echo ""
	@echo "Full stack started!"
	@echo "  Nodes: seed, peer-1, peer-2"
	@echo "  Pool: Stratum on :3333"
	@echo "  Miner: pool mode"
	@echo ""
	@echo "Commands:"
	@echo "  make logs-miner    - View miner logs"
	@echo "  make pool-logs     - View pool logs"
	@echo "  make pool-status   - Check pool health"

# ============== Pool Dev Mode (Hot Reload) ==============

# Start infrastructure for local pool development
# Runs: nodes + pool-db + pool-redis (NO pool-app)
pool-dev-infra:
	$(COMPOSE) up -d
	$(COMPOSE) --profile pool-dev up -d pool-db pool-redis
	@echo ""
	@echo "Infrastructure ready for local pool development!"
	@echo ""
	@echo "Nodes:"
	@echo "  wRPC: ws://localhost:17210"
	@echo "  gRPC: grpc://localhost:16210"
	@echo ""
	@echo "Database:"
	@echo "  PostgreSQL: localhost:5435"
	@echo "  User: qaspa_pool / Password: pool_secret"
	@echo ""
	@echo "Redis: localhost:6379"
	@echo ""
	@echo "Now run the pool locally:"
	@echo "  cd ../repos/qaspa-pool"
	@echo "  cp .env.local .env"
	@echo "  npm run dev"

# Stop dev infrastructure
pool-dev-down:
	$(COMPOSE) --profile pool-dev stop pool-db pool-redis
	$(COMPOSE) down

# Full dev mode: infra + local pool
pool-dev:
	@echo "Starting dev infrastructure..."
	@$(MAKE) pool-dev-infra
	@echo ""
	@echo "Starting pool with hot reload..."
	@echo "Press Ctrl+C to stop"
	@cd ../repos/qaspa-pool && npm run dev

# Reset pool database (useful during development)
pool-dev-reset-db:
	docker exec -i qaspa_pool_db psql -U qaspa_pool -d qaspa_pool -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
	docker exec -i qaspa_pool_db psql -U qaspa_pool -d qaspa_pool < ../repos/qaspa-pool/sql/init.sql
	@echo "Database reset complete"

# ============== E2E Tests ==============

# Run E2E tests with devnet (starts infra if not running)
e2e-test:
	@echo "Starting E2E tests..."
	@$(MAKE) pool-status >/dev/null 2>&1 || $(MAKE) up-pool
	@echo "Waiting for pool to be ready..."
	@sleep 10
	@cd ../repos/qaspa-pool && npm run test:e2e
	@echo "E2E tests complete"

# Run E2E tests without restarting infra
e2e-test-only:
	@cd ../repos/qaspa-pool && npm run test:e2e

# Run pipeline tests only (faster)
e2e-test-pipeline:
	@cd ../repos/qaspa-pool && npm run test:e2e:pipeline

# Run integration tests only (requires miner)
e2e-test-integration:
	@cd ../repos/qaspa-pool && npm run test:e2e:integration

# Run E2E tests with fresh database
e2e-test-fresh:
	@$(MAKE) pool-dev-reset-db
	@$(MAKE) e2e-test-only

# Run full E2E with miner (longest, most comprehensive)
e2e-test-full:
	@echo "Starting full E2E test suite..."
	@$(MAKE) up-full
	@echo "Waiting for full stack to be ready..."
	@sleep 20
	@cd ../repos/qaspa-pool && npm run test:e2e
	@echo "Full E2E tests complete"

# ============== E2E Multi-Miner Tests ==============

# Start nodes + pool + 3 e2e miners
e2e-miners-up:
	$(COMPOSE) up -d
	$(COMPOSE) --profile pool up -d
	@echo "Waiting for pool to be ready..."
	@sleep 10
	$(COMPOSE) --profile e2e-miners up -d
	@echo ""
	@echo "3 E2E miners started in pool mode!"
	@echo "  miner-1: kaspadev:qztest1..."
	@echo "  miner-2: kaspadev:qztest2..."
	@echo "  miner-3: kaspadev:qztest3..."
	@echo ""
	@echo "Commands:"
	@echo "  make e2e-miners-logs   - View miner logs"
	@echo "  make e2e-miners-status - Check miner stats"
	@echo "  make e2e-real-test     - Run E2E tests"

# Stop e2e miners
e2e-miners-down:
	$(COMPOSE) --profile e2e-miners stop

# View e2e miner logs
e2e-miners-logs:
	docker logs -f qaspa_miner_1 qaspa_miner_2 qaspa_miner_3 2>&1

# Check miner stats
e2e-miners-status:
	@echo "=== Miner Stats ==="
	@curl -s http://localhost:9091/stats 2>/dev/null | jq . || echo "miner-1: not available"
	@curl -s http://localhost:9092/stats 2>/dev/null | jq . || echo "miner-2: not available"
	@curl -s http://localhost:9093/stats 2>/dev/null | jq . || echo "miner-3: not available"
	@echo ""
	@echo "=== Pool Stats ==="
	@curl -s http://localhost:9300/api/v1/stats 2>/dev/null | jq '{connectedMiners, hashrate, blocksFound}' || echo "Pool not available"

# Run real E2E test with multiple Docker miners
e2e-real-test:
	@echo "Starting E2E test with real Docker miners..."
	@$(MAKE) e2e-miners-up
	@echo "Waiting for miners to start mining..."
	@sleep 30
	@cd ../repos/qaspa-pool && npm run test:e2e:real-miners
	@echo "E2E test complete"
