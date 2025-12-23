# Qaspa Testnet Development Makefile
# Usage: make <target>

.PHONY: help up down restart logs build-flutter build-controller build-miner dev dev-controller run-controller clean clean-chain clean-all add-miner add-miners up-dag status gen

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
