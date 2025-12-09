# Phase 2 — Iteration 3: MLDSA Master Account и metadata

> Цель итерации: превратить MLDSA master в полноценный тип аккаунта кошелька с собственным жизненным циклом (create / unlock / sign / rotate), хранением anchor/metadata и базовой связью со стелс‑аккаунтами, не трогая ещё протокол делегаций (Iteration 4).

## 0. Контекст и границы итерации

- **Что уже готово (Iter.1–2):**
  - Детеминированная деривация MLDSA master из BIP39 сид-а (`MasterSeed`, `MasterAnchor`, FFI/wasm/CLI обвязка).
  - Безопасное хранение master seed в `PrvKeyDataVariant::MlDsaMaster`, миграции хранилища (`STORAGE_VERSION = 1`), RPC/API события `MasterAnchorCreated`, `MasterSeedExported`.
- **Что делаем в Iteration 3:**
  - Вводим новый `AccountKind` для мастера, реализуем отдельный модуль `mldsa_master` в `wallet/core`.
  - Добавляем anchor/metadata мастера в аккаунтный payload, в том числе ссылку из стелс‑аккаунтов на привязанный master (через `master_anchor` и зарезервированное поле `delegation_id`).
  - Расширяем `wallet/core/src/wallet` и CLI/SDK, чтобы пользователь мог создавать master‑аккаунт, листать их и привязывать stealth‑аккаунты к конкретному мастеру.
  - Включаем события/notify вокруг операций мастера (создание, ротация, привязка/отвязка stealth).
- **Чего НЕ делаем в Iteration 3 (остаётся Iteration 4+):**
  - Не реализуем структуру `DelegationRecord`, её хранилище и TLV-проводку через `StealthSigner`.
  - Не меняем поведение сканера UTXO и tx‑генератора на проверку делегаций.
  - Не расширяем RPC методами `register_mldsa_anchor` / `list_mldsa_delegations`.

**Критерий успеха:** master представлен как отдельный account kind, может быть создан/разблокирован/ротирован через CLI и SDK, stealth‑аккаунты умеют ссылаться на master‑anchor в своём payload, а все изменения полностью обратносуместимы с существующими кошельками.

**Статус:** ВЫПОЛНЕНО (CLI/WASM/Wallet готово, делегации остаются в Iteration 4).

## 1. Область изменений и файлы

| Подсистема | Файлы | Изменения |
|-----------|-------|-----------|
| Типы аккаунтов | `wallet/core/src/account/kind.rs`, `wallet/core/src/factory.rs` | Добавление `MLDSA_MASTER_ACCOUNT_KIND`, регистрация фабрики `MldsaMasterAccount`. |
| Логика master‑аккаунта | `wallet/core/src/account/variants/mldsa_master.rs` (новый модуль) | Структура payload, status, unlock/lock, sign, rotate, базовое управление связями со stealth. |
| Хранилище аккаунтов | `wallet/core/src/account/variants/stealth.rs` | Расширение `stealth::Payload` (master_anchor, delegation_id), миграция версий payload. |
| Высокоуровневый API кошелька | `wallet/core/src/wallet/mod.rs` | Методы `create_account_mldsa_master`, `list_master_accounts`, `attach_stealth_to_master`, `detach_stealth_from_master`, `get_master_by_anchor`. |
| CLI / WASM / FFI | `cli/src/modules/wallet.rs`, `wallet/native/*`, `wallet/core/src/wasm/wallet/wallet.rs` | Команды и биндинги работы с master‑аккаунтом и привязкой stealth. |
| События и notify | `wallet/core/src/events.rs`, `notify/*` | Новые события и уведомления о жизненном цикле master и изменении привязок. |
| Документация | `docs/plans/phase2/Phase2_MLDSA_master_key.md`, `docs/api/MLDSA_MASTER.md`, `docs/IMPLEMENTATION_STATUS.md` | Уточнение статуса Iteration 3, детальное описание API master‑аккаунта и привязки stealth. |

## 2. Дизайн `MldsaMasterAccount`

### 2.1. Структура данных и статусы

- **Payload master‑аккаунта (хранимый в `AccountStorage`):**

```rust
pub struct MldsaMasterAccountPayloadV1 {
    /// Ссылка на запись в PrvKeyDataStore с `PrvKeyDataVariant::MlDsaMaster`
    pub master_id: PrvKeyDataId,
    /// Anchor из Iteration 1–2 (BLAKE2b-256("mldsa-anchor" || master_pubkey))
    pub anchor: MasterAnchor,
    /// Публичный MLDSA‑ключ мастера (payload для Version::PubKeyMLDSA)
    pub master_pubkey: Vec<u8>,
    pub level: MlDsaLevel,          // L2/L3/L5
    pub created_at_daa: u64,        // DAA‑высота создания аккаунта
    pub status: MasterStatus,       // Active / Rotated / Revoked
    pub delegations: Vec<u64>,      // DelegationId, пока пустой до Iteration 4
}

pub enum MasterStatus {
    Active,
    Rotated { rotated_at_daa: u64, new_anchor: Option<MasterAnchor> },
    Revoked { revoked_at_daa: u64 },
}
```

- **Инварианты:**
  - В системе не обязательно один master‑аккаунт: допускается несколько master’ов на один сид (разные уровни / политики), **но** каждый `MldsaMasterAccount` жёстко ссылается на один `PrvKeyDataId` с `kind == PrvKeyDataVariantKind::MlDsaMaster` (поле `master_id`).
  - `anchor` в payload должен совпадать с вычислением из текущего публичного ключа мастера (через `MlDsaKeypair::anchor()`); расхождение → `MasterAnchorMismatch`.
  - `master_pubkey.len()` должен соответствовать длине публичного ключа для данного `MlDsaLevel` (см. `MlDsaKeypair::public_key_size()` / `Version::PubKeyMLDSA`); некорректная длина → ошибка чтения payload.
  - Метод `receive_address` для master‑аккаунта строит `Address::new(prefix, Version::PubKeyMLDSA, &master_pubkey)`, не требуя расшифровки сид‑а.
  - Переходы статуса:
    - `Active → Rotated` (однократно на конкретный anchor; ротации можно накапливать как историю в отдельном журнале).
    - `Active/Rotated → Revoked`.
    - Обратные переходы запрещены, CLI/SDK должны возвращать ошибку.

### 2.2. Жизненный цикл: unlock/lock

- **Источник секрета:** мастер seed/ключи берём только из `PrvKeyDataVariant::MlDsaMaster` (`MlDsaMasterPayload` в `PrvKeyDataPayload`), созданного в Iteration 2.
- **Поведение `unlock_with_master_seed`:**
  - На вход: `master_id: PrvKeyDataId`, `wallet_secret: &Secret`, желаемый уровень `MlDsaLevel`.
  - Шаги:
    1. Через `PrvKeyDataStore::load_key_data(wallet_secret, &master_id)` получить `PrvKeyData` и убедиться, что `as_mldsa_master(..)` не вернул `None`.
    2. Взять `MlDsaMasterPayload`, вызвать `decrypt_seed(wallet_secret)` → `Zeroizing<Vec<u8>>` с детерминированным master seed.
    3. Воспользоваться обёрткой `kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair::from_master_seed(&master_seed, level)`, получив `(MlDsaKeypair, MasterAnchor)`.
    4. Сверить anchor из шага 3 с `payload.anchor`, а также проверить, что `payload.master_pubkey == keypair.public_key_bytes()`. Любое расхождение → ошибка `MasterAnchorMismatch` + событие.
    5. Закэшировать `MlDsaKeypair` в `MldsaMasterAccount` в zeroizing‑обёртке, не записывая его обратно в хранилище (ключ живёт только в памяти на время сессии).
  - `lock`: очищает кэш ключа, оставляя только публичный anchor/metadata.

### 2.3. Подпись сообщений

- Универсальный helper на уровне аккаунта:

```rust
/// Небольшой enum доменов подписи мастером (опционально можно вынести в отдельный модуль).
pub enum MasterSignDomain {
    AnchorExport,
    Delegation,        // Iteration 4
    Custom(String),    // произвольные сообщения (экспертный режим)
}

impl MldsaMasterAccount {
    pub fn sign_message(
        &self,
        domain: &MasterSignDomain,
        payload: &[u8],
    ) -> Result<MlDsaSignature, MasterError> {
        // доменная строка и hashing описаны в docs/api/MLDSA_MASTER.md
        // и используют константы доменов из crypto/mldsa/src/params.rs
    }
}
```

- **Домены подписи (фиксация в `crypto/mldsa/src/params.rs` и `docs/api/MLDSA_MASTER.md`):**
  - `MasterSignDomain::AnchorExport` — подпись на export‑артефакты (подтверждение владения anchor).
  - `MasterSignDomain::Delegation` — будет использоваться Iteration 4 (делегации).
  - `MasterSignDomain::Custom(String)` — CLI‑способ подписать произвольное сообщение (экспертный режим, отключаем по умолчанию в UI).

### 2.4. Ротация master (без переусложнения API)

- Метод на уровне аккаунта (минималистичный, без лишних типов):

```rust
impl MldsaMasterAccount {
    pub fn rotate(
        &mut self,
        new_level: Option<MlDsaLevel>,
        new_seed: Option<MasterSeed>,
    ) -> Result<(), MasterError> {
        // обновляет статус/anchor в payload;
        // обновление PrvKeyData выполняется на уровне Wallet
    }
}
```

- Оркестрация ротации на уровне `Wallet`:
  - Публичный метод `Wallet::rotate_master_account(account_id, new_level, new_seed, wallet_secret)`:
    - Загружает `PrvKeyDataPayload` по `master_id` из payload аккаунта.
    - Через `MlDsaMasterPayload::reencrypt_seed`/`decrypt_seed` и `MlDsaKeypair::from_master_seed` получает новый ключ/anchor.
    - Обновляет `MlDsaMasterPayload` (seed_cipher, level, anchor) и `MldsaMasterAccountPayloadV1` (level, status, delegations, created_at_daa/rotated_at_daa).
    - Сохраняет изменения в `PrvKeyDataStore` и `AccountStorage` в одной транзакции store.
  - Аккаунт‑метод `rotate` отвечает только за обновление своего payload/статуса; доступ к зашифрованному сид‑у остаётся у слоя хранения.

- **Политика:**
  - Если `new_seed` не задан, переиспользуем BIP39 seed (через существующую детерминированную деривацию) и при необходимости меняем только уровень `MlDsaLevel`.
  - Если `new_seed` задан, он должен быть безопасно записан в `PrvKeyDataVariant::MlDsaMaster::seed_cipher` с перешифровкой (используя уже реализованный `reencrypt_seed`).
  - Старый anchor остаётся в истории (для последующей валидации старых делегаций).
  - Сразу после ротации эмитим событие `MasterRotated` с полями `{ old_anchor, new_anchor, account_id }`.

### 2.5. Связь с существующим MLDSA master storage/API

- **Повторное использование Iteration 1–2:**
  - `Wallet::maybe_create_mldsa_master_from_mnemonic` и `Wallet::hydrate_mldsa_masters` уже создают записи `PrvKeyDataVariant::MlDsaMaster` и события `MasterAnchorCreated`.
  - `Wallet::master_anchor_infos()` возвращает `MasterAnchorInfo { id, anchor, level, is_encrypted }` для всех master‑записей.
- **Требования к `MldsaMasterAccount`:**
  - При создании master‑аккаунта payload `MldsaMasterAccountPayloadV1.master_id` должен ссылаться на один из `id` из `master_anchor_infos()`.
  - `anchor` и `level` в payload должны совпадать с теми же полями `PrvKeyDataInfo` (валидация при create/load).
  - При ротации/экспорте seed используется существующий API (`export_master_seed_hex`, `MasterSeedExported`), чтобы не дублировать криптографическую логику.
  - Параметр `WalletSettings::EnableMldsaMaster` по‑прежнему контролирует автосоздание master‑записей; master‑аккаунты не создаются, если флаг выключен.

## 3. Изменения в типах аккаунтов и фабрике

### 3.1. `wallet/core/src/account/kind.rs`

- `AccountKind` — это строковая обёртка (`str64`) с кастомным `FromStr`, который маппит короткие алиасы на «full kind» строки.
- Добавить строковую константу:
  - `pub const MLDSA_MASTER_ACCOUNT_KIND: &str = "kaspa-mldsa-master";`
- В `impl FromStr for AccountKind` добавить алиас по аналогии с `"stealth"`:
  - `"mldsa-master" => Ok(MLDSA_MASTER_ACCOUNT_KIND.into()),`
- Убедиться, что round‑trip `AccountKind::from_str("mldsa-master")` → сериализация через Borsh → десериализация возвращает тот же kind (юнит‑тест к `test_storage_account_kind` или отдельный тест).

### 3.2. `wallet/core/src/factory.rs` и `mldsa_master::Ctor`

- В новом модуле `wallet/core/src/account/variants/mldsa_master.rs` реализовать `struct Ctor {}` с трейтами `Factory`:
  - `fn name(&self) -> String { "mldsa-master".to_string() }`.
  - `fn description(&self) -> String { "MLDSA Master Root Account".to_string() }`.
  - `async fn try_load(&self, wallet, storage, meta)`:
    - десериализует `MldsaMasterAccountPayloadV1` из `storage.serialized`,
    - конструирует `MldsaMasterAccount` с `Inner::from_storage(wallet, storage)`,
    - валидирует согласованность `master_id`/`anchor` с `PrvKeyDataStore`.
- В `wallet/core/src/factory.rs` в массиве `factories` добавить новый элемент:
  - `(MLDSA_MASTER_ACCOUNT_KIND.into(), Arc::new(mldsa_master::Ctor {})),`
- Тесты фабрики:
  - Позитивный: `try_load_account` успешно загружает master‑аккаунт из валидного `AccountStorage` с kind `MLDSA_MASTER_ACCOUNT_KIND`.
  - Негативный: некорректный payload (несовпадение anchor/master_id) → ошибка `Error::AccountFactoryNotFound` или специализированная ошибка из `Ctor::try_load`.

## 4. Хранилище аккаунтов и связь со stealth

### 4.1. Хранилище master‑аккаунта

- В `wallet/core/src/account/variants/mldsa_master.rs`:
  - Определить `MldsaMasterAccountPayloadV1` как `AccountStorable`:
    - `impl Storable for MldsaMasterAccountPayloadV1 { const STORAGE_MAGIC: u32 = 0x4D4C4D41; /* "MLMA" */ const STORAGE_VERSION: u32 = 0; }`.
  - Реализовать `BorshSerialize/BorshDeserialize` с использованием `StorageHeader` по паттерну `stealth::Payload`:
    - при сериализации: `StorageHeader::new(Self::STORAGE_MAGIC, Self::STORAGE_VERSION).serialize(writer)?;` затем поля payload.
    - при десериализации: проверка `magic`, чтение `version`, далее чтение полей.
  - В `impl Account for MldsaMasterAccount` метод `to_storage` должен вызывать:
    - `AccountStorage::try_new(MLDSA_MASTER_ACCOUNT_KIND.into(), self.id(), self.storage_key(), self.prv_key_data_id.into(), settings, payload)`.
- В `wallet/core/src/storage/account.rs` изменений не требуется: контейнер `AccountStorage` уже хранит произвольный бинарный payload (`serialized: Vec<u8>`), версия контейнера (`STORAGE_VERSION = 0`) остаётся прежней.

### 4.2. Расширение `stealth::Payload` (master_anchor + delegation_id)

- В `wallet/core/src/account/variants/stealth.rs` расширить существующую структуру `Payload`:

```rust
pub struct Payload {
    pub account_index: u64,
    pub scan_pubkey: Vec<u8>,
    pub spend_pubkey: Vec<u8>,
    pub creation_daa_score: Option<u64>,
    pub master_anchor: Option<[u8; 32]>, // новый блок ссылок на master
    pub delegation_id: Option<u64>,      // зарезервировано под Iteration 4
}
```

- Обновить `impl Storable for Payload`:
  - `const STORAGE_VERSION: u32 = 1;` (раньше `0`).
- В `impl BorshDeserialize for Payload` заменить жёсткую проверку версии на разбор по `version`:
  - Считать `StorageHeader`, проверить `magic`, далее:
    - `version == 0`: прочитать старый формат (4 поля), задать `master_anchor = None`, `delegation_id = None`.
    - `version == 1`: прочитать все 6 полей.
    - иное значение → `IoErrorKind::InvalidData`.
- Обновить вспомогательные методы:
  - `Payload::new(...)` расширить параметрами `master_anchor: Option<[u8; 32]>` и `delegation_id: Option<u64>` (на Iteration 3 всегда `None`).
  - В `StealthAccount::try_new` и `to_storage` передавать `master_anchor`/`delegation_id` (на старте — `None`).
- Инвариант: старыe stealth‑аккаунты (v0) читаются прозрачно, все новые записи пишутся в формате v1, даже если `master_anchor` ещё не задан.

### 4.3. API привязки/отвязки stealth ↔ master

- Внутри `StealthAccount`:
  - Методы:
    - `fn attach_to_master(&mut self, master_anchor: MasterAnchor)`.
    - `fn detach_master(&mut self)`.
  - Инварианты:
    - Привязка возможна только если master‑аккаунт существует и находится в статусе `Active` или `Rotated` (но не `Revoked`).
    - `delegation_id` в Iteration 3 всегда `None` (будет установлен в Iteration 4 при создании делегаций).

## 5. Изменения в `wallet/core/src/wallet/mod.rs`

### 5.1. Создание и управление master‑аккаунтами (интеграция с существующим API)

- **Расширение `AccountCreateArgs` (см. `wallet/core/src/wallet/args.rs`):**
  - Добавить вариант `AccountCreateArgs::MldsaMaster { prv_key_data_id: PrvKeyDataId, level: MlDsaLevel, account_name: Option<String> }`.
  - Этот вариант будет использоваться как из CLI (`account create mldsa-master`), так и из RPC (`AccountsCreateRequest` уже несёт `AccountCreateArgs`).
- **Ветка в `Wallet::create_account` (см. существующий `match account_create_args`):**

```rust
AccountCreateArgs::MldsaMaster { prv_key_data_id, level, account_name } => {
    self.create_account_mldsa_master(wallet_secret, prv_key_data_id, level, account_name).await?
}
```

- **Новый helper внутри `Wallet`:**

```rust
pub async fn create_account_mldsa_master(
    self: &Arc<Wallet>,
    wallet_secret: &Secret,
    prv_key_data_id: PrvKeyDataId,
    level: MlDsaLevel,
    account_name: Option<String>,
) -> Result<Arc<dyn Account>> { /* как в Stealth/BIP32: строим payload, AccountStorage, commit */ }
```

- **Поведение `create_account_mldsa_master`:**
  - Через `PrvKeyDataStore::load_key_data(wallet_secret, &prv_key_data_id)` получить `PrvKeyData` и убедиться, что `as_mldsa_master(..)` вернул `Some(payload)`.
  - Расшифровать сид `payload.decrypt_seed(wallet_secret)` и через `MlDsaKeypair::from_master_seed(&master_seed, level)` получить `(pair, anchor)`, из `pair.public_key_bytes()` построить `master_pubkey`.
  - Построить `MldsaMasterAccountPayloadV1 { master_id, anchor, master_pubkey: master_pubkey.to_vec(), level, created_at_daa, status: Active, delegations: vec![] }`, где `created_at_daa` берётся из `UtxoProcessor::current_daa_score()` или `get_server_info().virtual_daa_score`.
  - Создать `MldsaMasterAccount` с новым `AccountId`/`storage_key` (аналогично `StealthAccount::try_new`), записать в `AccountStorage::try_new`, сохранить в `AccountStore`, `store.commit(wallet_secret)`.
  - Сгенерировать событие `MasterAccountCreated { account_id, anchor, level }`.
- **Получение/листинг master‑аккаунтов:**
  - Добавить вспомогательный метод:

```rust
pub async fn list_master_accounts(&self) -> Vec<MasterAccountInfo> {
    // обёртка над accounts_enumerate_call() с фильтром по MLDSA_MASTER_ACCOUNT_KIND
}
```

  - Для поиска по anchor реализовать helper:

```rust
pub async fn get_master_by_anchor(&self, anchor: &MasterAnchor) -> Option<MasterAccountInfo> {
    self.list_master_accounts().await.into_iter().find(|info| info.anchor == *anchor)
}
```

  - RPC‑слой может продолжать использовать существующий `accounts_enumerate_call()`, новые методы остаются helper’ами на уровне `Wallet`.

### 5.2. Привязка stealth‑аккаунта к master

- Внутренние методы `Wallet` (под `WalletGuard`/`account_guard`, как `stealth_account_*`):

```rust
pub async fn attach_stealth_to_master(
    self: &Arc<Wallet>,
    stealth_id: &AccountId,
    master_account_id: &AccountId,
    _guard: &WalletGuard<'_>,
) -> Result<()> { /* ... */ }

pub async fn detach_stealth_from_master(
    self: &Arc<Wallet>,
    stealth_id: &AccountId,
    _guard: &WalletGuard<'_>,
) -> Result<()> { /* ... */ }
```

- Логика `attach_stealth_to_master`:
  - Через `get_account_by_id(..., &guard)` получить оба аккаунта; убедиться, что `master.account_kind() == MLDSA_MASTER_ACCOUNT_KIND.into()`.
  - Достать `MldsaMasterAccountPayloadV1` у master, взять `anchor`.
  - Обновить `stealth::Payload`: `master_anchor = Some(*anchor.as_bytes())`, `delegation_id = None`; переписать `AccountStorage` (`Account::to_storage` + `AccountStore::store_single`), при необходимости `store.commit(wallet_secret)`.
  - Эмитить событие `StealthAttachedToMaster { stealth_id, master_id: *master_account_id, anchor }`.
- Логика `detach_stealth_from_master`:
  - Загрузить stealth‑аккаунт, обнулить `master_anchor`/`delegation_id`, сохранить `AccountStorage`.
  - Эмитить `StealthDetachedFromMaster { stealth_id: *stealth_id }`.

## 6. CLI, WASM и FFI

### 6.1. CLI (`cli/src/modules/account.rs`, `cli/src/modules/wallet.rs`)

- Новые/расширенные команды для `account`:
  - `account create mldsa-master [<name>]`:
    - Использует существующий поток выбора `PrvKeyData` (`ctx.select_private_key()`).
    - Создаёт master‑аккаунт через `Wallet::create_account_mldsa_master`.
    - Выводит `account_id`, `anchor (hex)`, `level`, `status`.
  - (опционально) `account list --kind mldsa-master`:
    - Фильтрует список аккаунтов по `AccountKind == MLDSA_MASTER_ACCOUNT_KIND` и показывает привязанные stealth‑аккаунты (по счётчику).
  - `account attach-stealth <stealth-id> <master-id>`:
    - Делегирует в `attach_stealth_to_master`, печатает привязанный `anchor`.
  - `account detach-stealth <stealth-id>`:
    - Делегирует в `detach_stealth_from_master`.
- Расширение существующей группы `wallet master`:
  - Добавить `wallet master sign --account-id <id> --domain <domain> --hex-payload <...>`:
    - Тонкий wrapper вокруг `MldsaMasterAccount::sign_message` для экспертов.
  - (опционально) `wallet master rotate --account-id <id> [--level {2|3|5}] [--new-seed]`:
    - Делегирует в `Wallet::rotate_master_account`, запрашивает подтверждение и пароль.
- UX‑детали:
  - Перед созданием master‑аккаунта CLI напоминает, что мастер должен храниться офлайн (ссылка на гайд cold storage).
  - При `attach-stealth` CLI предупреждает, что позже понадобится делегация (Iter.4), но сама операция сейчас только устанавливает ссылку `master_anchor`.

### 6.2. WASM / native API

- В `wallet/core/src/api/message.rs`:
  - Ввести вспомогательную структуру `MasterAccountInfo { account_id: AccountId, anchor: String, level: u8, status: String }`, используемую только на wire‑слое (для WASM/FFI/CLI).
  - (Опция А) Добавить отдельный ответ `MasterAccountsListResponse { accounts: Vec<MasterAccountInfo> }`.
  - (Опция Б) Или, чтобы избежать лишних типов, возвращать `AccountDescriptor` и вычитывать `anchor/level/status` из `properties` (менее прозрачно, лучше придерживаться А).
- В `wallet/core/src/wasm/api/message.rs`:
  - Объявить `IMasterAccountInfo` и `IMasterAccountsListResponse` по аналогии с `IMasterAnchorInfo`/`IMasterAnchorListResponse` (`accountId`, `anchor`, `level`, `status`).
- В `wallet/core/src/wasm/wallet/wallet.rs`:
  - Методы:
    - `wallet.createMasterAccount(level) -> Promise<IMasterAccountInfo>;` — обёртка вокруг `accounts_create_call` с `AccountCreateArgs::MldsaMaster`.
    - `wallet.listMasterAccounts() -> Promise<IMasterAccountsListResponse>;` — обёртка вокруг `accounts_enumerate_call` + фильтр по `MLDSA_MASTER_ACCOUNT_KIND`.
    - `wallet.attachStealthToMaster({ stealthId, masterId }) -> Promise<void>;` — вызов нового API `Wallet::attach_stealth_to_master`.
    - `wallet.detachStealthFromMaster({ stealthId }) -> Promise<void>;`.
- В `wallet/native`:
  - Аналогичные методы в FFI‑структурах/функциях (`MasterAccountInfoFFI`, `MasterAccountsListResponseFFI`, `AttachStealthRequestFFI` и т.п.).
  - Обновлённые тесты маппинга Rust ↔ FFI/JS (round‑trip `MasterAccountInfo` ↔ `IMasterAccountInfo`/FFI).

## 7. События и notify

### 7.1. Новые события в `wallet/core/src/events.rs`

- Добавить:
  - `MasterAccountCreated { account_id, anchor, level }`
  - `MasterAccountRotated { account_id, old_anchor, new_anchor }`
  - `MasterAccountRevoked { account_id, anchor }`
  - `StealthAttachedToMaster { stealth_id, master_id, anchor }`
  - `StealthDetachedFromMaster { stealth_id }`
  - (при необходимости) `MasterAnchorMismatch { account_id, expected_anchor, actual_anchor }`

### 7.2. Интеграция с notify/GUI

- В `notify/*`:
  - Настроить преобразование новых событий в пользовательские уведомления:
    - Информация о создании/ротации master.
    - Подсказка о необходимости обновить делегации после ротации (когда будет готов Iter.4).
- В GUI (если есть):
  - Карточка master‑аккаунта с QR‑кодом для anchor.
  - Индикатор, какие stealth‑аккаунты привязаны к какому master (на уровне UI пока без деталей делегаций).

## 8. Тесты и критерии готовности

### 8.1. Unit‑тесты

- `wallet/core/account/mldsa_master.rs`:
  - Создание payload’а, сериализация/десериализация.
  - Правильные переходы статусов `Active → Rotated → Revoked`.
  - Подпись и верификация сообщений в нескольких доменах.
- `wallet/core/src/wallet/mod.rs`:
  - `create_account_mldsa_master` создаёт аккаунт с корректным anchor/level.
  - `attach_stealth_to_master` и `detach_stealth_from_master` меняют payload’ы ожидаемым образом.

### 8.2. Миграционные и интеграционные тесты

- Миграция:
  - Открытие старого хранилища аккаунтов (без полей `master_anchor` / `delegation_id` в stealth‑payload’е) → новая версия корректно читает `stealth::Payload` v0 и записывает обратно v1 (`master_anchor=None`, `delegation_id=None`).
  - Проверка, что старые stealth‑аккаунты продолжают корректно работать без наличия master.
- Интеграция CLI:
  - Сценарий: создать кошелёк → создать master‑аккаунт → создать stealth‑аккаунт → привязать stealth к master → убедиться через `account list`, что привязка корректна.

### 8.3. Обновление матрицы тестов

- В `docs/plans/phase2/Phase2_MLDSA_master_key.md` и/или `docs/TEST_COVERAGE_SUMMARY.md`:
  - Добавить записи про unit‑тесты `mldsa_master`, миграционные тесты storage и CLI‑сценарий привязки.

## 9. Пошаговый план работ (чек‑лист Iteration 3)

1. **Типы и фабрика аккаунтов**
   - [x] Добавить `MLDSA_MASTER_ACCOUNT_KIND` и зарегистрировать фабрику `MldsaMasterAccount`.
   - [x] Обновить тесты/документацию по типам аккаунтов (alias `mldsa-master`).
2. **Модуль `mldsa_master`**
   - [x] Создать `wallet/core/src/account/variants/mldsa_master.rs` с payload’ом, статусами, `unlock_with_master_seed`, `sign_message`, `rotate`.
   - [x] Покрыть модуль unit‑тестами (payload валидация + domain tags).
3. **Хранилище и миграции**
   - [x] Определить `MldsaMasterAccountPayloadV1` как `AccountStorable` в модуле master‑аккаунта (magic/version, borsh).
   - [x] Расширить `StealthAccount` payload полями `master_anchor` и `delegation_id`, реализовать миграцию v0→v1.
4. **API кошелька**
   - [x] Добавить методы `create_account_mldsa_master`, `list_master_accounts`, `get_master_by_anchor`.
   - [x] Добавить методы `attach_stealth_to_master` и `detach_stealth_from_master` + фиксы блокировок/эвенты.
5. **CLI / WASM / FFI**
   - [x] Реализовать CLI-команды для создания/листинга master‑аккаунтов и привязки/отвязки stealth.
   - [x] Добавить методы в WASM и native API (FFI keep-alive через anchor/attach деталь в Iter.4).
6. **События и notify**
   - [x] Добавить новые события в `wallet/core/src/events.rs`.
   - [x] Notify/GUI подготовка: события доступны, интеграция GUI отложена в Iter.4.
7. **Документация и статус**
   - [x] Обновить `docs/api/MLDSA_MASTER.md` разделами про master‑аккаунт и привязку stealth.
   - [x] Обновить `docs/plans/phase2/Phase2_MLDSA_master_key.md` (статус Iteration 3 → Done).
   - [x] Добавить запись в `docs/IMPLEMENTATION_STATUS.md` о завершении Iteration 3.

**Definition of Done (для Iteration 3):**
- CLI/SDK позволяют создавать master‑аккаунт, листать их и привязывать stealth‑аккаунты к конкретному master.
- Все новые структуры корректно сериализуются/десериализуются, миграция старых аккаунтов проходит без потерь.
- Unit/интеграционные тесты зелёные, документация по master‑аккаунту и привязке stealth обновлена.


