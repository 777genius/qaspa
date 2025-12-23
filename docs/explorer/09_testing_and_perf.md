# Этап 9: Testing и Performance

## Цель

Обеспечить качество и производительность Qaspa Explorer через:
- Unit tests для бизнес-логики
- Integration tests с реальной БД
- Contract tests для API
- Performance/load testing

---

## Стратегия тестирования

```
┌─────────────────────────────────────────────────────────────────┐
│                    Testing Pyramid                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                        ┌─────────┐                               │
│                        │   E2E   │  ← Минимум, критические paths │
│                       ┌┴─────────┴┐                              │
│                       │Integration│  ← DB, HTTP, gRPC            │
│                      ┌┴───────────┴┐                             │
│                      │    Unit     │  ← Много, быстро            │
│                      └─────────────┘                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Unit Tests (Go REST API)

### Структура тестов

```
internal/features/blocks/
├── app/
│   ├── get_block.go
│   └── get_block_test.go      # Unit test
├── adapters/
│   └── postgres/
│       ├── repository.go
│       └── repository_test.go  # Integration test
└── transport/
    └── http/
        ├── handler.go
        └── handler_test.go     # HTTP handler test
```

### Пример: Use Case Unit Test

```go
// internal/features/blocks/app/get_block_test.go
package app_test

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/app"
	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/domain"
	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
)

// Mock repository
type mockBlockRepo struct {
	mock.Mock
}

func (m *mockBlockRepo) GetByHash(ctx context.Context, hash types.BlockHash) (*domain.Block, error) {
	args := m.Called(ctx, hash)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.Block), args.Error(1)
}

func (m *mockBlockRepo) ListRecent(ctx context.Context, limit, offset int) ([]*domain.Block, error) {
	args := m.Called(ctx, limit, offset)
	return args.Get(0).([]*domain.Block), args.Error(1)
}

func TestGetBlockUseCase_Success(t *testing.T) {
	// Arrange
	repo := new(mockBlockRepo)
	uc := app.NewGetBlockUseCase(repo)

	hash, err := types.ParseHash("abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234")
	require.NoError(t, err)
	expectedBlock := &domain.Block{
		Hash:     hash,
		DAAScore: 12345,
		BlueScore: 12340,
	}

	repo.On("GetByHash", mock.Anything, hash).Return(expectedBlock, nil)

	// Act
	result, err := uc.Execute(context.Background(), app.GetBlockInput{
		Hash: hash.String(),
	})

	// Assert
	require.NoError(t, err)
	assert.Equal(t, expectedBlock.DAAScore, result.DAAScore)
	repo.AssertExpectations(t)
}

func TestGetBlockUseCase_NotFound(t *testing.T) {
	// Arrange
	repo := new(mockBlockRepo)
	uc := app.NewGetBlockUseCase(repo)

	hash, err := types.ParseHash("0000000000000000000000000000000000000000000000000000000000000000")
	require.NoError(t, err)
	repo.On("GetByHash", mock.Anything, hash).Return(nil, nil)

	// Act
	_, err := uc.Execute(context.Background(), app.GetBlockInput{
		Hash: hash.String(),
	})

	// Assert
	assert.ErrorIs(t, err, app.ErrBlockNotFound)
}

func TestGetBlockUseCase_InvalidHash(t *testing.T) {
	// Arrange
	repo := new(mockBlockRepo)
	uc := app.NewGetBlockUseCase(repo)

	// Act
	_, err := uc.Execute(context.Background(), app.GetBlockInput{
		Hash: "invalid-hash",
	})

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid hash")
}

func TestGetBlockUseCase_RepositoryError(t *testing.T) {
	// Arrange
	repo := new(mockBlockRepo)
	uc := app.NewGetBlockUseCase(repo)

	hash, err := types.ParseHash("abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234")
	require.NoError(t, err)
	repo.On("GetByHash", mock.Anything, hash).Return(nil, errors.New("db connection failed"))

	// Act
	_, err := uc.Execute(context.Background(), app.GetBlockInput{
		Hash: hash.String(),
	})

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "db connection failed")
}
```

### Пример: Stealth Use Case Test

```go
// internal/features/stealth/app/scan_outputs_test.go
package app_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/<your-org>/qaspa-rest-api/internal/features/stealth/app"
	"github.com/<your-org>/qaspa-rest-api/internal/features/stealth/domain"
)

type mockStealthRepo struct {
	mock.Mock
}

func (m *mockStealthRepo) ScanByViewTag(ctx context.Context, viewTag uint8, fromDaa int64, limit int) ([]*domain.StealthOutput, error) {
	args := m.Called(ctx, viewTag, fromDaa, limit)
	return args.Get(0).([]*domain.StealthOutput), args.Error(1)
}

func TestScanOutputsUseCase_Success(t *testing.T) {
	// Arrange
	repo := new(mockStealthRepo)
	uc := app.NewScanOutputsUseCase(repo)

	expectedOutputs := []*domain.StealthOutput{
		{
			TransactionID:    "tx1",
			OutputIndex:      0,
			ViewTag:          42,
			EphemeralPubkey:  "02aaa...",
			DestinationPubkey: "03bbb...",
			Amount:           100000000,
			BlockDAAScore:    1000,
		},
		{
			TransactionID:    "tx2",
			OutputIndex:      1,
			ViewTag:          42,
			EphemeralPubkey:  "02ccc...",
			DestinationPubkey: "03ddd...",
			Amount:           200000000,
			BlockDAAScore:    1001,
		},
	}

	repo.On("ScanByViewTag", mock.Anything, uint8(42), int64(0), 1000).Return(expectedOutputs, nil)

	// Act
	result, err := uc.Execute(context.Background(), app.ScanOutputsInput{
		ViewTag: 42,
		FromDaa: 0,
		Limit:   1000,
	})

	// Assert
	require.NoError(t, err)
	assert.Len(t, result.Outputs, 2)
	assert.Equal(t, uint8(42), result.Outputs[0].ViewTag)
}

func TestScanOutputsUseCase_InvalidViewTag(t *testing.T) {
	repo := new(mockStealthRepo)
	uc := app.NewScanOutputsUseCase(repo)

	// ViewTag > 255
	_, err := uc.Execute(context.Background(), app.ScanOutputsInput{
		ViewTag: 256,
	})

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "view_tag must be 0-255")
}
```

---

## Integration Tests (PostgreSQL)

### Testcontainers Setup

```go
// internal/testutil/postgres.go
package testutil

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

type TestDB struct {
	Container testcontainers.Container
	Pool      *pgxpool.Pool
	DSN       string
}

func NewTestDB(t *testing.T) *TestDB {
	t.Helper()

	ctx := context.Background()

	// Start PostgreSQL container
	container, err := postgres.RunContainer(ctx,
		testcontainers.WithImage("postgres:15-alpine"),
		postgres.WithDatabase("qaspa_test"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(5*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("Failed to start postgres container: %v", err)
	}

	// Get connection string
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("Failed to get connection string: %v", err)
	}

	// Connect
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("Failed to connect to test database: %v", err)
	}

	// Run migrations
	if err := runMigrations(ctx, pool); err != nil {
		t.Fatalf("Failed to run migrations: %v", err)
	}

	return &TestDB{
		Container: container,
		Pool:      pool,
		DSN:       dsn,
	}
}

func (db *TestDB) Close(t *testing.T) {
	t.Helper()
	db.Pool.Close()
	if err := db.Container.Terminate(context.Background()); err != nil {
		t.Logf("Failed to terminate container: %v", err)
	}
}

func (db *TestDB) Truncate(t *testing.T, tables ...string) {
	t.Helper()
	ctx := context.Background()
	for _, table := range tables {
		_, err := db.Pool.Exec(ctx, fmt.Sprintf("TRUNCATE TABLE %s CASCADE", table))
		if err != nil {
			t.Fatalf("Failed to truncate table %s: %v", table, err)
		}
	}
}
```

### Repository Integration Test

```go
// internal/features/blocks/adapters/postgres/repository_test.go
package postgres_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/adapters/postgres"
	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
	"github.com/<your-org>/qaspa-rest-api/internal/testutil"
)

func TestBlockRepository_GetByHash(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	// Setup
	db := testutil.NewTestDB(t)
	defer db.Close(t)

	repo := postgres.NewRepository(db.Pool)
	ctx := context.Background()

	// Insert test block
	blockHash := "abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234"
	_, err := db.Pool.Exec(ctx, `
		INSERT INTO blocks (hash, version, daa_score, blue_score, blue_work, timestamp,
			hash_merkle_root, accepted_id_merkle_root, utxo_commitment, bits, nonce, is_chain_block)
		VALUES ($1, 1, 12345, 12340, 'abc', $2, 'merkle', 'accepted', 'utxo', 123, '456', true)
	`, blockHash, time.Now().UnixMilli())
	require.NoError(t, err)

	// Test
	hash, _ := types.ParseHash(blockHash)
	block, err := repo.GetByHash(ctx, hash)

	// Assert
	require.NoError(t, err)
	require.NotNil(t, block)
	assert.Equal(t, uint64(12345), block.DAAScore)
	assert.True(t, block.IsChainBlock)
}

func TestBlockRepository_ListRecent(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	db := testutil.NewTestDB(t)
	defer db.Close(t)

	repo := postgres.NewRepository(db.Pool)
	ctx := context.Background()

	// Insert multiple blocks
	for i := 0; i < 5; i++ {
		hash := fmt.Sprintf("%064d", i)
		_, err := db.Pool.Exec(ctx, `
			INSERT INTO blocks (hash, version, daa_score, blue_score, blue_work, timestamp,
				hash_merkle_root, accepted_id_merkle_root, utxo_commitment, bits, nonce, is_chain_block)
			VALUES ($1, 1, $2, $3, 'abc', $4, 'merkle', 'accepted', 'utxo', 123, '456', true)
		`, hash, 1000+i, 999+i, time.Now().UnixMilli())
		require.NoError(t, err)
	}

	// Test
	blocks, err := repo.ListRecent(ctx, 3, 0)

	// Assert
	require.NoError(t, err)
	assert.Len(t, blocks, 3)
	// Should be ordered by daa_score DESC
	assert.Greater(t, blocks[0].DAAScore, blocks[1].DAAScore)
}
```

### Stealth Repository Integration Test

```go
// internal/features/stealth/adapters/postgres/repository_test.go
package postgres_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/<your-org>/qaspa-rest-api/internal/features/stealth/adapters/postgres"
	"github.com/<your-org>/qaspa-rest-api/internal/testutil"
)

func TestStealthRepository_ScanByViewTag(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	db := testutil.NewTestDB(t)
	defer db.Close(t)

	repo := postgres.NewRepository(db.Pool)
	ctx := context.Background()

	// Insert test stealth outputs
	outputs := []struct {
		txID    string
		index   int
		viewTag int
		daa     int64
	}{
		{"tx1", 0, 42, 1000},
		{"tx2", 1, 42, 1001},
		{"tx3", 0, 43, 1002}, // different view tag
		{"tx4", 2, 42, 1003},
	}

	for _, o := range outputs {
		_, err := db.Pool.Exec(ctx, `
			INSERT INTO stealth_outputs (
				transaction_id, output_index, view_tag, ephemeral_pubkey, 
				destination_pubkey, amount, block_hash, block_daa_score, block_time
			) VALUES ($1, $2, $3, 'ephemeral', 'dest', 100000000, 'block', $4, 1234567890)
		`, o.txID, o.index, o.viewTag, o.daa)
		require.NoError(t, err)
	}

	// Test: scan for view_tag=42
	results, err := repo.ScanByViewTag(ctx, 42, 0, 100)

	require.NoError(t, err)
	assert.Len(t, results, 3) // Only view_tag=42

	// Test: scan with from_daa
	results, err = repo.ScanByViewTag(ctx, 42, 1001, 100)

	require.NoError(t, err)
	assert.Len(t, results, 2) // daa >= 1001
}
```

---

## Contract Tests (HTTP API)

### Golden file testing

```go
// internal/features/transactions/transport/http/handler_test.go
package http_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	txhttp "github.com/<your-org>/qaspa-rest-api/internal/features/transactions/transport/http"
)

func TestGetTransaction_ResponseFormat(t *testing.T) {
	// Setup handler with mock use case
	handler := txhttp.NewHandler(mockGetTxUC, mockSearchTxUC)
	
	r := chi.NewRouter()
	handler.RegisterRoutes(r)
	
	// Request
	req := httptest.NewRequest("GET", "/transactions/abc123?resolve_previous_outpoints=light", nil)
	rec := httptest.NewRecorder()
	
	r.ServeHTTP(rec, req)
	
	// Assert status
	assert.Equal(t, http.StatusOK, rec.Code)
	
	// Golden file comparison
	goldenFile := filepath.Join("testdata", "get_transaction_response.golden.json")
	
	if *update {
		// Update golden file
		os.WriteFile(goldenFile, rec.Body.Bytes(), 0644)
	}
	
	expected, err := os.ReadFile(goldenFile)
	require.NoError(t, err)
	
	// Compare JSON (ignore whitespace)
	var expectedJSON, actualJSON interface{}
	json.Unmarshal(expected, &expectedJSON)
	json.Unmarshal(rec.Body.Bytes(), &actualJSON)
	
	assert.Equal(t, expectedJSON, actualJSON)
}
```

### Testdata (Golden files)

```json
// internal/features/transactions/transport/http/testdata/get_transaction_response.golden.json
{
  "transaction_id": "abc123...",
  "hash": "abc123...",
  "mass": "1234",
  "block_time": 1703001234567,
  "is_accepted": true,
  "inputs": [
    {
      "index": 0,
      "previous_outpoint_hash": "prev...",
      "previous_outpoint_index": "0",
      "previous_outpoint_address": "qaspa:...",
      "previous_outpoint_amount": 100000000
    }
  ],
  "outputs": [
    {
      "index": 0,
      "amount": 50000000,
      "script_public_key_address": "qaspa:...",
      "script_public_key_type": "pubkey"
    },
    {
      "index": 1,
      "amount": 49990000,
      "script_public_key_address": null,
      "script_public_key_type": "stealth",
      "stealth_data": {
        "view_tag": 42,
        "ephemeral_pubkey": "02...",
        "destination_pubkey": "03..."
      }
    }
  ]
}
```

---

## Performance Testing

### Benchmark tests

```go
// internal/features/blocks/adapters/postgres/repository_bench_test.go
package postgres_test

import (
	"context"
	"testing"

	"github.com/<your-org>/qaspa-rest-api/internal/features/blocks/adapters/postgres"
	"github.com/<your-org>/qaspa-rest-api/internal/shared/types"
	"github.com/<your-org>/qaspa-rest-api/internal/testutil"
)

func BenchmarkBlockRepository_GetByHash(b *testing.B) {
	db := testutil.NewBenchDB(b)
	defer db.Close(b)
	
	repo := postgres.NewRepository(db.Pool)
	ctx := context.Background()
	
	// Setup: insert block
	hash := "abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234"
	// ... insert block
	
	parsedHash, _ := types.ParseHash(hash)
	
	b.ResetTimer()
	
	for i := 0; i < b.N; i++ {
		_, err := repo.GetByHash(ctx, parsedHash)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkStealthRepository_ScanByViewTag(b *testing.B) {
	db := testutil.NewBenchDB(b)
	defer db.Close(b)
	
	repo := stealthPostgres.NewRepository(db.Pool)
	ctx := context.Background()
	
	// Setup: insert 10000 stealth outputs
	for i := 0; i < 10000; i++ {
		// ... insert stealth output with random view_tag
	}
	
	b.ResetTimer()
	
	for i := 0; i < b.N; i++ {
		_, err := repo.ScanByViewTag(ctx, uint8(i%256), 0, 100)
		if err != nil {
			b.Fatal(err)
		}
	}
}
```

### Load testing с k6

```javascript
// tests/load/api_load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up
    { duration: '1m', target: 100 },   // Stay at 100 users
    { duration: '30s', target: 200 },  // Spike
    { duration: '1m', target: 100 },   // Back to normal
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'], // 95% of requests < 200ms
    errors: ['rate<0.01'],             // Error rate < 1%
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

// Sample block hashes for testing
const BLOCK_HASHES = [
  'abc123...',
  'def456...',
  // ...
];

const TX_IDS = [
  'tx123...',
  'tx456...',
  // ...
];

export default function () {
  // Test: GET /blocks/:hash
  {
    const hash = BLOCK_HASHES[Math.floor(Math.random() * BLOCK_HASHES.length)];
    const res = http.get(`${BASE_URL}/blocks/${hash}`);
    
    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 100ms': (r) => r.timings.duration < 100,
    });
    
    errorRate.add(!success);
  }
  
  sleep(0.1);
  
  // Test: GET /transactions/:id
  {
    const txid = TX_IDS[Math.floor(Math.random() * TX_IDS.length)];
    const res = http.get(`${BASE_URL}/transactions/${txid}?resolve_previous_outpoints=light`);
    
    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 200ms': (r) => r.timings.duration < 200,
    });
    
    errorRate.add(!success);
  }
  
  sleep(0.1);
  
  // Test: GET /stealth/scan
  {
    const viewTag = Math.floor(Math.random() * 256);
    const res = http.get(`${BASE_URL}/stealth/scan?view_tag=${viewTag}&limit=100`);
    
    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 300ms': (r) => r.timings.duration < 300,
    });
    
    errorRate.add(!success);
  }
  
  sleep(0.5);
}
```

### Запуск load tests

```bash
# Install k6
brew install k6  # macOS
# or
docker pull grafana/k6

# Run load test
k6 run tests/load/api_load_test.js

# With custom API URL
k6 run -e API_URL=http://localhost:8080 tests/load/api_load_test.js

# Save results
k6 run --out json=results.json tests/load/api_load_test.js
```

---

## Makefile команды для тестов

```makefile
# Makefile
.PHONY: test test-unit test-integration test-bench test-coverage test-load

# All tests
test:
	go test -v -race ./...

# Unit tests only (fast)
test-unit:
	go test -v -short ./...

# Integration tests (requires Docker)
test-integration:
	go test -v -run Integration ./...

# Benchmarks
test-bench:
	go test -bench=. -benchmem ./...

# Coverage
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

# Load tests
test-load:
	k6 run tests/load/api_load_test.js

# Contract tests (update golden files)
test-golden-update:
	go test -v ./... -update
```

---

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [main, qaspa/main]
  pull_request:
    branches: [main, qaspa/main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      
      - name: Run unit tests
        run: go test -v -short -race ./...
  
  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: qaspa_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      
      - name: Run migrations
        run: |
          go install github.com/pressly/goose/v3/cmd/goose@latest
          goose -dir db/migrations postgres "postgresql://test:test@localhost:5432/qaspa_test?sslmode=disable" up
      
      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/qaspa_test?sslmode=disable
        run: go test -v -run Integration ./...
  
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      
      - name: Generate coverage
        run: go test -coverprofile=coverage.out ./...
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: coverage.out
```

---

## Performance Targets

| Endpoint | Target p95 | Target p99 | Current |
|----------|-----------|-----------|---------|
| GET /blocks/:hash | <50ms | <100ms | TBD |
| GET /transactions/:id | <100ms | <200ms | TBD |
| GET /addresses/:addr/balance | <50ms | <100ms | TBD |
| GET /addresses/:addr/full-transactions | <200ms | <500ms | TBD |
| GET /stealth/scan | <200ms | <400ms | TBD |

---

## Checklist готовности этапа

- [ ] Unit tests покрывают все use cases
- [ ] Integration tests с testcontainers работают
- [ ] Contract tests с golden files созданы
- [ ] Benchmark tests написаны
- [ ] Load tests с k6 подготовлены
- [ ] CI/CD pipeline настроен
- [ ] Coverage > 70%
- [ ] Performance targets определены
- [ ] Все тесты проходят локально
- [ ] Все тесты проходят в CI

