# Этап 8: Local Development / Docker Compose

## Цель

Создать единый `docker-compose.yml` для локальной разработки всего стека Qaspa Explorer.

---

## Архитектура

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Docker Network                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐      │
│  │ explorer │    │ rest-api │    │  socket  │    │ db-filler│      │
│  │  :3000   │───>│  :8080   │    │  :8081   │    │          │      │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘      │
│       │               │               │               │             │
│       │               │               │               │             │
│       │               ▼               │               │             │
│       │         ┌──────────┐          │               │             │
│       │         │ postgres │<─────────┼───────────────┤             │
│       │         │  :5432   │          │               │             │
│       │         └──────────┘          │               │             │
│       │                               │               │             │
│       │                               ▼               ▼             │
│       │                         ┌──────────┐                        │
│       └─────────────────────────│  qaspad  │                        │
│                                 │  :16110  │                        │
│                                 │  :16111  │                        │
│                                 └──────────┘                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Docker Compose

### docker-compose.yml (в корне `repos/`)

Важно: ниже — **шаблон**. Мы НЕ завязываемся на “магические” внешние образы и команды, которых может не быть.
Для `qaspad` есть два варианта:

1) **Сборка из этого монорепо** (рекомендуется): использовать локальный Dockerfile из `qaspa/docker/` и нужные параметры запуска.
2) **Внешний образ**: если у вас уже есть готовый image, подставьте его сами.

```yaml
version: '3.8'

services:
  # ============================================================
  # PostgreSQL Database
  # ============================================================
  postgres:
    image: postgres:15-alpine
    container_name: qaspa-postgres
    environment:
      POSTGRES_USER: qaspa
      POSTGRES_PASSWORD: qaspa
      POSTGRES_DB: qaspa
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U qaspa"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - qaspa-network

  # ============================================================
  # Qaspad Node (for local testing)
  # ============================================================
  qaspad:
    # Вариант A (рекомендуется): собрать image локально из текущего монорепо `qaspa`
    # Путь и Dockerfile нужно уточнить под ваш текущий docker пайплайн.
    build:
      context: ..
      dockerfile: docker/Dockerfile.kaspad
    # Вариант B: если вы используете внешний образ, замените build на image:
    # image: <your-registry>/qaspad:<tag>
    container_name: qaspa-node
    command:
      # Параметры запуска уточняем под реальный `qaspad` в вашем репо.
      # Критично для эксплорера:
      # - включить RPC (gRPC/wRPC по необходимости)
      # - включить utxoindex (для некоторых API/сканов)
      - --utxoindex
      - --rpclisten=0.0.0.0:16110
    volumes:
      - qaspad_data:/app/data
    ports:
      - "16110:16110"  # gRPC
      - "16111:16111"  # P2P
      - "17110:17110"  # wRPC (Borsh)
    # Healthcheck убран из шаблона: внутри образа может не быть grpcurl/nc.
    # Готовый healthcheck добавим после того как зафиксируем образ `qaspad`
    # и набор утилит в нём.
    networks:
      - qaspa-network

  # ============================================================
  # Database Indexer (fills PostgreSQL from qaspad)
  # ============================================================
  db-filler:
    build:
      context: ./qaspa-db-filler
      dockerfile: Dockerfile
    container_name: qaspa-db-filler
    environment:
      KASPAD_HOST: qaspad:16110
      DATABASE_URL: postgresql://qaspa:qaspa@postgres:5432/qaspa
      ENABLE_STEALTH_INDEXING: "true"
      ENABLE_UTXO_TABLE: "true"
      ENABLE_ADDRESS_TX: "true"
      BATCH_SIZE: "100"
      LOG_LEVEL: info
    depends_on:
      postgres:
        condition: service_healthy
      # Для qaspad в шаблоне healthcheck не задан, поэтому используем service_started.
      qaspad:
        condition: service_started
    restart: unless-stopped
    networks:
      - qaspa-network

  # ============================================================
  # Go REST API
  # ============================================================
  rest-api:
    build:
      context: ./qaspa-rest-api
      dockerfile: Dockerfile
    container_name: qaspa-rest-api
    environment:
      DATABASE_URL: postgresql://qaspa:qaspa@postgres:5432/qaspa
      PORT: "8080"
      LOG_LEVEL: debug
      CORS_ALLOWED_ORIGINS: "http://localhost:3000,http://127.0.0.1:3000"
      RATE_LIMIT_RPS: "100"
      RATE_LIMIT_BURST: "200"
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/ping"]
      interval: 10s
      timeout: 5s
      retries: 3
    restart: unless-stopped
    networks:
      - qaspa-network

  # ============================================================
  # Socket.IO Server (realtime events)
  # ============================================================
  socket-server:
    build:
      context: ./qaspa-socket-server
      dockerfile: Dockerfile
    container_name: qaspa-socket-server
    environment:
      KASPAD_HOST: qaspad:16110
      HOST: "0.0.0.0"
      PORT: "8081"
      CORS_ORIGINS: "http://localhost:3000,http://127.0.0.1:3000"
      EMIT_STEALTH_STATS: "true"
    ports:
      - "8081:8081"
    depends_on:
      qaspad:
        condition: service_started
    restart: unless-stopped
    networks:
      - qaspa-network

  # ============================================================
  # Frontend Explorer
  # ============================================================
  explorer:
    build:
      context: ./qaspa-explorer-ng
      dockerfile: Dockerfile
      args:
        # Важно: Vite/React Router подхватывает import.meta.env.* на этапе BUILD.
        # Для локальной прод-сборки в compose задаём VITE_* как build args.
        VITE_API_BASE: http://rest-api:8080
        VITE_SOCKET_URL: http://socket-server:8081
    container_name: qaspa-explorer
    ports:
      - "3000:3000"
    depends_on:
      - rest-api
      - socket-server
    networks:
      - qaspa-network

  # ============================================================
  # Optional: Adminer (DB management UI)
  # ============================================================
  adminer:
    image: adminer:latest
    container_name: qaspa-adminer
    ports:
      - "8888:8080"
    depends_on:
      - postgres
    networks:
      - qaspa-network
    profiles:
      - tools

volumes:
  postgres_data:
  qaspad_data:

networks:
  qaspa-network:
    driver: bridge
```

---

## Dockerfiles для каждого сервиса

### qaspa-rest-api/Dockerfile

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /api ./cmd/api

# Runtime stage
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata wget

WORKDIR /app

COPY --from=builder /api /app/api
COPY --from=builder /app/db/migrations /app/migrations

EXPOSE 8080

ENTRYPOINT ["/app/api"]
```

### qaspa-db-filler/Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "main.py"]
```

### qaspa-socket-server/Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8081

CMD ["python", "server.py"]
```

### qaspa-explorer-ng/Dockerfile

```dockerfile
# Важно: upstream `kaspa-explorer-ng` — это React Router (не Next.js).

FROM node:20-alpine AS development-dependencies-env
COPY . /app
WORKDIR /app
RUN npm ci

FROM node:20-alpine AS production-dependencies-env
COPY ./package.json package-lock.json /app/
WORKDIR /app
RUN npm ci --omit=dev

FROM node:20-alpine AS build-env
COPY . /app/
COPY --from=development-dependencies-env /app/node_modules /app/node_modules
WORKDIR /app
# Build-time env for Vite
ARG VITE_API_BASE
ARG VITE_SOCKET_URL
ENV VITE_API_BASE=$VITE_API_BASE
ENV VITE_SOCKET_URL=$VITE_SOCKET_URL
RUN npm run build

FROM node:20-alpine
COPY ./package.json package-lock.json /app/
COPY --from=production-dependencies-env /app/node_modules /app/node_modules
COPY --from=build-env /app/build /app/build
WORKDIR /app
CMD ["npm", "run", "start"]
```

---

## Makefile для удобства

### repos/Makefile

```makefile
.PHONY: up down logs restart clean build

# Start all services
up:
	docker compose up -d

# Start with build
up-build:
	docker compose up -d --build

# Stop all services
down:
	docker compose down

# View logs
logs:
	docker compose logs -f

logs-api:
	docker compose logs -f rest-api

logs-filler:
	docker compose logs -f db-filler

logs-socket:
	docker compose logs -f socket-server

logs-explorer:
	docker compose logs -f explorer

# Restart specific service
restart-api:
	docker compose restart rest-api

restart-filler:
	docker compose restart db-filler

restart-socket:
	docker compose restart socket-server

restart-explorer:
	docker compose restart explorer

# Clean volumes
clean:
	docker compose down -v
	docker volume rm qaspa_postgres_data qaspa_qaspad_data 2>/dev/null || true

# Build images
build:
	docker compose build

build-api:
	docker compose build rest-api

build-filler:
	docker compose build db-filler

build-socket:
	docker compose build socket-server

build-explorer:
	docker compose build explorer

# Database
db-shell:
	docker compose exec postgres psql -U qaspa -d qaspa

db-migrate:
	@echo "Миграции выполняем goose (будет добавлено в qaspa-rest-api на этапе реализации)."

# Status
status:
	docker compose ps

# Health check
health:
	@echo "=== REST API ==="
	@curl -s http://localhost:8080/ping || echo "REST API not responding"
	@echo "\n=== Socket Server ==="
	@curl -s http://localhost:8081/health || echo "Socket server not responding"
	@echo "\n=== Explorer ==="
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "Explorer not responding"

# Tools profile (Adminer)
tools:
	docker compose --profile tools up -d adminer
```

---

## Скрипты

### repos/scripts/init-dev.sh

```bash
#!/bin/bash
set -e

echo "=== Initializing Qaspa Explorer Development Environment ==="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "Error: Docker Compose is not installed"
    exit 1
fi

# Create .env if not exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << EOF
# Database
POSTGRES_USER=qaspa
POSTGRES_PASSWORD=qaspa
POSTGRES_DB=qaspa

# API
LOG_LEVEL=debug
CORS_ALLOWED_ORIGINS=http://localhost:3000

# Network
NETWORK=testnet
EOF
fi

# Pull/Build images
echo "Building images..."
docker compose build

# Start services
echo "Starting services..."
docker compose up -d

# Wait for postgres
echo "Waiting for PostgreSQL..."
until docker compose exec -T postgres pg_isready -U qaspa; do
    sleep 2
done

# Миграции: на раннем этапе запускаем вручную (см. docs/explorer/02_data_model_and_queries.md).
# Автоматизацию добавим после реализации `qaspa-rest-api` (goose в контейнере или отдельный migrate-job).

# Wait for qaspad sync
echo "Waiting for qaspad to sync..."
echo "(This may take a while on first run)"

# Health check
echo ""
echo "=== Services Status ==="
docker compose ps

echo ""
echo "=== Access Points ==="
echo "Explorer:      http://localhost:3000"
echo "REST API:      http://localhost:8080"
echo "Socket Server: http://localhost:8081"
echo "Adminer:       http://localhost:8888 (run 'make tools' first)"
echo ""
echo "Done! Happy developing!"
```

### repos/scripts/reset-db.sh

```bash
#!/bin/bash
set -e

echo "=== Resetting Database ==="
echo "WARNING: This will delete all indexed data!"
read -p "Are you sure? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Stop db-filler first
    docker compose stop db-filler
    
    # Drop and recreate database
    docker compose exec postgres psql -U qaspa -c "DROP DATABASE IF EXISTS qaspa;"
    docker compose exec postgres psql -U qaspa -c "CREATE DATABASE qaspa;"
    
    # Миграции выполняем вручную (см. docs/explorer/02_data_model_and_queries.md).
    
    # Restart db-filler
    docker compose start db-filler
    
    echo "Database reset complete!"
else
    echo "Cancelled."
fi
```

---

## Локальная разработка без Docker

Для разработки отдельных компонентов:

### REST API

```bash
cd qaspa-rest-api

# Установить зависимости
go mod download

# Запустить PostgreSQL локально или через Docker
docker run -d --name postgres \
    -e POSTGRES_USER=qaspa \
    -e POSTGRES_PASSWORD=qaspa \
    -e POSTGRES_DB=qaspa \
    -p 5432:5432 \
    postgres:15-alpine

# Настроить окружение
export DATABASE_URL="postgresql://qaspa:qaspa@localhost:5432/qaspa"
export PORT=8080
export LOG_LEVEL=debug

# Запустить миграции
goose -dir db/migrations postgres "$DATABASE_URL" up

# Запустить API
go run ./cmd/api
```

### Frontend

```bash
cd qaspa-explorer-ng

# Установить зависимости
npm install

# Настроить окружение
cp .env.example .env.local
# Edit .env.local

# Запустить dev server
npm run dev
```

### Socket Server

```bash
cd qaspa-socket-server

# Создать venv
python -m venv venv
source venv/bin/activate

# Установить зависимости
pip install -r requirements.txt

# Настроить окружение
export KASPAD_HOST=localhost:16110
export PORT=8081

# Запустить
python server.py
```

---

## Troubleshooting

### PostgreSQL не запускается

```bash
# Проверить логи
docker compose logs postgres

# Проверить занятость порта
lsof -i :5432

# Сбросить volume
docker compose down -v
docker volume rm qaspa_postgres_data
```

### qaspad не синхронизируется

```bash
# Проверить логи
docker compose logs qaspad

# Проверить подключение
docker compose exec qaspad grpcurl -plaintext localhost:16110 list

# Сбросить данные и пересинхронизироваться
docker compose down
docker volume rm qaspa_qaspad_data
docker compose up -d qaspad
```

### REST API не отвечает

```bash
# Проверить логи
docker compose logs rest-api

# Проверить подключение к БД
docker compose exec rest-api wget -q -O- http://localhost:8080/health

# Перезапустить
docker compose restart rest-api
```

### Frontend ошибки CORS

Проверить что `CORS_ALLOWED_ORIGINS` в `.env` включает origin фронтенда.

---

## Checklist готовности этапа

- [ ] docker-compose.yml создан и работает
- [ ] Все Dockerfile созданы
- [ ] Makefile с командами создан
- [ ] Init script создан и работает
- [ ] Все сервисы запускаются
- [ ] Health checks проходят
- [ ] Frontend открывается и показывает данные
- [ ] Realtime события приходят
- [ ] Документация по troubleshooting написана

