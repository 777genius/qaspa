# Этап 1: Репозитории и Remotes

## Цель

Создать структуру репозиториев в `repos/`, настроить upstream remotes для форков, подготовить базовые конфиги.

---

## Структура

```
qaspa/
├── repos/
│   ├── qaspa-explorer-ng/      # Форк lAmeR1/kaspa-explorer-ng
│   ├── qaspa-db-filler/        # Форк lAmeR1/kaspa-db-filler
│   ├── qaspa-socket-server/    # Форк lAmeR1/kaspa-socket-server
│   └── qaspa-rest-api/         # Новый Go REST API
└── docs/
    └── explorer/               # Эта документация
```

---

## Команды для создания

### 1. Создать папку repos

```bash
cd /path/to/qaspa
mkdir -p repos
```

### 2. Форк kaspa-explorer-ng

```bash
cd repos

# Клонируем upstream
git clone https://github.com/lAmeR1/kaspa-explorer-ng.git qaspa-explorer-ng
cd qaspa-explorer-ng

# Настраиваем remotes
git remote rename origin upstream
# Добавьте ваш fork remote (пример):
git remote add origin git@github.com:<your-org>/qaspa-explorer-ng.git

# Создаём ветку для Qaspa (опционально)
git checkout -b qaspa/main
# Пушить имеет смысл только если remote настроен
# git push -u origin qaspa/main

cd ..
```

### 3. Форк kaspa-db-filler

```bash
git clone https://github.com/lAmeR1/kaspa-db-filler.git qaspa-db-filler
cd qaspa-db-filler

git remote rename origin upstream
git remote add origin git@github.com:<your-org>/qaspa-db-filler.git

git checkout -b qaspa/main
# git push -u origin qaspa/main

cd ..
```

### 4. Форк kaspa-socket-server

```bash
git clone https://github.com/lAmeR1/kaspa-socket-server.git qaspa-socket-server
cd qaspa-socket-server

git remote rename origin upstream
git remote add origin git@github.com:<your-org>/qaspa-socket-server.git

git checkout -b qaspa/main
# git push -u origin qaspa/main

cd ..
```

### 5. Создать новый qaspa-rest-api

```bash
mkdir qaspa-rest-api
cd qaspa-rest-api

# Инициализируем Go модуль
go mod init github.com/<your-org>/qaspa-rest-api

# Создаём базовую структуру
mkdir -p cmd/api
mkdir -p internal/{platform,shared,features}
mkdir -p db/migrations
mkdir -p scripts

# Инициализируем git
git init
git remote add origin git@github.com:<your-org>/qaspa-rest-api.git

cd ..
```

---

## Структура qaspa-rest-api

```
qaspa-rest-api/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── platform/
│   │   ├── config/
│   │   │   └── config.go
│   │   ├── httpserver/
│   │   │   ├── server.go
│   │   │   └── middleware.go
│   │   ├── db/
│   │   │   └── postgres.go
│   │   └── observability/
│   │       ├── logger.go
│   │       └── metrics.go
│   ├── shared/
│   │   ├── pagination/
│   │   │   └── pagination.go
│   │   ├── errors/
│   │   │   └── errors.go
│   │   └── types/
│   │       ├── hash.go
│   │       ├── address.go
│   │       └── script.go
│   └── features/
│       ├── blocks/
│       │   ├── domain/
│       │   ├── app/
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   └── transport/
│       │       └── http/
│       ├── transactions/
│       ├── addresses/
│       ├── stealth/
│       ├── mldsa/
│       ├── info/
│       └── search/
├── db/
│   └── migrations/
│       ├── 001_init_schema.sql
│       └── ...
├── scripts/
│   └── generate.sh
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── go.mod
├── go.sum
└── README.md
```

---

## Базовые файлы для qaspa-rest-api

### go.mod

```go
module github.com/<your-org>/qaspa-rest-api

go 1.22

require (
    github.com/go-chi/chi/v5 v5.0.12
    github.com/jackc/pgx/v5 v5.5.5
    github.com/pressly/goose/v3 v3.19.2
    go.uber.org/zap v1.27.0
    github.com/caarlos0/env/v10 v10.0.0
)
```

### Makefile

```makefile
.PHONY: build run test migrate lint

build:
	go build -o bin/api ./cmd/api

run:
	go run ./cmd/api

test:
	go test -v -race ./...

migrate-up:
	goose -dir db/migrations postgres "$(DATABASE_URL)" up

migrate-down:
	goose -dir db/migrations postgres "$(DATABASE_URL)" down

migrate-status:
	goose -dir db/migrations postgres "$(DATABASE_URL)" status

lint:
	golangci-lint run

generate:
	sqlc generate

docker-build:
	docker build -t qaspa-rest-api .

docker-run:
	docker run -p 8080:8080 --env-file .env qaspa-rest-api
```

### .env.example

```bash
# Database
DATABASE_URL=postgres://qaspa:qaspa@localhost:5432/qaspa?sslmode=disable

# Server
PORT=8080
LOG_LEVEL=debug

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000

# Rate limiting
RATE_LIMIT_RPS=100
RATE_LIMIT_BURST=200
```

### Dockerfile

```dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /api ./cmd/api

# Runtime
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata

COPY --from=builder /api /api
COPY --from=builder /app/db/migrations /migrations

EXPOSE 8080

ENTRYPOINT ["/api"]
```

---

## .gitignore для repos/

Добавить в корневой `.gitignore` проекта qaspa:

```gitignore
# Explorer repos (managed separately)
/repos/
```

Или если хотим держать как submodules — настроить `.gitmodules`.

---

## README для каждого репо

### qaspa-explorer-ng/README.md (добавить секцию)

```markdown
## Qaspa Fork

This is a fork of kaspa-explorer-ng adapted for Qaspa network.

### Changes from upstream
- Make API_BASE and SOCKET_URL configurable (remove hardcoded `api.kaspa.org`)
- Support for stealth outputs display
- Support for MLDSA address type
- Nullable script_public_key_address handling

### Local Development

```bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env.local
# Edit .env.local with your API endpoints

# Run dev server
npm run dev
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| VITE_API_BASE | REST API base URL | http://localhost:8080 |
| VITE_SOCKET_URL | WebSocket server URL | http://localhost:8081 |

Note: для Docker production-сборки (см. этап 8) переменные `VITE_*` должны быть доступны **на этапе `npm run build`** (через build args/ENV), иначе значения “впекаются” дефолтами.
```

---

## Checklist готовности этапа

- [ ] Папка `repos/` создана
- [ ] qaspa-explorer-ng склонирован, remotes настроены
- [ ] qaspa-db-filler склонирован, remotes настроены
- [ ] qaspa-socket-server склонирован, remotes настроены
- [ ] qaspa-rest-api инициализирован с базовой структурой
- [ ] Каждый репо имеет README с инструкцией запуска
- [ ] .env.example файлы созданы
- [ ] Makefile/scripts готовы для локальной разработки

