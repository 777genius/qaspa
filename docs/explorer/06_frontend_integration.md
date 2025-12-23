# Этап 6: Frontend Integration (qaspa-explorer-ng)

## Цель

Адаптировать форк `kaspa-explorer-ng` для работы с Qaspa API:
- Вынести API URL в конфигурацию
- Поддержать stealth outputs и nullable addresses
- Добавить UI для Qaspa-специфичных фич

---

## Ключевые изменения

### 1. Конфигурация API endpoints

#### .env (Vite/React Router)

```bash
# API Configuration
VITE_API_BASE=http://localhost:8080
VITE_SOCKET_URL=http://localhost:8081

# Network
VITE_NETWORK_ID=qaspa-mainnet
# Display policy: можно ставить `qaspa` (для mainnet) — backend всё равно принимает и `kaspa`, и `qaspa`.
VITE_ADDRESS_PREFIX=qaspa

# Features
VITE_ENABLE_STEALTH=true
VITE_ENABLE_MLDSA=true
```

#### app/config.ts (новый файл)

```typescript
export const config = {
  api: {
    // Важно: Vite переменные доступны как import.meta.env.VITE_*
    baseUrl: import.meta.env.VITE_API_BASE || 'https://api.qaspa.org',
    // socket.io URL обычно задаём как http(s) — транспорт сам апгрейдится до ws
    socketUrl: import.meta.env.VITE_SOCKET_URL || 'https://api.qaspa.org',
  },
  network: {
    id: import.meta.env.VITE_NETWORK_ID || 'qaspa-mainnet',
    // Prefixes берём из `crypto/addresses` (в монорепо): kaspa/kaspatest/kaspasim/kaspadev + stealth qs/qstest
    addressPrefix: import.meta.env.VITE_ADDRESS_PREFIX || 'kaspa',
    stealthPrefix: ['kaspa', 'qaspa'].includes(import.meta.env.VITE_ADDRESS_PREFIX || 'kaspa') ? 'qs' : 'qstest',
  },
  features: {
    stealth: import.meta.env.VITE_ENABLE_STEALTH === 'true',
    mldsa: import.meta.env.VITE_ENABLE_MLDSA === 'true',
  },
};
```

### 2. API Client обновление

#### Centralize base URL (upstream сейчас хардкодит `https://api.kaspa.org`)

Upstream в `app/hooks/*` делает `axios.get("https://api.kaspa.org/...")`, а в `app/api/socket.ts` — `SOCKET_URL = "wss://api.kaspa.org"`.
Для Qaspa форка: выносим в `app/config.ts` и используем везде единый `apiBase`.

Рекомендуемый минимум:
- заменить константы на `config.api.baseUrl` / `config.api.socketUrl`
- создать один axios instance `app/api/http.ts` и использовать его в хуках

Точки хардкода (их нужно заменить на общий client/instance):
- `app/api/socket.ts`
- `app/api/kaspa-api-client.ts` (market-data)
- `app/hooks/useAddressBalance.ts`
- `app/hooks/useAddressTxCount.ts`
- `app/hooks/useAddressUtxos.ts`
- `app/hooks/useAddressNames.ts`
- `app/hooks/useAddressDistribution.ts`
- `app/hooks/useTopAddresses.ts`
- `app/hooks/useTransactions.ts` (full-transactions-page)
- `app/hooks/useTransactionsSearch.ts` (transactions/search)
- `app/hooks/useTransactionById.ts`
- `app/hooks/useTransactionsCount.ts`
- `app/hooks/useTransactionCount.ts`
- `app/hooks/useBlockById.ts`
- `app/hooks/useBlockDagInfo.ts`
- `app/hooks/useBlockReward.ts`
- `app/hooks/useFeeEstimate.ts`
- `app/hooks/useHalving.ts`
- `app/hooks/useCoinSupply.ts`

#### app/api/socket.ts (замена hardcoded SOCKET_URL)

```ts
import { io } from "socket.io-client";
import { config } from "../config";

export const socket = io(config.api.socketUrl, {
  path: "/ws/socket.io",
  autoConnect: true,
});
```

#### app/hooks/* (пример замены на общий axios instance)

Было:

```ts
await axios.get(`https://api.kaspa.org/addresses/${address}/balance`);
```

Стало:

```ts
await api.get(`/addresses/${address}/balance`);
```

```typescript
import axios from 'axios';
import { config } from '../config';

const api = axios.create({
  baseURL: config.api.baseUrl,
  timeout: 30000,
});

// === BLOCKS ===

export const getBlock = async (hash: string, includeColor = true) => {
  const { data } = await api.get(`/blocks/${hash}`, {
    params: { includeColor },
  });
  return data;
};

export const getBlocks = async (limit = 20, offset = 0) => {
  const { data } = await api.get('/blocks', {
    params: { limit, offset },
  });
  return data;
};

// === TRANSACTIONS ===

export interface TransactionOutput {
  transaction_id: string;
  index: number;
  amount: number;
  script_public_key: string;
  script_public_key_address: string | null;  // NULLABLE!
  script_public_key_type: string;
  accepting_block_hash: string;
  // Qaspa-specific
  stealth_data?: {
    view_tag: number;
    ephemeral_pubkey: string;
    destination_pubkey: string;
    anchor_hint?: string;
  };
}

export interface Transaction {
  transaction_id: string;
  hash: string;
  mass: string;
  payload: string;
  block_hash: string[];
  block_time: number;
  is_accepted: boolean;
  accepting_block_hash: string;
  accepting_block_blue_score: number;
  accepting_block_time: number;
  inputs: TransactionInput[];
  outputs: TransactionOutput[];
}

export const getTransaction = async (
  txid: string,
  resolvePreviousOutpoints: 'no' | 'light' | 'full' = 'light'
) => {
  const { data } = await api.get<Transaction>(`/transactions/${txid}`, {
    params: { resolve_previous_outpoints: resolvePreviousOutpoints },
  });
  return data;
};

export const searchTransactions = async (txids: string[]) => {
  const { data } = await api.post<Transaction[]>('/transactions/search', {
    transactionIds: txids,
  });
  return data;
};

// === ADDRESSES ===

export const getAddressBalance = async (address: string) => {
  // Проверяем что это не stealth адрес
  if (address.startsWith(config.network.stealthPrefix + ':')) {
    throw new Error('Cannot get balance for stealth address');
  }
  
  const { data } = await api.get(`/addresses/${address}/balance`);
  return data;
};

export const getAddressUtxos = async (address: string) => {
  const { data } = await api.get(`/addresses/${address}/utxos`);
  return data;
};

export const getAddressTransactions = async (
  address: string,
  limit = 20,
  offset = 0
) => {
  const { data } = await api.get(`/addresses/${address}/full-transactions`, {
    params: { limit, offset, resolve_previous_outpoints: 'light' },
  });
  return data;
};

// === STEALTH (Qaspa-specific) ===

export interface StealthOutput {
  transaction_id: string;
  output_index: number;
  view_tag: number;
  ephemeral_pubkey: string;
  destination_pubkey: string;
  amount: number;
  block_hash: string;
  block_daa_score: number;
  block_time: number;
  is_coinbase: boolean;
  is_spent: boolean;
  anchor_hint?: string;
}

export const getBlockViewTags = async (blockHash: string) => {
  const { data } = await api.get(`/blocks/${blockHash}/view-tags`);
  return data;
};

export const getStealthOutputs = async (
  limit = 100,
  cursor?: string,
  unspentOnly = false
) => {
  const { data } = await api.get('/stealth/outputs', {
    params: { limit, cursor, unspent_only: unspentOnly },
  });
  return data;
};

export const scanStealthOutputs = async (
  viewTag: number,
  fromDaa = 0,
  limit = 1000
) => {
  const { data } = await api.get('/stealth/scan', {
    params: { view_tag: viewTag, from_daa: fromDaa, limit },
  });
  return data;
};

// === MLDSA (Qaspa-specific) ===

export const getMldsaAnchors = async () => {
  const { data } = await api.get('/mldsa/anchors');
  return data;
};

export const getMldsaDelegations = async (anchor: string) => {
  const { data } = await api.get(`/mldsa/anchors/${anchor}/delegations`);
  return data;
};

// === INFO ===

export const getBlockDagInfo = async () => {
  const { data } = await api.get('/info/blockdag');
  return data;
};

export const getCoinSupply = async () => {
  const { data } = await api.get('/info/coinsupply');
  return data;
};

export const getNetworkInfo = async () => {
  const { data } = await api.get('/info/network');
  return data;
};
```

### 3. Компоненты для Stealth

#### app/components/StealthOutput.tsx (новый)

```tsx
import React from 'react';
import { StealthOutput as StealthOutputType } from '../api/qaspa-api-client';
import { formatKas } from '../utils/format';
import { CopyButton } from './CopyButton';

interface Props {
  output: StealthOutputType;
  showBlockInfo?: boolean;
}

export const StealthOutputCard: React.FC<Props> = ({ output, showBlockInfo = false }) => {
  return (
    <div className="stealth-output-card">
      <div className="stealth-output-header">
        <span className="stealth-badge">STEALTH</span>
        <span className="view-tag">View Tag: {output.view_tag}</span>
      </div>
      
      <div className="stealth-output-body">
        <div className="field">
          <label>Amount</label>
          <span className="amount">{formatKas(output.amount)} QAS</span>
        </div>
        
        <div className="field">
          <label>Ephemeral Pubkey (R)</label>
          <div className="pubkey">
            <code>{output.ephemeral_pubkey}</code>
            <CopyButton value={output.ephemeral_pubkey} />
          </div>
        </div>
        
        <div className="field">
          <label>Destination Pubkey (P)</label>
          <div className="pubkey">
            <code>{output.destination_pubkey}</code>
            <CopyButton value={output.destination_pubkey} />
          </div>
        </div>
        
        {output.anchor_hint && (
          <div className="field">
            <label>MLDSA Anchor Hint</label>
            <code>{output.anchor_hint}</code>
          </div>
        )}
        
        {showBlockInfo && (
          <div className="field">
            <label>Block</label>
            <a href={`/blocks/${output.block_hash}`}>
              DAA: {output.block_daa_score.toLocaleString()}
            </a>
          </div>
        )}
        
        <div className="field status">
          {output.is_spent ? (
            <span className="spent">Spent</span>
          ) : (
            <span className="unspent">Unspent</span>
          )}
          {output.is_coinbase && <span className="coinbase">Coinbase</span>}
        </div>
      </div>
    </div>
  );
};
```

#### app/components/StealthOutput.css

```css
.stealth-output-card {
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  border: 1px solid #7b2cbf;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 12px;
}

.stealth-output-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.stealth-badge {
  background: linear-gradient(90deg, #7b2cbf, #9d4edd);
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: bold;
}

.view-tag {
  color: #e0aaff;
  font-family: monospace;
}

.stealth-output-body .field {
  margin-bottom: 8px;
}

.stealth-output-body label {
  display: block;
  color: #888;
  font-size: 12px;
  margin-bottom: 4px;
}

.stealth-output-body .pubkey {
  display: flex;
  align-items: center;
  gap: 8px;
}

.stealth-output-body code {
  font-family: 'Fira Code', monospace;
  font-size: 12px;
  color: #c77dff;
  word-break: break-all;
}

.stealth-output-body .amount {
  color: #70e000;
  font-weight: bold;
  font-size: 16px;
}

.stealth-output-body .status {
  display: flex;
  gap: 8px;
}

.stealth-output-body .spent {
  color: #ff6b6b;
}

.stealth-output-body .unspent {
  color: #70e000;
}

.stealth-output-body .coinbase {
  background: #3a0ca3;
  color: white;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 11px;
}
```

### 2.1 Валидация адресов (критичная правка под Qaspa prefixes)

Сейчас в `app/utils/kaspa.ts` валидируется только `kaspa:` и `kaspatest:` и под очень узкую длину.
Для Qaspa нужно:
- принимать stealth prefixes `qs:` и `qstest:`
- **не фиксировать длину на 61-63**, так как stealth адреса заметно длиннее

Минимальный вариант (быстрая защита от мусора, без полного bech32 decode):

```ts
export const isValidQaspaAddressSyntax = (address: string) =>
  /^(kaspa|kaspatest|kaspasim|kaspadev|qs|qstest):[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{20,200}$/.test(address);
```

И заменить в `app/routes/addressdetails.tsx`:
- `isValidKaspaAddressSyntax` → `isValidQaspaAddressSyntax`

### 4. Обновление страницы транзакции

#### app/routes/transactiondetails.tsx (изменения)

```tsx
import { Link } from "react-router";

import { StealthOutputCard } from "../components/StealthOutput";

// В компоненте отображения outputs:

const TransactionOutputs: React.FC<{ outputs: TransactionOutput[] }> = ({ outputs }) => {
  return (
    <div className="outputs-list">
      {outputs.map((output, index) => (
        <div key={index} className="output-item">
          {output.stealth_data ? (
            // Stealth output - специальное отображение
            <StealthOutputCard
              output={{
                transaction_id: output.transaction_id,
                output_index: output.index,
                view_tag: output.stealth_data.view_tag,
                ephemeral_pubkey: output.stealth_data.ephemeral_pubkey,
                destination_pubkey: output.stealth_data.destination_pubkey,
                amount: output.amount,
                block_hash: '', // не доступно в контексте tx
                block_daa_score: 0,
                block_time: 0,
                is_coinbase: false,
                is_spent: false,
                anchor_hint: output.stealth_data.anchor_hint,
              }}
            />
          ) : (
            // Обычный output
            <div className="regular-output">
              <div className="output-address">
                {output.script_public_key_address ? (
                  <Link to={`/addresses/${output.script_public_key_address}`}>
                    {output.script_public_key_address}
                  </Link>
                ) : (
                  <span className="no-address">
                    Non-standard script ({output.script_public_key_type})
                  </span>
                )}
              </div>
              <div className="output-amount">
                {formatKas(output.amount)} QAS
              </div>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};
```

### 5. Новая страница: Stealth Outputs в блоке (React Router route)

В этом проекте роуты задаются в `app/routes.ts`.
Добавляем новый маршрут:

```ts
// app/routes.ts
route("blocks/:blockId/stealth", "./routes/blockstealth.tsx"),
```

И создаём файл:

#### app/routes/blockstealth.tsx (новый)

```tsx
import { useQuery } from "@tanstack/react-query";
import { useParams } from "react-router";

import { getBlockViewTags } from "../api/qaspa-api-client";
import { StealthOutputCard } from "../components/StealthOutput";
import Spinner from "../Spinner";

export default function BlockStealthRoute() {
  const { blockId } = useParams();
  
  const { data, isLoading, error } = useQuery({
    queryKey: ['block-view-tags', blockId],
    queryFn: () => getBlockViewTags(blockId),
    enabled: !!blockId,
  });
  
  if (isLoading) return <Spinner />;
  if (error) return <div className="error">Failed to load stealth outputs</div>;
  
  return (
    <div className="stealth-outputs-page">
      <h1>Stealth Outputs in Block</h1>
      <div className="block-info">
        <p>Block Hash: <code>{blockId}</code></p>
        <p>DAA Score: {data?.block_daa_score?.toLocaleString()}</p>
        <p>Total Stealth Outputs: {data?.total_count}</p>
      </div>
      
      <div className="stealth-outputs-list">
        {data?.stealth_outputs?.length === 0 ? (
          <p className="no-outputs">No stealth outputs in this block</p>
        ) : (
          data?.stealth_outputs?.map((output: any, index: number) => (
            <StealthOutputCard key={index} output={output} />
          ))
        )}
      </div>
    </div>
  );
}
```

### 6. Обновление страницы адреса

#### app/routes/addressdetails.tsx (изменения)

```tsx
import { useParams } from "react-router";

import { config } from "../config";

export default function AddressDetailsRoute() {
  const { address } = useParams();
  
  // Проверяем тип адреса
  const isStealthAddress = address.startsWith(config.network.stealthPrefix + ':');
  
  if (isStealthAddress) {
    return <StealthAddressInfo address={address} />;
  }
  
  return <RegularAddressInfo address={address} />;
}

// Для stealth адресов показываем информационную страницу
const StealthAddressInfo: React.FC<{ address: string }> = ({ address }) => {
  return (
    <div className="stealth-address-page">
      <h1>Stealth Address</h1>
      <div className="address-display">
        <code>{address}</code>
      </div>
      
      <div className="info-box">
        <h2>Privacy Notice</h2>
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
          To view your transactions, use a wallet that supports stealth address scanning.
        </p>
      </div>
      
      <div className="address-parts">
        <h3>Address Components</h3>
        <div className="part">
          <label>Scan Public Key</label>
          <code>{/* Parse from address */}</code>
        </div>
        <div className="part">
          <label>Spend Public Key</label>
          <code>{/* Parse from address */}</code>
        </div>
      </div>
    </div>
  );
};

// Обычная страница адреса
const RegularAddressInfo: React.FC<{ address: string }> = ({ address }) => {
  // ... существующая логика
};
```

### 7. Навигация

#### app/components/Navbar.tsx (изменения)

```tsx
import { Link } from "react-router";

import { config } from "../config";

export const Navbar: React.FC = () => {
  return (
    <nav className="navbar">
      <div className="navbar-brand">
        <Link to="/">
          <span className="logo">Qaspa Explorer</span>
        </Link>
      </div>
      
      <div className="navbar-menu">
        <Link to="/blocks">Blocks</Link>
        <Link to="/txs">Transactions</Link>
        
        {config.features.stealth && (
          <Link to="/stealth">Stealth Outputs</Link>
        )}
        
        {config.features.mldsa && (
          <Link to="/mldsa">MLDSA</Link>
        )}
        
        <Link to="/info">Network</Link>
      </div>
      
      <div className="navbar-search">
        <SearchBar />
      </div>
    </nav>
  );
};
```

### 8. Утилиты для адресов

#### app/utils/address.ts (новый)

```typescript
import { config } from '../config';

export type AddressType = 
  | 'pubkey' 
  | 'pubkey_ecdsa' 
  | 'pubkey_mldsa' 
  | 'script_hash' 
  | 'stealth'
  | 'unknown';

export function getAddressType(address: string): AddressType {
  if (!address) return 'unknown';
  
  // Stealth addresses
  if (address.startsWith('qs:') || address.startsWith('qstest:')) {
    return 'stealth';
  }
  
  // Regular addresses - определяем по версии
  // Это упрощённая версия, полный парсинг требует bech32
  // Принимаем оба family prefixes: kaspa* и qaspa* (alias).
  if (
    address.startsWith('kaspa:q') || address.startsWith('kaspatest:q') || address.startsWith('kaspasim:q') || address.startsWith('kaspadev:q') ||
    address.startsWith('qaspa:q') || address.startsWith('qaspatest:q') || address.startsWith('qaspasim:q') || address.startsWith('qaspadev:q')
  ) {
    // Нужно декодировать и проверить version byte
    return 'pubkey'; // default
  }
  
  return 'unknown';
}

export function isStealthAddress(address: string): boolean {
  return getAddressType(address) === 'stealth';
}

export function canQueryBalance(address: string): boolean {
  const type = getAddressType(address);
  return type !== 'stealth' && type !== 'unknown';
}

export function formatAddress(address: string, short = false): string {
  if (!address) return '';
  if (!short) return address;
  
  // qaspa:qz1234...5678
  const parts = address.split(':');
  if (parts.length !== 2) return address;
  
  const [prefix, payload] = parts;
  if (payload.length <= 16) return address;
  
  return `${prefix}:${payload.slice(0, 8)}...${payload.slice(-8)}`;
}

// Display policy: в UI показываем regular-адреса как qaspa*, но принимаем kaspa* как алиас.
export function toDisplayAddress(address: string): string {
  if (!address) return '';
  if (address.startsWith('kaspa:')) return 'qaspa:' + address.slice('kaspa:'.length);
  if (address.startsWith('kaspatest:')) return 'qaspatest:' + address.slice('kaspatest:'.length);
  if (address.startsWith('kaspasim:')) return 'qaspasim:' + address.slice('kaspasim:'.length);
  if (address.startsWith('kaspadev:')) return 'qaspadev:' + address.slice('kaspadev:'.length);
  return address;
}

export function getAddressExplorerUrl(address: string): string {
  return `/addresses/${address}`;
}
```

---

## Стили

### Stealth theme colors

Добавить в глобальные стили:

```css
:root {
  /* Stealth theme */
  --stealth-primary: #7b2cbf;
  --stealth-secondary: #9d4edd;
  --stealth-light: #e0aaff;
  --stealth-gradient: linear-gradient(90deg, #7b2cbf, #9d4edd);
  
  /* MLDSA theme */
  --mldsa-primary: #3a0ca3;
  --mldsa-secondary: #4361ee;
  
  /* Status colors */
  --color-spent: #ff6b6b;
  --color-unspent: #70e000;
  --color-pending: #ffd60a;
}
```

---

## Тестирование

### E2E тесты для stealth

```typescript
// e2e/stealth.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Stealth outputs', () => {
  test('should display stealth outputs in block', async ({ page }) => {
    await page.goto('/blocks/test-block-hash/stealth');
    
    await expect(page.locator('h1')).toContainText('Stealth Outputs');
    await expect(page.locator('.stealth-badge')).toBeVisible();
  });
  
  test('should show privacy notice for stealth address', async ({ page }) => {
    await page.goto('/addresses/qs:test-stealth-address');
    
    await expect(page.locator('.info-box')).toContainText('Privacy Notice');
    await expect(page.locator('.info-box')).toContainText('cannot be publicly tracked');
  });
  
  test('should handle null address in transaction outputs', async ({ page }) => {
    await page.goto('/txs/test-tx-with-stealth-output');
    
    // Не должно быть ошибок
    await expect(page.locator('.error')).not.toBeVisible();
    
    // Stealth output должен отображаться корректно
    await expect(page.locator('.stealth-output-card')).toBeVisible();
  });
});
```

---

## Checklist готовности этапа

- [ ] API URL вынесен в конфигурацию
- [ ] API client обновлён для Qaspa endpoints
- [ ] Компонент StealthOutputCard создан
- [ ] Страница транзакции поддерживает stealth outputs
- [ ] Страница блока имеет ссылку на stealth outputs
- [ ] Страница /blocks/:hash/stealth создана
- [ ] Страница адреса корректно обрабатывает stealth адреса
- [ ] Навигация обновлена
- [ ] Стили для stealth элементов добавлены
- [ ] E2E тесты написаны и проходят
- [ ] Документация обновлена

