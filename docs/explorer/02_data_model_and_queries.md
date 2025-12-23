# Этап 2: Data Model и Queries

## Цель

Спроектировать схему PostgreSQL под Qaspa с поддержкой:
- Публичных адресов (как в оригинальной Kaspa)
- Stealth outputs (view_tag, ephemeral_pubkey, destination_pubkey)
- MLDSA типов адресов
- Быстрых запросов для API

---

## Обзор таблиц

```
┌─────────────────┐     ┌─────────────────┐
│     blocks      │────<│  transactions   │
└─────────────────┘     └─────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
      ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
      │   tx_inputs   │ │  tx_outputs   │ │stealth_outputs│
      └───────────────┘ └───────────────┘ └───────────────┘
                              │
                              ▼
                      ┌───────────────┐
                      │     utxos     │  (materialized view / table)
                      └───────────────┘
                              │
                              ▼
                      ┌───────────────┐
                      │  address_tx   │  (denormalized for fast lookup)
                      └───────────────┘
```

---

## DDL: Миграция 001_init_schema.sql

```sql
-- ============================================================================
-- BLOCKS
-- ============================================================================
CREATE TABLE blocks (
    hash              VARCHAR(64) PRIMARY KEY,
    version           SMALLINT NOT NULL,
    
    -- DAG info
    daa_score         BIGINT NOT NULL,
    blue_score        BIGINT NOT NULL,
    blue_work         VARCHAR(64) NOT NULL,
    pruning_point     VARCHAR(64),
    
    -- Timestamps
    timestamp         BIGINT NOT NULL,  -- Unix milliseconds
    
    -- Merkle roots
    hash_merkle_root       VARCHAR(64) NOT NULL,
    accepted_id_merkle_root VARCHAR(64) NOT NULL,
    utxo_commitment        VARCHAR(64) NOT NULL,
    
    -- Mining
    bits              BIGINT NOT NULL,
    nonce             NUMERIC(20, 0) NOT NULL,
    
    -- Verbose data
    difficulty        DOUBLE PRECISION,
    selected_parent_hash VARCHAR(64),
    is_chain_block    BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Extra (from kaspa-explorer)
    miner_address     VARCHAR(128),
    miner_info        TEXT,
    color             VARCHAR(16),
    
    -- Metadata
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_blocks_daa_score ON blocks(daa_score DESC);
CREATE INDEX idx_blocks_blue_score ON blocks(blue_score DESC);
CREATE INDEX idx_blocks_timestamp ON blocks(timestamp DESC);
CREATE INDEX idx_blocks_is_chain_block ON blocks(is_chain_block) WHERE is_chain_block = TRUE;

-- Parent hashes (многие-ко-многим)
CREATE TABLE block_parents (
    block_hash   VARCHAR(64) NOT NULL REFERENCES blocks(hash) ON DELETE CASCADE,
    parent_hash  VARCHAR(64) NOT NULL,
    parent_level SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (block_hash, parent_hash)
);

CREATE INDEX idx_block_parents_parent ON block_parents(parent_hash);

-- ============================================================================
-- TRANSACTIONS
-- ============================================================================
CREATE TABLE transactions (
    transaction_id    VARCHAR(64) PRIMARY KEY,
    hash              VARCHAR(64) NOT NULL,  -- witness hash
    
    -- Transaction data
    version           SMALLINT NOT NULL,
    lock_time         BIGINT NOT NULL,
    subnetwork_id     VARCHAR(40) NOT NULL,
    gas               BIGINT NOT NULL DEFAULT 0,
    payload           BYTEA,
    mass              BIGINT NOT NULL,
    
    -- Acceptance info
    is_accepted       BOOLEAN NOT NULL DEFAULT FALSE,
    accepting_block_hash VARCHAR(64),
    accepting_block_blue_score BIGINT,
    block_time        BIGINT,  -- from accepting block
    
    -- Metadata
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_accepting_block ON transactions(accepting_block_hash);
CREATE INDEX idx_transactions_block_time ON transactions(block_time DESC) WHERE is_accepted = TRUE;
CREATE INDEX idx_transactions_hash ON transactions(hash);

-- Связь транзакция <-> блок (многие-ко-многим, т.к. tx может быть в нескольких блоках)
CREATE TABLE transaction_blocks (
    transaction_id VARCHAR(64) NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    block_hash     VARCHAR(64) NOT NULL REFERENCES blocks(hash) ON DELETE CASCADE,
    PRIMARY KEY (transaction_id, block_hash)
);

CREATE INDEX idx_transaction_blocks_block ON transaction_blocks(block_hash);

-- ============================================================================
-- TRANSACTION INPUTS
-- ============================================================================
CREATE TABLE tx_inputs (
    id                       BIGSERIAL PRIMARY KEY,
    transaction_id           VARCHAR(64) NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    input_index              INT NOT NULL,
    
    -- Previous outpoint
    previous_outpoint_hash   VARCHAR(64) NOT NULL,
    previous_outpoint_index  INT NOT NULL,
    
    -- Script
    signature_script         BYTEA NOT NULL,
    sig_op_count             INT NOT NULL DEFAULT 0,
    sequence                 BIGINT NOT NULL DEFAULT 0,
    
    UNIQUE (transaction_id, input_index)
);

CREATE INDEX idx_tx_inputs_tx ON tx_inputs(transaction_id);
CREATE INDEX idx_tx_inputs_prevout ON tx_inputs(previous_outpoint_hash, previous_outpoint_index);

-- ============================================================================
-- TRANSACTION OUTPUTS
-- ============================================================================

-- Script types enum
CREATE TYPE script_type AS ENUM (
    'pubkey',
    'pubkey_ecdsa', 
    'pubkey_mldsa',
    'script_hash',
    'stealth',
    'non_standard'
);

CREATE TABLE tx_outputs (
    id                       BIGSERIAL PRIMARY KEY,
    transaction_id           VARCHAR(64) NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    output_index             INT NOT NULL,
    
    -- Value
    amount                   BIGINT NOT NULL,
    
    -- Script
    script_public_key        BYTEA NOT NULL,
    script_version           SMALLINT NOT NULL DEFAULT 0,
    script_type              script_type NOT NULL,
    
    -- Address (NULL для stealth и non_standard)
    script_public_key_address VARCHAR(128),
    
    -- Spending info
    is_spent                 BOOLEAN NOT NULL DEFAULT FALSE,
    spending_tx_id           VARCHAR(64),
    spending_input_index     INT,
    
    UNIQUE (transaction_id, output_index)
);

CREATE INDEX idx_tx_outputs_tx ON tx_outputs(transaction_id);
CREATE INDEX idx_tx_outputs_address ON tx_outputs(script_public_key_address) 
    WHERE script_public_key_address IS NOT NULL;
CREATE INDEX idx_tx_outputs_unspent ON tx_outputs(script_public_key_address) 
    WHERE is_spent = FALSE AND script_public_key_address IS NOT NULL;
CREATE INDEX idx_tx_outputs_script_version ON tx_outputs(script_version) 
    WHERE script_version = 16;  -- stealth

-- ============================================================================
-- STEALTH OUTPUTS (отдельная таблица для быстрого сканирования)
-- ============================================================================
CREATE TABLE stealth_outputs (
    id                   BIGSERIAL PRIMARY KEY,
    
    -- Reference to tx_outputs
    transaction_id       VARCHAR(64) NOT NULL,
    output_index         INT NOT NULL,
    
    -- Stealth-specific data
    view_tag             SMALLINT NOT NULL,  -- 0-255
    ephemeral_pubkey     VARCHAR(66) NOT NULL,  -- 33 bytes hex (compressed)
    destination_pubkey   VARCHAR(66) NOT NULL,  -- 33 bytes hex
    
    -- Value (denormalized for fast access)
    amount               BIGINT NOT NULL,
    
    -- Block info (denormalized for scanning)
    block_hash           VARCHAR(64) NOT NULL,
    block_daa_score      BIGINT NOT NULL,
    block_time           BIGINT NOT NULL,
    
    -- MLDSA anchor hint (optional)
    anchor_hint          VARCHAR(64),
    
    -- Is coinbase?
    is_coinbase          BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Spending info
    is_spent             BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE (transaction_id, output_index),
    FOREIGN KEY (transaction_id, output_index) 
        REFERENCES tx_outputs(transaction_id, output_index) ON DELETE CASCADE
);

-- Индекс для сканирования по view_tag
CREATE INDEX idx_stealth_outputs_scan ON stealth_outputs(view_tag, block_daa_score);
CREATE INDEX idx_stealth_outputs_daa ON stealth_outputs(block_daa_score);
CREATE INDEX idx_stealth_outputs_unspent ON stealth_outputs(is_spent) WHERE is_spent = FALSE;
CREATE INDEX idx_stealth_outputs_anchor ON stealth_outputs(anchor_hint) WHERE anchor_hint IS NOT NULL;

-- ============================================================================
-- UTXOS (материализованная таблица для быстрого баланса/списка)
-- Только для NON-STEALTH адресов
-- ============================================================================
CREATE TABLE utxos (
    id                       BIGSERIAL PRIMARY KEY,
    
    -- Outpoint
    transaction_id           VARCHAR(64) NOT NULL,
    output_index             INT NOT NULL,
    
    -- Address (NOT NULL - только для адресуемых)
    address                  VARCHAR(128) NOT NULL,
    
    -- Value
    amount                   BIGINT NOT NULL,
    
    -- Script info
    script_public_key        BYTEA NOT NULL,
    script_type              script_type NOT NULL,
    
    -- Is coinbase (for maturity check)?
    is_coinbase              BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Block info
    block_daa_score          BIGINT NOT NULL,
    
    UNIQUE (transaction_id, output_index)
);

CREATE INDEX idx_utxos_address ON utxos(address);
CREATE INDEX idx_utxos_address_amount ON utxos(address, amount DESC);

-- ============================================================================
-- ADDRESS_TX (денормализованная лента транзакций по адресу)
-- ============================================================================
CREATE TABLE address_tx (
    id                       BIGSERIAL PRIMARY KEY,
    
    address                  VARCHAR(128) NOT NULL,
    transaction_id           VARCHAR(64) NOT NULL,
    
    -- Direction
    is_input                 BOOLEAN NOT NULL,  -- true = spent from, false = received to
    
    -- Value (сумма по этому адресу в этой tx)
    amount                   BIGINT NOT NULL,
    
    -- Block info
    block_daa_score          BIGINT NOT NULL,
    block_time               BIGINT NOT NULL,
    
    UNIQUE (address, transaction_id, is_input)
);

CREATE INDEX idx_address_tx_lookup ON address_tx(address, block_daa_score DESC);
CREATE INDEX idx_address_tx_tx ON address_tx(transaction_id);

-- ============================================================================
-- MLDSA ANCHORS (опционально, для будущего)
-- ============================================================================
CREATE TABLE mldsa_anchors (
    anchor           VARCHAR(64) PRIMARY KEY,  -- BLAKE2b hash
    master_pubkey    BYTEA NOT NULL,           -- 1952 bytes for Level 3
    level            SMALLINT NOT NULL,        -- 2, 3, or 5
    registered_at    BIGINT NOT NULL,          -- block_daa_score
    metadata         JSONB,
    
    created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE mldsa_delegations (
    id               BIGSERIAL PRIMARY KEY,
    
    anchor           VARCHAR(64) NOT NULL REFERENCES mldsa_anchors(anchor),
    account_id       VARCHAR(64) NOT NULL,
    
    -- Delegated keys
    spend_pubkey     VARCHAR(66) NOT NULL,
    scan_pubkey      VARCHAR(66) NOT NULL,
    
    -- Validity
    valid_from_daa   BIGINT NOT NULL,
    valid_until_daa  BIGINT NOT NULL,
    nonce            BIGINT NOT NULL,
    
    -- Signature
    signature        BYTEA NOT NULL,
    
    -- Status
    status           VARCHAR(16) NOT NULL DEFAULT 'active',  -- active, revoked, expired
    
    created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE (anchor, account_id, nonce)
);

CREATE INDEX idx_mldsa_delegations_anchor ON mldsa_delegations(anchor);
CREATE INDEX idx_mldsa_delegations_status ON mldsa_delegations(status) WHERE status = 'active';

-- ============================================================================
-- NETWORK INFO (singleton table for caching)
-- ============================================================================
CREATE TABLE network_info (
    id                       INT PRIMARY KEY DEFAULT 1,
    
    -- Virtual info
    virtual_daa_score        BIGINT,
    virtual_parent_hashes    TEXT[],
    
    -- Supply
    circulating_supply       BIGINT,
    max_supply               BIGINT,
    
    -- Stats
    tip_count                INT,
    difficulty               DOUBLE PRECISION,
    past_median_time         BIGINT,
    
    -- Sync status
    is_synced                BOOLEAN DEFAULT FALSE,
    
    updated_at               TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT single_row CHECK (id = 1)
);

INSERT INTO network_info (id) VALUES (1);
```

---

## Ключевые запросы

### GET /transactions/:id?resolve_previous_outpoints=light

```sql
-- Main transaction
SELECT 
    t.transaction_id,
    t.hash,
    t.version,
    t.lock_time,
    t.subnetwork_id,
    t.gas,
    t.payload,
    t.mass,
    t.is_accepted,
    t.accepting_block_hash,
    t.accepting_block_blue_score,
    t.block_time
FROM transactions t
WHERE t.transaction_id = $1;

-- Inputs with resolved prevouts (light = only address/amount)
SELECT 
    i.input_index,
    i.previous_outpoint_hash,
    i.previous_outpoint_index,
    i.signature_script,
    i.sig_op_count,
    -- Resolved prevout (light)
    o.amount AS previous_outpoint_amount,
    o.script_public_key_address AS previous_outpoint_address
FROM tx_inputs i
LEFT JOIN tx_outputs o 
    ON o.transaction_id = i.previous_outpoint_hash 
    AND o.output_index = i.previous_outpoint_index
WHERE i.transaction_id = $1
ORDER BY i.input_index;

-- Outputs
SELECT 
    o.output_index,
    o.amount,
    o.script_public_key,
    o.script_version,
    o.script_type,
    o.script_public_key_address
FROM tx_outputs o
WHERE o.transaction_id = $1
ORDER BY o.output_index;

-- If has stealth outputs, also fetch:
SELECT 
    s.output_index,
    s.view_tag,
    s.ephemeral_pubkey,
    s.destination_pubkey,
    s.anchor_hint
FROM stealth_outputs s
WHERE s.transaction_id = $1;
```

### GET /addresses/:addr/balance

```sql
SELECT COALESCE(SUM(amount), 0) AS balance
FROM utxos
WHERE address = $1;
```

### GET /addresses/:addr/utxos

```sql
SELECT 
    transaction_id,
    output_index,
    amount,
    script_public_key,
    script_type,
    is_coinbase,
    block_daa_score
FROM utxos
WHERE address = $1
ORDER BY amount DESC
LIMIT $2 OFFSET $3;
```

### GET /addresses/:addr/full-transactions

```sql
-- Получаем список tx_id
SELECT DISTINCT transaction_id, block_daa_score, block_time
FROM address_tx
WHERE address = $1
ORDER BY block_daa_score DESC
LIMIT $2 OFFSET $3;

-- Затем для каждого tx_id получаем полную транзакцию
-- (или batch запросом с IN clause)
```

### GET /blocks/:hash/view-tags (Qaspa-specific)

```sql
SELECT 
    s.transaction_id,
    s.output_index,
    s.view_tag,
    s.ephemeral_pubkey,
    s.destination_pubkey,
    s.amount,
    s.is_coinbase,
    s.anchor_hint
FROM stealth_outputs s
WHERE s.block_hash = $1
ORDER BY s.transaction_id, s.output_index;
```

### GET /stealth/scan (Qaspa-specific)

```sql
SELECT 
    s.transaction_id,
    s.output_index,
    s.view_tag,
    s.ephemeral_pubkey,
    s.destination_pubkey,
    s.amount,
    s.block_hash,
    s.block_daa_score,
    s.block_time,
    s.anchor_hint,
    s.is_spent
FROM stealth_outputs s
WHERE s.view_tag = $1
  AND s.block_daa_score >= $2
  AND s.is_spent = FALSE
ORDER BY s.block_daa_score
LIMIT $3;
```

---

## Стратегия обновления UTXO

При обработке нового accepted блока:

```sql
-- 1. Помечаем потраченные outputs
UPDATE tx_outputs
SET is_spent = TRUE,
    spending_tx_id = $1,
    spending_input_index = $2
FROM tx_inputs i
WHERE tx_outputs.transaction_id = i.previous_outpoint_hash
  AND tx_outputs.output_index = i.previous_outpoint_index
  AND i.transaction_id = $1;

-- 2. Удаляем из UTXO table
DELETE FROM utxos u
USING tx_inputs i
WHERE u.transaction_id = i.previous_outpoint_hash
  AND u.output_index = i.previous_outpoint_index
  AND i.transaction_id = $1;

-- 3. Добавляем новые UTXO (только для адресуемых)
INSERT INTO utxos (transaction_id, output_index, address, amount, script_public_key, script_type, is_coinbase, block_daa_score)
SELECT 
    o.transaction_id,
    o.output_index,
    o.script_public_key_address,
    o.amount,
    o.script_public_key,
    o.script_type,
    (t.subnetwork_id = '0000000000000000000000000000000000000001'),
    $3
FROM tx_outputs o
JOIN transactions t ON t.transaction_id = o.transaction_id
WHERE o.transaction_id = $1
  AND o.script_public_key_address IS NOT NULL;

-- 4. Обновляем address_tx
INSERT INTO address_tx (address, transaction_id, is_input, amount, block_daa_score, block_time)
-- ... aggregated by address
```

---

## Миграции

Файлы в `repos/qaspa-rest-api/db/migrations/`:

```
001_init_schema.sql         -- Вся схема выше
002_add_indexes.sql         -- Дополнительные индексы после нагрузочного тестирования
003_add_mldsa_tables.sql    -- MLDSA anchors/delegations (можно отложить)
```

Команды:

```bash
# Применить миграции
goose -dir db/migrations postgres "$DATABASE_URL" up

# Откатить последнюю
goose -dir db/migrations postgres "$DATABASE_URL" down

# Статус
goose -dir db/migrations postgres "$DATABASE_URL" status
```

---

## Checklist готовности этапа

- [ ] DDL schema написана и проверена
- [ ] Миграции созданы в `db/migrations/`
- [ ] Ключевые запросы задокументированы
- [ ] Индексная стратегия определена
- [ ] Тестовый dataset подготовлен для проверки
- [ ] Производительность запросов измерена на тестовых данных

