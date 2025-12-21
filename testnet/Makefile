# Qaspa Testnet Development Makefile
# Usage: make <target>

.PHONY: help up down restart logs build-flutter build-controller build-miner dev clean

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
	@echo "    make gen             - Run build_runner for code generation"
	@echo "    make clean           - Clean Flutter build artifacts"
	@echo ""
	@echo "  Cluster:"
	@echo "    make status          - Show cluster status via API"
	@echo "    make add-miner       - Add a test miner"
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

gen:
	cd admin_flutter && dart run build_runner build --delete-conflicting-outputs

clean:
	cd $(FLUTTER_DIR) && flutter clean
	cd admin_flutter && dart run build_runner clean

# ============== Cluster ==============

API_URL = http://localhost:8081/api/v1

status:
	@echo "=== Nodes ===" && curl -s $(API_URL)/nodes | jq '.[] | {name, status, metrics: .metrics | {blocks: .block_count, synced: .is_synced}}'
	@echo "\n=== Miners ===" && curl -s $(API_URL)/miners | jq '.[] | {name, status, hashrate, blocks_found}'

add-miner:
	@curl -s -X POST $(API_URL)/miners \
		-H "Content-Type: application/json" \
		-d '{"target_node": "$(shell curl -s $(API_URL)/nodes | jq -r '.[0].id')", "payout_address": "kaspadev:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq6cqmuuq4", "threads": 2}' | jq
