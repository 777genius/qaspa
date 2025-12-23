# Этап 4: Go REST API Architecture

## Цель

Спроектировать и реализовать Go REST API по принципам DDD, Clean Architecture, feature-based (vertical slices).

---

## Принципы архитектуры

### DDD (Domain-Driven Design)

- **Domain Layer**: чистые бизнес-сущности без зависимостей от инфраструктуры
- **Ubiquitous Language**: термины из предметной области (Block, Transaction, StealthOutput)
- **Bounded Contexts**: каждая фича — изолированный контекст

### Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      HTTP Handlers                          │  ← Frameworks & Drivers
├─────────────────────────────────────────────────────────────┤
│                      Use Cases / App                        │  ← Application Business Rules
├─────────────────────────────────────────────────────────────┤
│                      Domain Entities                        │  ← Enterprise Business Rules
├─────────────────────────────────────────────────────────────┤
│                      Repositories (interfaces)              │  ← Interface Adapters
├─────────────────────────────────────────────────────────────┤
│                      PostgreSQL Adapters                    │  ← Frameworks & Drivers
└─────────────────────────────────────────────────────────────┘

Зависимости направлены ВНУТРЬ (к Domain)
```

### Feature-based (Vertical Slices)

Код группируется по фичам, не по типам файлов:

```
internal/features/
├── blocks/           # Всё про блоки
│   ├── domain/
│   ├── app/
│   ├── adapters/
│   └── transport/
├── transactions/     # Всё про транзакции
├── addresses/        # Балансы/UTXO/история
├── stealth/          # Stealth-специфика
├── mldsa/            # MLDSA anchors/delegations
├── info/             # Network info
└── search/           # Поиск
```

---

## Структура проекта

```
repos/qaspa-rest-api/
├── cmd/
│   └── api/
│       └── main.go                 # Composition Root
│
├── internal/
│   ├── platform/                   # Инфраструктурные пакеты
│   │   ├── config/
│   │   │   └── config.go
│   │   ├── httpserver/
│   │   │   ├── server.go
│   │   │   ├── middleware.go
│   │   │   └── response.go
│   │   ├── db/
│   │   │   └── postgres.go
│   │   └── observability/
│   │       ├── logger.go
│   │       └── metrics.go
│   │
│   ├── shared/                     # Shared Kernel
│   │   ├── types/
│   │   │   ├── hash.go
│   │   │   ├── address.go
│   │   │   ├── txid.go
│   │   │   └── script.go
│   │   ├── pagination/
│   │   │   └── pagination.go
│   │   └── errors/
│   │       └── errors.go
│   │
│   └── features/                   # Feature Modules
│       ├── blocks/
│       │   ├── domain/
│       │   │   ├── block.go
│       │   │   └── errors.go
│       │   ├── app/
│       │   │   ├── get_block.go
│       │   │   ├── list_blocks.go
│       │   │   └── ports.go
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   │       ├── repository.go
│       │   │       └── queries.sql
│       │   └── transport/
│       │       └── http/
│       │           ├── handler.go
│       │           ├── dto.go
│       │           └── routes.go
│       │
│       ├── transactions/
│       │   ├── domain/
│       │   │   ├── transaction.go
│       │   │   ├── input.go
│       │   │   ├── output.go
│       │   │   └── errors.go
│       │   ├── app/
│       │   │   ├── get_transaction.go
│       │   │   ├── search_transactions.go
│       │   │   └── ports.go
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   │       └── repository.go
│       │   └── transport/
│       │       └── http/
│       │           ├── handler.go
│       │           └── dto.go
│       │
│       ├── addresses/
│       │   ├── domain/
│       │   │   ├── balance.go
│       │   │   ├── utxo.go
│       │   │   └── errors.go
│       │   ├── app/
│       │   │   ├── get_balance.go
│       │   │   ├── get_utxos.go
│       │   │   ├── get_transactions.go
│       │   │   └── ports.go
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   │       └── repository.go
│       │   └── transport/
│       │       └── http/
│       │           ├── handler.go
│       │           └── dto.go
│       │
│       ├── stealth/
│       │   ├── domain/
│       │   │   ├── stealth_output.go
│       │   │   └── errors.go
│       │   ├── app/
│       │   │   ├── get_view_tags.go
│       │   │   ├── scan_outputs.go
│       │   │   ├── list_utxos.go
│       │   │   └── ports.go
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   │       └── repository.go
│       │   └── transport/
│       │       └── http/
│       │           ├── handler.go
│       │           └── dto.go
│       │
│       ├── mldsa/
│       │   ├── domain/
│       │   │   ├── anchor.go
│       │   │   ├── delegation.go
│       │   │   └── errors.go
│       │   ├── app/
│       │   │   ├── list_anchors.go
│       │   │   ├── get_delegations.go
│       │   │   └── ports.go
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   │       └── repository.go
│       │   └── transport/
│       │       └── http/
│       │           └── handler.go
│       │
│       ├── info/
│       │   ├── domain/
│       │   │   └── network_info.go
│       │   ├── app/
│       │   │   ├── get_blockdag.go
│       │   │   ├── get_coinsupply.go
│       │   │   └── ports.go
│       │   ├── adapters/
│       │   │   └── postgres/
│       │   │       └── repository.go
│       │   └── transport/
│       │       └── http/
│       │           └── handler.go
│       │
│       └── search/
│           ├── app/
│           │   └── search.go
│           └── transport/
│               └── http/
│                   └── handler.go
│
├── db/
│   ├── migrations/
│   │   ├── 001_init_schema.sql
│   │   └── ...
│   └── sqlc/
│       ├── sqlc.yaml
│       └── queries/
│           ├── blocks.sql
│           ├── transactions.sql
│           └── ...
│
├── scripts/
│   ├── generate.sh
│   └── migrate.sh
│
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── go.mod
├── go.sum
└── README.md
```

---

## Технологический стек

| Компонент | Технология | Обоснование |
|-----------|------------|-------------|
| HTTP Router | `chi` | Простой, идиоматичный, middleware-friendly |
| Database | `pgxpool` | Высокая производительность, connection pooling |
| SQL Generation | `sqlc` | Type-safe запросы, compile-time проверка |
| Migrations | `goose` | Простота, SQL миграции |
| Logging | `zap` | Структурированное логирование, производительность |
| Config | `env` | Простота, 12-factor |
| Metrics | `prometheus` | Стандарт индустрии |
| Testing | `testify` + `testcontainers` | Удобство, реальная БД в тестах |

---

## Код: Основные компоненты

### cmd/api/main.go (Composition Root)

```go
package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/<your-org>/qaspa-rest-api/internal/platform/config"
	"github.com/<your-org>/qaspa-rest-api/internal/platform/db"
	"github.com/<your-org>/qaspa-rest-api/internal/platform/httpserver"
	"github.com/<your-org>/qaspa-rest-api/internal/platform/observability"

	// Features
	blocksHttp "github.com/<your-org>/qaspa-rest-api/internal/features/blocks/transport/http"
	blocksApp "github.com/<your-org>/qaspa-rest-api/internal/features/blocks/app"
	blocksRepo "github.com/<your-org>/qaspa-rest-api/internal/features/blocks/adapters/postgres"

	txHttp "github.com/<your-org>/qaspa-rest-api/internal/features/transactions/transport/http"
	txApp "github.com/<your-org>/qaspa-rest-api/internal/features/transactions/app"
	txRepo "github.com/<your-org>/qaspa-rest-api/internal/features/transactions/adapters/postgres"

	addrHttp "github.com/<your-org>/qaspa-rest-api/internal/features/addresses/transport/http"
	addrApp "github.com/<your-org>/qaspa-rest-api/internal/features/addresses/app"
	addrRepo "github.com/<your-org>/qaspa-rest-api/internal/features/addresses/adapters/postgres"

	stealthHttp "github.com/<your-org>/qaspa-rest-api/internal/features/stealth/transport/http"
	stealthApp "github.com/<your-org>/qaspa-rest-api/internal/features/stealth/app"
	stealthRepo "github.com/<your-org>/qaspa-rest-api/internal/features/stealth/adapters/postgres"

	infoHttp "github.com/<your-org>/qaspa-rest-api/internal/features/info/transport/http"
	infoApp "github.com/<your-org>/qaspa-rest-api/internal/features/info/app"
	infoRepo "github.com/<your-org>/qaspa-rest-api/internal/features/info/adapters/postgres"
)

func main() {
	// 1. Load config
	cfg, err := config.Load()
	if err != nil {
		panic(err)
	}

	// 2. Setup logger
	logger := observability.NewLogger(cfg.LogLevel)
	defer logger.Sync()

	// 3. Connect to database
	pool, err := db.NewPostgresPool(context.Background(), cfg.DatabaseURL)
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}
	defer pool.Close()

	// 4. Wire up features
	// Blocks
	blocksRepository := blocksRepo.NewRepository(pool)
	getBlockUC := blocksApp.NewGetBlockUseCase(blocksRepository)
	listBlocksUC := blocksApp.NewListBlocksUseCase(blocksRepository)
	blocksHandler := blocksHttp.NewHandler(getBlockUC, listBlocksUC)

	// Transactions
	txRepository := txRepo.NewRepository(pool)
	getTxUC := txApp.NewGetTransactionUseCase(txRepository)
	searchTxUC := txApp.NewSearchTransactionsUseCase(txRepository)
	txHandler := txHttp.NewHandler(getTxUC, searchTxUC)

	// Addresses
	addrRepository := addrRepo.NewRepository(pool)
	getBalanceUC := addrApp.NewGetBalanceUseCase(addrRepository)
	getUtxosUC := addrApp.NewGetUtxosUseCase(addrRepository)
	getAddrTxUC := addrApp.NewGetTransactionsUseCase(addrRepository)
	addrHandler := addrHttp.NewHandler(getBalanceUC, getUtxosUC, getAddrTxUC)

	// Stealth
	stealthRepository := stealthRepo.NewRepository(pool)
	getViewTagsUC := stealthApp.NewGetViewTagsUseCase(stealthRepository)
	scanOutputsUC := stealthApp.NewScanOutputsUseCase(stealthRepository)
	listStealthUtxosUC := stealthApp.NewListUtxosUseCase(stealthRepository)
	stealthHandler := stealthHttp.NewHandler(getViewTagsUC, scanOutputsUC, listStealthUtxosUC)

	// Info
	infoRepository := infoRepo.NewRepository(pool)
	getBlockdagUC := infoApp.NewGetBlockdagUseCase(infoRepository)
	getCoinSupplyUC := infoApp.NewGetCoinSupplyUseCase(infoRepository)
	infoHandler := infoHttp.NewHandler(getBlockdagUC, getCoinSupplyUC)

	// 5. Setup HTTP server
	server := httpserver.New(cfg, logger)

	// Register routes
	blocksHandler.RegisterRoutes(server.Router())
	txHandler.RegisterRoutes(server.Router())
	addrHandler.RegisterRoutes(server.Router())
	stealthHandler.RegisterRoutes(server.Router())
	infoHandler.RegisterRoutes(server.Router())

	// 6. Start server
	go func() {
		if err := server.Start(); err != nil {
			logger.Fatal("Server failed", zap.Error(err))
		}
	}()

	// 7. Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")
	if err := server.Shutdown(context.Background()); err != nil {
		logger.Error("Server shutdown failed", zap.Error(err))
	}
}
```

### internal/platform/config/config.go

```go
package config

import (
	"github.com/caarlos0/env/v10"
)

type Config struct {
	// Server
	Port     int    `env:"PORT" envDefault:"8080"`
	LogLevel string `env:"LOG_LEVEL" envDefault:"info"`

	// Database
	DatabaseURL string `env:"DATABASE_URL,required"`

	// CORS
	CORSAllowedOrigins []string `env:"CORS_ALLOWED_ORIGINS" envSeparator:"," envDefault:"*"`

	// Rate limiting
	RateLimitRPS   int `env:"RATE_LIMIT_RPS" envDefault:"100"`
	RateLimitBurst int `env:"RATE_LIMIT_BURST" envDefault:"200"`
}

func Load() (*Config, error) {
	cfg := &Config{}
	if err := env.Parse(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}
```

### internal/platform/httpserver/server.go

```go
package httpserver

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"go.uber.org/zap"

	"github.com/<your-org>/qaspa-rest-api/internal/platform/config"
)

type Server struct {
	router *chi.Mux
	server *http.Server
	logger *zap.Logger
	cfg    *config.Config
}

func New(cfg *config.Config, logger *zap.Logger) *Server {
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(LoggerMiddleware(logger))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.CORSAllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Content-Type"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	// Health check
	r.Get("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("pong"))
	})

	return &Server{
		router: r,
		logger: logger,
		cfg:    cfg,
	}
}

func (s *Server) Router() *chi.Mux {
	return s.router
}

func (s *Server) Start() error {
	s.server = &http.Server{
		Addr:         fmt.Sprintf(":%d", s.cfg.Port),
		Handler:      s.router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	s.logger.Info("Starting server", zap.Int("port", s.cfg.Port))
	return s.server.ListenAndServe()
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.server.Shutdown(ctx)
}
```

### internal/shared/types/hash.go

```go
package types

import (
	"encoding/hex"
	"fmt"
)

// Hash represents a 32-byte hash (block hash, tx id, etc.)
type Hash [32]byte

func (h Hash) String() string {
	return hex.EncodeToString(h[:])
}

func (h Hash) IsZero() bool {
	return h == Hash{}
}

func ParseHash(s string) (Hash, error) {
	if len(s) != 64 {
		return Hash{}, fmt.Errorf("invalid hash length: %d", len(s))
	}

	bytes, err := hex.DecodeString(s)
	if err != nil {
		return Hash{}, fmt.Errorf("invalid hex: %w", err)
	}

	var h Hash
	copy(h[:], bytes)
	return h, nil
}

// TxID is an alias for transaction ID
type TxID = Hash

// BlockHash is an alias for block hash
type BlockHash = Hash
```

### internal/features/blocks/domain/block.go

```go
package domain

import (
	"time"

	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
)

// Block represents a block in the DAG
type Block struct {
	Hash                  types.BlockHash
	Version               uint16
	DAAScore              uint64
	BlueScore             uint64
	BlueWork              string
	PruningPoint          *types.BlockHash
	Timestamp             time.Time
	HashMerkleRoot        types.Hash
	AcceptedIDMerkleRoot  types.Hash
	UTXOCommitment        types.Hash
	Bits                  uint64
	Nonce                 uint64
	Difficulty            float64
	SelectedParentHash    *types.BlockHash
	IsChainBlock          bool
	ParentHashes          []types.BlockHash
	TransactionIDs        []types.TxID
	MinerAddress          *string
	MinerInfo             *string
	Color                 *string
}

// TransactionCount returns the number of transactions in the block
func (b *Block) TransactionCount() int {
	return len(b.TransactionIDs)
}
```

### internal/features/blocks/app/get_block.go

```go
package app

import (
	"context"
	"errors"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/domain"
	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
)

var ErrBlockNotFound = errors.New("block not found")

// BlockRepository defines the interface for block data access
type BlockRepository interface {
	GetByHash(ctx context.Context, hash types.BlockHash) (*domain.Block, error)
	ListRecent(ctx context.Context, limit, offset int) ([]*domain.Block, error)
}

// GetBlockUseCase handles getting a single block
type GetBlockUseCase struct {
	repo BlockRepository
}

func NewGetBlockUseCase(repo BlockRepository) *GetBlockUseCase {
	return &GetBlockUseCase{repo: repo}
}

type GetBlockInput struct {
	Hash         string
	IncludeColor bool
}

func (uc *GetBlockUseCase) Execute(ctx context.Context, input GetBlockInput) (*domain.Block, error) {
	hash, err := types.ParseHash(input.Hash)
	if err != nil {
		return nil, err
	}

	block, err := uc.repo.GetByHash(ctx, hash)
	if err != nil {
		return nil, err
	}
	if block == nil {
		return nil, ErrBlockNotFound
	}

	return block, nil
}
```

### internal/features/blocks/adapters/postgres/repository.go

```go
package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/app"
	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/domain"
	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

// Ensure interface compliance
var _ app.BlockRepository = (*Repository)(nil)

func (r *Repository) GetByHash(ctx context.Context, hash types.BlockHash) (*domain.Block, error) {
	// Примечание: доменные типы (Hash/time.Time) не сканируются напрямую из pgx.
	// Сканы делаем в примитивы (string/int64), затем валидируем и маппим в domain.
	// В реальной реализации предпочтительно использовать sqlc и отдельный mapper слой.

	row := r.pool.QueryRow(ctx, `
		SELECT hash, version, daa_score, blue_score, blue_work, timestamp, is_chain_block
		FROM blocks
		WHERE hash = $1
	`, hash.String())

	var hashStr string
	var version int16
	var daaScore, blueScore int64
	var blueWork string
	var timestampMs int64
	var isChain bool

	if err := row.Scan(&hashStr, &version, &daaScore, &blueScore, &blueWork, &timestampMs, &isChain); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	parsedHash, err := types.ParseHash(hashStr)
	if err != nil {
		return nil, err
	}

	return &domain.Block{
		Hash:         parsedHash,
		Version:      uint16(version),
		DAAScore:     uint64(daaScore),
		BlueScore:    uint64(blueScore),
		BlueWork:     blueWork,
		Timestamp:    time.UnixMilli(timestampMs),
		IsChainBlock: isChain,
	}, nil
}

func (r *Repository) ListRecent(ctx context.Context, limit, offset int) ([]*domain.Block, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT hash, version, daa_score, blue_score, timestamp, is_chain_block
		FROM blocks
		ORDER BY daa_score DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocks []*domain.Block
	for rows.Next() {
		var hashStr string
		var version int16
		var daaScore, blueScore int64
		var timestampMs int64
		var isChain bool

		if err := rows.Scan(&hashStr, &version, &daaScore, &blueScore, &timestampMs, &isChain); err != nil {
			return nil, err
		}

		parsedHash, err := types.ParseHash(hashStr)
		if err != nil {
			return nil, err
		}

		blocks = append(blocks, &domain.Block{
			Hash:         parsedHash,
			Version:      uint16(version),
			DAAScore:     uint64(daaScore),
			BlueScore:    uint64(blueScore),
			Timestamp:    time.UnixMilli(timestampMs),
			IsChainBlock: isChain,
		})
	}

	return blocks, nil
}
```

### internal/features/blocks/transport/http/handler.go

```go
package http

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/app"
	"github.com/<your-org>/qaspa-rest-api/internal/platform/httpserver"
)

type Handler struct {
	getBlock   *app.GetBlockUseCase
	listBlocks *app.ListBlocksUseCase
}

func NewHandler(getBlock *app.GetBlockUseCase, listBlocks *app.ListBlocksUseCase) *Handler {
	return &Handler{
		getBlock:   getBlock,
		listBlocks: listBlocks,
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/blocks/{hash}", h.GetBlock)
	r.Get("/blocks", h.ListBlocks)
}

func (h *Handler) GetBlock(w http.ResponseWriter, r *http.Request) {
	hash := chi.URLParam(r, "hash")
	includeColor := r.URL.Query().Get("includeColor") == "true"

	block, err := h.getBlock.Execute(r.Context(), app.GetBlockInput{
		Hash:         hash,
		IncludeColor: includeColor,
	})

	if errors.Is(err, app.ErrBlockNotFound) {
		httpserver.NotFound(w, "Block not found")
		return
	}
	if err != nil {
		httpserver.InternalError(w, err)
		return
	}

	dto := BlockToDTO(block)
	httpserver.JSON(w, http.StatusOK, dto)
}

func (h *Handler) ListBlocks(w http.ResponseWriter, r *http.Request) {
	// Parse pagination
	limit, offset := httpserver.ParsePagination(r, 20, 0)

	blocks, err := h.listBlocks.Execute(r.Context(), app.ListBlocksInput{
		Limit:  limit,
		Offset: offset,
	})

	if err != nil {
		httpserver.InternalError(w, err)
		return
	}

	dtos := make([]*BlockDTO, len(blocks))
	for i, b := range blocks {
		dtos[i] = BlockToDTO(b)
	}

	httpserver.JSON(w, http.StatusOK, dtos)
}
```

### internal/features/blocks/transport/http/dto.go

```go
package http

import (
	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/domain"
)

type BlockDTO struct {
	Header      BlockHeaderDTO      `json:"header"`
	VerboseData BlockVerboseDataDTO `json:"verboseData"`
	Extra       *BlockExtraDTO      `json:"extra,omitempty"`
}

type BlockHeaderDTO struct {
	Version               uint16   `json:"version"`
	HashMerkleRoot        string   `json:"hashMerkleRoot"`
	AcceptedIDMerkleRoot  string   `json:"acceptedIdMerkleRoot"`
	UTXOCommitment        string   `json:"utxoCommitment"`
	Timestamp             string   `json:"timestamp"`
	Bits                  uint64   `json:"bits"`
	Nonce                 string   `json:"nonce"`
	DAAScore              string   `json:"daaScore"`
	BlueWork              string   `json:"blueWork"`
	BlueScore             string   `json:"blueScore"`
	PruningPoint          string   `json:"pruningPoint,omitempty"`
	Parents               []ParentDTO `json:"parents"`
}

type ParentDTO struct {
	ParentHashes []string `json:"parentHashes"`
}

type BlockVerboseDataDTO struct {
	Hash               string   `json:"hash"`
	Difficulty         float64  `json:"difficulty"`
	SelectedParentHash string   `json:"selectedParentHash,omitempty"`
	TransactionIDs     []string `json:"transactionIds"`
	IsChainBlock       bool     `json:"isChainBlock"`
}

type BlockExtraDTO struct {
	Color        string `json:"color,omitempty"`
	MinerAddress string `json:"minerAddress,omitempty"`
	MinerInfo    string `json:"minerInfo,omitempty"`
}

func BlockToDTO(b *domain.Block) *BlockDTO {
	parentHashes := make([]string, len(b.ParentHashes))
	for i, ph := range b.ParentHashes {
		parentHashes[i] = ph.String()
	}

	txIDs := make([]string, len(b.TransactionIDs))
	for i, tid := range b.TransactionIDs {
		txIDs[i] = tid.String()
	}

	dto := &BlockDTO{
		Header: BlockHeaderDTO{
			Version:              b.Version,
			HashMerkleRoot:       b.HashMerkleRoot.String(),
			AcceptedIDMerkleRoot: b.AcceptedIDMerkleRoot.String(),
			UTXOCommitment:       b.UTXOCommitment.String(),
			Timestamp:            fmt.Sprintf("%d", b.Timestamp.UnixMilli()),
			Bits:                 b.Bits,
			Nonce:                fmt.Sprintf("%d", b.Nonce),
			DAAScore:             fmt.Sprintf("%d", b.DAAScore),
			BlueWork:             b.BlueWork,
			BlueScore:            fmt.Sprintf("%d", b.BlueScore),
			Parents: []ParentDTO{
				{ParentHashes: parentHashes},
			},
		},
		VerboseData: BlockVerboseDataDTO{
			Hash:           b.Hash.String(),
			Difficulty:     b.Difficulty,
			TransactionIDs: txIDs,
			IsChainBlock:   b.IsChainBlock,
		},
	}

	if b.Color != nil || b.MinerAddress != nil {
		dto.Extra = &BlockExtraDTO{}
		if b.Color != nil {
			dto.Extra.Color = *b.Color
		}
		if b.MinerAddress != nil {
			dto.Extra.MinerAddress = *b.MinerAddress
		}
		if b.MinerInfo != nil {
			dto.Extra.MinerInfo = *b.MinerInfo
		}
	}

	return dto
}
```

---

## sqlc Configuration

### db/sqlc/sqlc.yaml

```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "queries/"
    schema: "../migrations/"
    gen:
      go:
        package: "sqlcgen"
        out: "../../internal/sqlcgen"
        sql_package: "pgx/v5"
        emit_json_tags: true
        emit_db_tags: true
        emit_prepared_queries: false
        emit_interface: true
```

### db/sqlc/queries/blocks.sql

```sql
-- name: GetBlockByHash :one
SELECT 
    hash, version, daa_score, blue_score, blue_work,
    pruning_point, timestamp, hash_merkle_root,
    accepted_id_merkle_root, utxo_commitment,
    bits, nonce, difficulty, selected_parent_hash,
    is_chain_block, miner_address, miner_info, color
FROM blocks
WHERE hash = $1;

-- name: ListRecentBlocks :many
SELECT 
    hash, version, daa_score, blue_score, timestamp,
    is_chain_block, miner_address, color
FROM blocks
ORDER BY daa_score DESC
LIMIT $1 OFFSET $2;

-- name: GetBlockParents :many
SELECT parent_hash, parent_level
FROM block_parents
WHERE block_hash = $1
ORDER BY parent_level;

-- name: GetBlockTransactionIDs :many
SELECT transaction_id
FROM transaction_blocks
WHERE block_hash = $1;
```

---

## Тестирование

### Unit test пример

```go
// internal/features/blocks/app/get_block_test.go
package app_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/app"
	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/domain"
	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
)

type MockBlockRepository struct {
	mock.Mock
}

func (m *MockBlockRepository) GetByHash(ctx context.Context, hash types.BlockHash) (*domain.Block, error) {
	args := m.Called(ctx, hash)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.Block), args.Error(1)
}

func (m *MockBlockRepository) ListRecent(ctx context.Context, limit, offset int) ([]*domain.Block, error) {
	args := m.Called(ctx, limit, offset)
	return args.Get(0).([]*domain.Block), args.Error(1)
}

func TestGetBlockUseCase_Execute_Success(t *testing.T) {
	// Arrange
	repo := new(MockBlockRepository)
	uc := app.NewGetBlockUseCase(repo)

	hash, _ := types.ParseHash("abcd1234" + strings.Repeat("0", 56))
	expectedBlock := &domain.Block{
		Hash:     hash,
		DAAScore: 12345,
	}

	repo.On("GetByHash", mock.Anything, hash).Return(expectedBlock, nil)

	// Act
	block, err := uc.Execute(context.Background(), app.GetBlockInput{
		Hash: hash.String(),
	})

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, expectedBlock.DAAScore, block.DAAScore)
	repo.AssertExpectations(t)
}

func TestGetBlockUseCase_Execute_NotFound(t *testing.T) {
	// Arrange
	repo := new(MockBlockRepository)
	uc := app.NewGetBlockUseCase(repo)

	hash, _ := types.ParseHash("abcd1234" + strings.Repeat("0", 56))
	repo.On("GetByHash", mock.Anything, hash).Return(nil, nil)

	// Act
	_, err := uc.Execute(context.Background(), app.GetBlockInput{
		Hash: hash.String(),
	})

	// Assert
	assert.ErrorIs(t, err, app.ErrBlockNotFound)
}
```

---

## Checklist готовности этапа

- [ ] Структура проекта создана
- [ ] go.mod с зависимостями настроен
- [ ] Platform пакеты реализованы (config, httpserver, db, logger)
- [ ] Shared kernel реализован (types, pagination, errors)
- [ ] Feature `blocks` полностью реализован (domain, app, adapters, transport)
- [ ] Feature `transactions` полностью реализован
- [ ] Feature `addresses` полностью реализован
- [ ] Feature `stealth` полностью реализован
- [ ] Feature `info` полностью реализован
- [ ] sqlc генерация настроена
- [ ] Unit tests написаны для use cases
- [ ] Integration tests написаны для repositories
- [ ] API работает локально
- [ ] Makefile команды работают

