# Этап 5: REST API Endpoints Contract

## Цель

Зафиксировать контракт REST API для Qaspa Explorer. Контракт "mostly compatible" с `api.kaspa.org`, но с расширениями для stealth/MLDSA.

---

## Базовый URL

```
Production: https://api.qaspa.org
Local:      http://localhost:8080
```

---

## Общие правила

### Формат ответов

Все ответы в JSON. Успешные ответы возвращают данные напрямую (без обёртки).

### Address prefixes (display vs accepted input)

Стратегия проекта:
- **В ответах API и в UI отображаем** regular-адреса с префиксами `qaspa*` (например `qaspa:...`, `qaspatest:...`).
- **На входе (path/query/body) принимаем** и `kaspa*`, и `qaspa*` как алиасы одного и того же network prefix.
- **Stealth префиксы не меняются**: `qs` / `qstest` (и это не алиасы к regular).

### Naming convention (важно для совместимости с `qaspa-explorer-ng`)

Фронт сейчас ожидает **два стиля** (как у `api.kaspa.org`):
- **Blocks/info** часто в формате kaspad RPC (camelCase внутри объектов, например `header.hashMerkleRoot`).
- **Transactions/addresses** в формате REST (snake_case, например `transaction_id`, `script_public_key_address`).

В Qaspa REST API сохраняем эти ожидания, чтобы минимально править фронт.

### Ошибки

```json
{
  "error": "Block not found",
  "code": "NOT_FOUND"
}
```

HTTP коды:
- `200` — успех
- `400` — неверный запрос (bad hash format, etc.)
- `404` — не найдено
- `429` — rate limit
- `500` — внутренняя ошибка

### Пагинация

Query параметры:
- `limit` — кол-во записей (default: 20, max: 100)
- `offset` — смещение (default: 0)

Ответ с пагинацией НЕ оборачивается (как в оригинале), возвращается массив.

### Nullable поля

**Важно для Qaspa**: поле `script_public_key_address` может быть `null` для:
- Stealth outputs (script_version = 16)
- Non-standard scripts

Клиенты должны обрабатывать это корректно.

---

## Endpoints

### Blocks

#### GET /blocks/:hash

Получить блок по хешу.

**Query params:**
- `includeColor` (bool, default: false) — включить цвет блока

**Response:**

```json
{
  "header": {
    "version": 1,
    "hashMerkleRoot": "abc123...",
    "acceptedIdMerkleRoot": "def456...",
    "utxoCommitment": "ghi789...",
    "timestamp": "1703001234567",
    "bits": 453115127,
    "nonce": "12345678901234567890",
    "daaScore": "50000000",
    "blueWork": "1a2b3c...",
    "blueScore": "49999000",
    "pruningPoint": "xyz...",
    "parents": [
      {
        "parentHashes": ["parent1hash...", "parent2hash..."]
      }
    ]
  },
  "transactions": [
    {
      "inputs": [...],
      "outputs": [...],
      "subnetworkId": "0000...",
      "payload": "",
      "verboseData": {
        "transactionId": "tx123...",
        "hash": "tx123...",
        "computeMass": 1234,
        "blockHash": "block...",
        "blockTime": 1703001234567
      },
      "lockTime": 0,
      "gas": 0,
      "mass": 1234,
      "version": 0
    }
  ],
  "verboseData": {
    "hash": "blockhash...",
    "difficulty": 1234567890.12,
    "selectedParentHash": "parent...",
    "transactionIds": ["tx1...", "tx2..."],
    "blueScore": "49999000",
    "childrenHashes": [],
    "mergeSetBluesHashes": [],
    "mergeSetRedsHashes": [],
    "isChainBlock": true
  },
  "extra": {
    "color": "#ff0000",
    "minerAddress": "qaspa:...",
    "minerInfo": "pool-name"
  }
}
```

#### GET /blocks

Список последних блоков.

**Query params:**
- `limit` (int, default: 20)
- `offset` (int, default: 0)
- `lowHash` (string, optional) — начать после этого хеша

**Response:** массив блоков (упрощённый формат)

```json
[
  {
    "hash": "abc123...",
    "daaScore": 50000000,
    "blueScore": 49999000,
    "timestamp": "1703001234567",
    "isChainBlock": true,
    "txCount": 5,
    "minerAddress": "qaspa:..."
  }
]
```

---

### Transactions

#### GET /transactions/:txid

Получить транзакцию по ID.

**Query params:**
- `resolve_previous_outpoints` (string: "no" | "light" | "full", default: "no")
  - `no` — не резолвить prevouts
  - `light` — только address + amount
  - `full` — полный output (не реализовано, fallback на light)

**Response:**

```json
{
  "subnetwork_id": "0000...",
  "transaction_id": "tx123...",
  "hash": "tx123...",
  "mass": "1234",
  "payload": "",
  "block_hash": ["block1...", "block2..."],
  "block_time": 1703001234567,
  "is_accepted": true,
  "accepting_block_hash": "block1...",
  "accepting_block_blue_score": 49999000,
  "accepting_block_time": 1703001234567,
  "inputs": [
    {
      "transaction_id": "tx123...",
      "index": 0,
      "previous_outpoint_hash": "prevtx...",
      "previous_outpoint_index": "0",
      "previous_outpoint_resolved": {
        "transaction_id": "prevtx...",
        "index": 0,
        "amount": 100000000,
        "script_public_key": "20abc...",
        "script_public_key_address": "qaspa:...",
        "script_public_key_type": "pubkey",
        "accepting_block_hash": "..."
      },
      "previous_outpoint_address": "qaspa:...",
      "previous_outpoint_amount": 100000000,
      "signature_script": "41abc...",
      "sig_op_count": "1"
    }
  ],
  "outputs": [
    {
      "transaction_id": "tx123...",
      "index": 0,
      "amount": 50000000,
      "script_public_key": "20def...",
      "script_public_key_address": "qaspa:...",
      "script_public_key_type": "pubkey",
      "accepting_block_hash": "block1..."
    },
    {
      "transaction_id": "tx123...",
      "index": 1,
      "amount": 49990000,
      "script_public_key": "10ghi...",
      "script_public_key_address": null,
      "script_public_key_type": "stealth",
      "accepting_block_hash": "block1...",
      "stealth_data": {
        "view_tag": 42,
        "ephemeral_pubkey": "02abc...",
        "destination_pubkey": "03def...",
        "anchor_hint": "anchor123..."
      }
    }
  ]
}
```

**Важно**: `script_public_key_address` может быть `null` для stealth outputs!

#### POST /transactions/search

Поиск транзакций.

**Request body:**

```json
{
  "transactionIds": ["tx1...", "tx2...", "tx3..."]
}
```

**Response:** массив транзакций (как в GET)

#### GET /addresses/:address/full-transactions-page (совместимость с текущими хуками)

В `qaspa-explorer-ng` сейчас используется endpoint пагинации по заголовкам:
- `X-Next-Page-Before`
- `X-Next-Page-After`
- `X-Page-Count`

**Query params (как в хуке):**
- `limit` (int)
- `before` (int)
- `after` (int)
- `fields` (string)
- `resolve_previous_outpoints` ("no"|"light"|"full")

**Response:** массив транзакций (snake_case, как `Transaction` в хуке).

---

### Addresses

#### GET /addresses/:address/balance

Баланс адреса (только для non-stealth адресов).

**Response:**

```json
{
  "address": "qaspa:qz...",
  "balance": 123456789000
}
```

**Примечание**: для stealth адресов (`qs:...`) вернёт `400 Bad Request` с пояснением.

#### GET /addresses/:address/utxos

UTXO адреса.

**Response:**

```json
[
  {
    "address": "qaspa:qz...",
    "outpoint": {
      "transactionId": "tx123...",
      "index": 0
    },
    "utxoEntry": {
      "amount": "50000000",
      "scriptPublicKey": {
        "scriptPublicKey": "20abc...",
        "version": 0
      },
      "blockDaaScore": "50000000",
      "isCoinbase": false
    }
  }
]
```

#### GET /addresses/:address/transactions-count

Количество транзакций адреса.

**Response:**

```json
{
  "total": 42
}
```

#### GET /addresses/:address/full-transactions

История транзакций адреса.

**Query params:**
- `limit` (int, default: 20)
- `offset` (int, default: 0)
- `resolve_previous_outpoints` (string, default: "light")

**Response:** массив транзакций (как в GET /transactions/:txid)

---

### Stealth (Qaspa-specific)

#### GET /blocks/:hash/view-tags

Stealth outputs из конкретного блока.

**Response:**

```json
{
  "block_hash": "abc123...",
  "block_daa_score": 50000000,
  "stealth_outputs": [
    {
      "transaction_id": "tx123...",
      "output_index": 1,
      "view_tag": 42,
      "ephemeral_pubkey": "02abc...",
      "destination_pubkey": "03def...",
      "amount": 100000000,
      "is_coinbase": false,
      "anchor_hint": "anchor123..."
    }
  ],
  "total_count": 15
}
```

#### GET /stealth/outputs

Список всех stealth outputs (с пагинацией).

**Query params:**
- `limit` (int, default: 100)
- `cursor` (string, optional) — курсор для пагинации
- `unspent_only` (bool, default: false)

**Response:**

```json
{
  "outputs": [
    {
      "transaction_id": "tx123...",
      "output_index": 1,
      "view_tag": 42,
      "ephemeral_pubkey": "02abc...",
      "destination_pubkey": "03def...",
      "amount": 100000000,
      "block_hash": "block...",
      "block_daa_score": 50000000,
      "block_time": 1703001234567,
      "is_coinbase": false,
      "is_spent": false,
      "anchor_hint": "anchor123..."
    }
  ],
  "next_cursor": "cursor_abc123"
}
```

#### GET /stealth/scan

Сканирование stealth outputs по view tag (для кошельков).

**Query params:**
- `view_tag` (int, required) — 0-255
- `from_daa` (int, default: 0) — начать с этого DAA score
- `limit` (int, default: 1000)

**Response:**

```json
{
  "outputs": [
    {
      "transaction_id": "tx123...",
      "output_index": 1,
      "view_tag": 42,
      "ephemeral_pubkey": "02abc...",
      "destination_pubkey": "03def...",
      "amount": 100000000,
      "block_hash": "block...",
      "block_daa_score": 50000000,
      "block_time": 1703001234567,
      "anchor_hint": "anchor123..."
    }
  ],
  "last_daa_score": 50001000,
  "has_more": true
}
```

---

### MLDSA (Qaspa-specific, optional)

#### GET /mldsa/anchors

Список зарегистрированных MLDSA anchors.

**Response:**

```json
{
  "anchors": [
    {
      "anchor": "anchor123...",
      "level": 3,
      "registered_at_daa": 49000000,
      "delegation_count": 5
    }
  ]
}
```

#### GET /mldsa/anchors/:anchor/delegations

Делегации по anchor.

**Response:**

```json
{
  "anchor": "anchor123...",
  "delegations": [
    {
      "account_id": "acc123",
      "spend_pubkey": "02abc...",
      "scan_pubkey": "03def...",
      "valid_from_daa": 49000000,
      "valid_until_daa": 99999999,
      "nonce": 1,
      "status": "active"
    }
  ]
}
```

---

### Info

#### GET /info/blockdag

Информация о текущем состоянии DAG.

**Response:**

```json
{
  "networkName": "qaspa-mainnet",
  "blockCount": "50000000",
  "headerCount": "50000000",
  "tipHashes": ["tip1...", "tip2..."],
  "difficulty": 1234567890.12,
  "pastMedianTime": "1703001234567",
  "virtualParentHashes": ["vp1...", "vp2..."],
  "pruningPointHash": "pp...",
  "virtualDaaScore": "50000000"
}
```

#### GET /info/coinsupply

Информация о supply.

**Response:**

```json
{
  "circulatingSupply": "28000000000000000",
  "maxSupply": "28700000000000000"
}
```

#### GET /info/coinsupply/circulating

Только circulating (plain text).

**Response:**

```
28000000000000000
```

#### GET /info/coinsupply/total

Только max supply (plain text).

**Response:**

```
28700000000000000
```

#### GET /info/network

Статистика сети.

**Response:**

```json
{
  "networkName": "qaspa-mainnet",
  "tps": 2.5,
  "bps": 10.0,
  "mempoolSize": 42,
  "difficulty": 1234567890.12,
  "hashrate": "1.23 PH/s"
}
```

#### GET /info/halving

Информация о halving (если применимо).

**Response:**

```json
{
  "nextHalvingTimestamp": 1735689600000,
  "nextHalvingDate": "2025-01-01T00:00:00Z",
  "nextHalvingAmount": 150
}
```

---

### Health

#### GET /ping

Health check.

**Response:**

```
pong
```

#### GET /health

Детальный health check.

**Response:**

```json
{
  "status": "healthy",
  "database": "connected",
  "synced": true,
  "version": "1.0.0"
}
```

---

## Сравнение с api.kaspa.org

| Endpoint | api.kaspa.org | Qaspa API | Изменения |
|----------|---------------|-----------|-----------|
| GET /blocks/:hash | ✅ | ✅ | Без изменений |
| GET /transactions/:txid | ✅ | ✅ | + stealth_data в outputs |
| GET /addresses/:addr/balance | ✅ | ✅ | Ошибка для stealth адресов |
| GET /addresses/:addr/utxos | ✅ | ✅ | Без изменений |
| GET /addresses/:addr/full-transactions | ✅ | ✅ | + stealth_data |
| GET /blocks/:hash/view-tags | ❌ | ✅ | **Новый** |
| GET /stealth/outputs | ❌ | ✅ | **Новый** |
| GET /stealth/scan | ❌ | ✅ | **Новый** |
| GET /mldsa/anchors | ❌ | ✅ | **Новый** |
| GET /info/* | ✅ | ✅ | Без изменений |

---

## OpenAPI Spec

Полная OpenAPI 3.0 спецификация будет сгенерирована и размещена в:
- `repos/qaspa-rest-api/api/openapi.yaml`
- Доступна по `/docs` (Swagger UI)

---

## Socket.io (realtime) compatibility note

Фронт подключается к socket.io с кастомным path:
- URL: `VITE_SOCKET_URL` (пример: `http://localhost:8081` или `wss://api.qaspa.org`)
- path: `/ws/socket.io`

Это нужно сохранить в `qaspa-socket-server`, иначе realtime в UI не поднимется без правок фронта.

---

## Checklist готовности этапа

- [ ] Все endpoints задокументированы
- [ ] Примеры запросов/ответов проверены
- [ ] Обработка null адресов для stealth описана
- [ ] Backward compatibility с kaspa-explorer-ng проверена
- [ ] OpenAPI spec сгенерирован
- [ ] Swagger UI работает

