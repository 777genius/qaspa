# Этап 10: Security и Privacy

## Цель

Обеспечить безопасность и приватность Qaspa Explorer:
- Защита API от злоупотреблений
- Корректная обработка приватных данных
- Прозрачная коммуникация с пользователями о приватности

---

## Security Measures

### 1. Rate Limiting

#### Реализация в Go

```go
// internal/platform/httpserver/middleware/ratelimit.go
package middleware

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

type RateLimiter struct {
	visitors map[string]*visitor
	mu       sync.RWMutex
	r        rate.Limit
	b        int
}

type visitor struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

func NewRateLimiter(rps int, burst int) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*visitor),
		r:        rate.Limit(rps),
		b:        burst,
	}

	// Cleanup goroutine
	go rl.cleanup()

	return rl
}

func (rl *RateLimiter) getVisitor(ip string) *rate.Limiter {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[ip]
	if !exists {
		limiter := rate.NewLimiter(rl.r, rl.b)
		rl.visitors[ip] = &visitor{limiter, time.Now()}
		return limiter
	}

	v.lastSeen = time.Now()
	return v.limiter
}

func (rl *RateLimiter) cleanup() {
	for {
		time.Sleep(time.Minute)

		rl.mu.Lock()
		for ip, v := range rl.visitors {
			if time.Since(v.lastSeen) > 3*time.Minute {
				delete(rl.visitors, ip)
			}
		}
		rl.mu.Unlock()
	}
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getIP(r)
		limiter := rl.getVisitor(ip)

		if !limiter.Allow() {
			http.Error(w, "Too Many Requests", http.StatusTooManyRequests)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func getIP(r *http.Request) string {
	// Check X-Forwarded-For first (for reverse proxy)
	xff := r.Header.Get("X-Forwarded-For")
	if xff != "" {
		// Take first IP
		ips := strings.Split(xff, ",")
		return strings.TrimSpace(ips[0])
	}

	// Check X-Real-IP
	xri := r.Header.Get("X-Real-IP")
	if xri != "" {
		return xri
	}

	// Fall back to RemoteAddr
	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	return ip
}
```

#### Конфигурация лимитов

```go
// По типу endpoint'а
var rateLimits = map[string]struct{ rps, burst int }{
	"/blocks":        {100, 200},
	"/transactions":  {100, 200},
	"/addresses":     {50, 100},   // Более тяжёлые запросы
	"/stealth/scan":  {20, 50},    // Потенциально тяжёлый
	"/search":        {20, 50},
}
```

### 2. Input Validation

```go
// internal/shared/validation/validators.go
package validation

import (
	"fmt"
	"regexp"
)

var (
	hashRegex    = regexp.MustCompile(`^[a-fA-F0-9]{64}$`)
	addressRegex = regexp.MustCompile(`^(qaspa|qaspatest|qs|qstest):q[a-z0-9]{40,100}$`)
)

func ValidateHash(h string) error {
	if !hashRegex.MatchString(h) {
		return fmt.Errorf("invalid hash format: must be 64 hex characters")
	}
	return nil
}

func ValidateAddress(addr string) error {
	if !addressRegex.MatchString(addr) {
		return fmt.Errorf("invalid address format")
	}
	return nil
}

func ValidateViewTag(vt int) error {
	if vt < 0 || vt > 255 {
		return fmt.Errorf("view_tag must be 0-255")
	}
	return nil
}

func ValidatePagination(limit, offset int) error {
	if limit < 1 || limit > 100 {
		return fmt.Errorf("limit must be 1-100")
	}
	if offset < 0 {
		return fmt.Errorf("offset must be non-negative")
	}
	return nil
}
```

### 3. SQL Injection Prevention

**sqlc + pgx автоматически используют prepared statements.**

```sql
-- db/sqlc/queries/blocks.sql
-- Все параметры через $1, $2 - безопасно
-- name: GetBlockByHash :one
SELECT * FROM blocks WHERE hash = $1;

-- НИКОГДА не делать конкатенацию строк:
-- BAD: SELECT * FROM blocks WHERE hash = '" + userInput + "'"
```

### 4. CORS Configuration

```go
// internal/platform/httpserver/server.go
r.Use(cors.Handler(cors.Options{
	AllowedOrigins:   cfg.CORSAllowedOrigins,  // НЕ "*" в продакшене
	AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
	AllowedHeaders:   []string{"Accept", "Content-Type"},
	ExposedHeaders:   []string{"X-Request-ID"},
	AllowCredentials: false,  // Нет cookies
	MaxAge:           300,
}))
```

### 5. Security Headers

```go
// internal/platform/httpserver/middleware/security.go
package middleware

import "net/http"

func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Prevent clickjacking
		w.Header().Set("X-Frame-Options", "DENY")
		
		// Prevent MIME sniffing
		w.Header().Set("X-Content-Type-Options", "nosniff")
		
		// XSS protection
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		
		// Content Security Policy
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		
		// Referrer policy
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		
		next.ServeHTTP(w, r)
	})
}
```

### 6. Error Handling

```go
// internal/platform/httpserver/response.go
package httpserver

import (
	"encoding/json"
	"net/http"

	"go.uber.org/zap"
)

type ErrorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code,omitempty"`
}

// НИКОГДА не возвращать stack traces или внутренние детали
func InternalError(w http.ResponseWriter, err error) {
	// Log full error internally
	zap.L().Error("Internal error", zap.Error(err))
	
	// Return generic message to client
	w.WriteHeader(http.StatusInternalServerError)
	json.NewEncoder(w).Encode(ErrorResponse{
		Error: "Internal server error",
		Code:  "INTERNAL_ERROR",
	})
}

func NotFound(w http.ResponseWriter, msg string) {
	w.WriteHeader(http.StatusNotFound)
	json.NewEncoder(w).Encode(ErrorResponse{
		Error: msg,
		Code:  "NOT_FOUND",
	})
}

func BadRequest(w http.ResponseWriter, msg string) {
	w.WriteHeader(http.StatusBadRequest)
	json.NewEncoder(w).Encode(ErrorResponse{
		Error: msg,
		Code:  "BAD_REQUEST",
	})
}
```

---

## Privacy Considerations

### 1. Stealth Address Handling

**Принцип: Explorer НЕ должен компрометировать приватность stealth адресов.**

```go
// internal/features/addresses/app/get_balance.go

func (uc *GetBalanceUseCase) Execute(ctx context.Context, address string) (*Balance, error) {
	// Явно отклоняем запросы баланса для stealth адресов
	if isStealthAddress(address) {
		return nil, &PrivacyError{
			Message: "Cannot query balance for stealth address. " +
				"Stealth addresses provide receiver privacy by design.",
			Suggestion: "Use a wallet with stealth scanning capability.",
		}
	}
	
	return uc.repo.GetBalance(ctx, address)
}

func isStealthAddress(addr string) bool {
	return strings.HasPrefix(addr, "qs:") || strings.HasPrefix(addr, "qstest:")
}
```

### 2. UI Privacy Notices

```tsx
// app/components/PrivacyNotice.tsx
import React from 'react';

interface Props {
  type: 'stealth-address' | 'stealth-output';
}

export const PrivacyNotice: React.FC<Props> = ({ type }) => {
  if (type === 'stealth-address') {
    return (
      <div className="privacy-notice">
        <h3>🔒 Privacy Protected</h3>
        <p>
          This is a <strong>stealth address</strong>. By design, stealth addresses
          provide receiver privacy and cannot be publicly tracked.
        </p>
        <ul>
          <li>Balance and transaction history are not publicly visible</li>
          <li>Only the owner with the scan key can identify their transactions</li>
          <li>This is a privacy feature, not a limitation</li>
        </ul>
        <p>
          <a href="/docs/stealth-addresses">Learn more about stealth addresses →</a>
        </p>
      </div>
    );
  }
  
  if (type === 'stealth-output') {
    return (
      <div className="privacy-notice compact">
        <span className="icon">🔒</span>
        <span>
          Stealth output: recipient address is cryptographically hidden.
          Only the intended recipient can identify this payment.
        </span>
      </div>
    );
  }
  
  return null;
};
```

### 3. Logging Policy

```go
// internal/platform/observability/logger.go

// Что логируем:
// ✅ Request ID, method, path, status, duration
// ✅ Error messages (без sensitive data)
// ✅ Rate limit events
// ✅ Failed validation (без values)

// Что НЕ логируем:
// ❌ Полные адреса (только prefix + hash)
// ❌ View tags
// ❌ Ephemeral/destination pubkeys
// ❌ Anchor hints
// ❌ Full transaction bodies

func SanitizeForLog(address string) string {
	if len(address) <= 20 {
		return address
	}
	// qaspa:qz... -> qaspa:qz****
	return address[:10] + "****"
}

type sanitizedRequest struct {
	Method string `json:"method"`
	Path   string `json:"path"`  // Без query params если есть sensitive data
}
```

### 4. Data Retention

```sql
-- Мы НЕ храним:
-- - IP адреса запросов (только в памяти для rate limiting)
-- - User agents
-- - Referers
-- - Связь между запросами одного пользователя

-- Мы храним только blockchain data
-- которая и так публична (кроме stealth private parts)
```

---

## Threat Model

### Threats и Mitigations

| Threat | Impact | Mitigation |
|--------|--------|------------|
| DDoS | High | Rate limiting, CDN |
| SQL Injection | High | Prepared statements (sqlc/pgx) |
| XSS | Medium | CSP headers, sanitization |
| Brute force search | Low | Rate limiting on search |
| Privacy deanonymization | High | Reject stealth queries, education |
| Data scraping | Low | Rate limiting, pagination limits |

### Attack Vectors

1. **Массовый scraping блоков/транзакций**
   - Mitigation: Rate limiting 100 RPS
   - Mitigation: Pagination max 100 items

2. **Попытка связать stealth outputs с адресами**
   - Mitigation: Не храним и не вычисляем такие связи
   - Mitigation: API не предоставляет endpoint для этого

3. **Timing attacks на stealth scan**
   - Mitigation: Фиксированное время ответа (padding)
   - Mitigation: Rate limit на /stealth/scan

---

## Deployment Security

### Environment Variables

```bash
# .env.production
# НЕ коммитить в git!

DATABASE_URL=postgresql://user:STRONG_PASSWORD@host:5432/db?sslmode=require
LOG_LEVEL=info

# Ограниченные CORS
CORS_ALLOWED_ORIGINS=https://explorer.qaspa.org

# Строгие лимиты для продакшена
RATE_LIMIT_RPS=50
RATE_LIMIT_BURST=100
```

### Docker Security

```dockerfile
# Dockerfile
FROM golang:1.22-alpine AS builder
# ... build ...

FROM alpine:3.19

# Non-root user
RUN addgroup -S api && adduser -S api -G api

COPY --from=builder /api /app/api

# Read-only filesystem
USER api

# No shell access
ENTRYPOINT ["/app/api"]
```

### Network

```yaml
# docker-compose.prod.yml
services:
  rest-api:
    # Внутренняя сеть
    networks:
      - internal
    # Expose только через reverse proxy
    expose:
      - "8080"
    
  nginx:
    networks:
      - internal
      - external
    ports:
      - "443:443"
```

---

## Compliance

### GDPR / Privacy Laws

**Qaspa Explorer не собирает персональные данные:**

- Нет регистрации/аккаунтов
- Нет cookies (кроме технических для socket.io)
- Нет tracking
- Нет analytics (или privacy-respecting типа Plausible)
- IP адреса не сохраняются
- Blockchain данные являются публичными

### Terms of Service (рекомендации)

```markdown
## Terms of Service

1. This explorer provides read-only access to public blockchain data.
2. Stealth address privacy is protected by design - we cannot and do not
   track stealth transactions.
3. We do not collect personal information.
4. Rate limiting is applied to prevent abuse.
5. Data displayed is provided "as is" from the blockchain.
```

---

## Security Checklist

### Pre-Launch

- [ ] Rate limiting настроен и протестирован
- [ ] Input validation на всех endpoints
- [ ] SQL injection невозможен (prepared statements)
- [ ] Security headers настроены
- [ ] CORS ограничен для продакшена
- [ ] Error messages не раскрывают внутренности
- [ ] Логи не содержат sensitive data
- [ ] Stealth запросы корректно отклоняются
- [ ] Privacy notices добавлены в UI
- [ ] Docker работает от non-root
- [ ] TLS настроен
- [ ] Secrets не в коде

### Post-Launch

- [ ] Мониторинг rate limiting
- [ ] Alerts на аномальный трафик
- [ ] Регулярный аудит логов
- [ ] Обновление зависимостей
- [ ] Penetration testing (ежегодно)

---

## Incident Response

### В случае подозрительной активности:

1. **Немедленно**: Включить stricter rate limits
2. **5 минут**: Проверить логи на pattern
3. **15 минут**: Если DDoS - включить CDN protection mode
4. **1 час**: Анализ и решение о блокировке IP ranges

### В случае обнаружения уязвимости:

1. **Не публиковать** до исправления
2. Исправить и задеплоить
3. Проверить логи на exploitation
4. Написать post-mortem
5. Уведомить пользователей если были затронуты

---

## Checklist готовности этапа

- [ ] Rate limiting реализован
- [ ] Input validation на всех endpoints
- [ ] Security headers настроены
- [ ] Error handling не раскрывает детали
- [ ] Stealth privacy защищена
- [ ] Privacy notices в UI
- [ ] Logging policy задокументирована
- [ ] Docker security настроен
- [ ] CORS для продакшена
- [ ] Документация по incident response
- [ ] Security checklist пройден

