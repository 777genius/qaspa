# Phase 2 — Iteration 6: Airgap UX и аппаратные кошельки

> Цель итерации: превратить протокол делегирования MLDSA‑master → stealth‑ветки в **офлайн‑дружественный** поток, который можно безопасно выполнять на полностью изолированном устройстве (air‑gapped desktop / аппаратный кошелёк), используя стабильные JSON/Borsh форматы `delegation_request` / `delegation_response` и консистентные API во всех клетках стека (CLI, wasm, native).

## 0. Контекст и границы итерации

- **Что уже есть к началу Iteration 6 (после Iter.1–5):**
  - Детерминированный MLDSA‑master из BIP39 (`MasterSeed`, `MasterAnchor`), хранение в `PrvKeyDataVariant::MlDsaMaster`, экспорт seed/anchor через API, CLI и wasm (`wallet master list/export`, `wallet.masterAnchors()`, `wallet.exportMasterAnchor()`).
  - Master‑аккаунт как отдельный `AccountKind` (`MldsaMasterAccount`), связка stealth ↔ master через `master_anchor` и `delegation_id` в payload (`wallet/core/src/account/variants/{mldsa_master,stealth}.rs`) — Iteration 3.
  - Протокол делегаций на уровне кошелька: структура `DelegationRecord`, хранение/миграции, TLV `delegation_id` в `StealthSigner`, RPC методы регистрации/чтения делегаций — Iteration 4.
  - Корректное сканирование/обработка UTXO с учётом делегаций, reorg и `valid_until_daa` — Iteration 5.
- **Чего не хватает:**
  - Устойчивых оффлайн‑форматов запроса/ответа (`delegation_request.json` / `delegation_response.json`), которые можно безопасно переносить между online и air‑gapped устройствами (USB/QR).
  - Строго определённого signable‑payload для мастера (`MasterDelegationRequest`), с домен‑сепарацией, checksum и защитой от подмены.
  - Консистентных API в `wallet/core` / wasm / native / CLI, чтобы:
    - online‑кошелёк мог **сформировать** запрос делегации без доступа к секрету мастера;
    - offline‑кошелёк с master‑ключом мог **подписать** запрос, не имея RPC и не раскрывая seed;
    - online‑кошелёк мог **применить** ответ (подписанные `DelegationRecord`) и обновить локальное состояние/ончейн‑метаданные.
- **Границы Iteration 6:**
  - Работаем **только** на уровне кошелька и клиентских API: никакие консенсусные правила, форматы транзакций и RPC протоколы не меняются.
  - Предполагается, что `DelegationRecord` и вся логика проверки делегаций (Iteration 4–5) уже реализованы; Iteration 6 надстраивает над ними оффлайн‑UX.
  - Не реализуем в этой итерации поддержку конкретных hardware‑кошельков (Trezor/Ledger и т.п.) — только абстрактный FFI/JSON интерфейс, который они могут позвать.

**Критерий успеха:** пользователь может полностью выполнить сценарий «создать делегацию для stealth‑аккаунта, подписать её на оффлайн‑устройстве, применить на online‑кошельке» с использованием стабильных JSON/Borsh форматов и CLI/SDK, не подключая мастер к сети.

## 1. Область изменений и файлы

| Подсистема | Файлы | Изменения |
|-----------|-------|-----------|
| Signable‑payload / хеширование | `wallet/core/src/message.rs` | Ввод `MasterDelegationRequestBody` / `MasterDelegationResponseBody`, функций хеширования с доменом `Delegation`, checksum `request_id`. |
| Wallet API messages | `wallet/core/src/api/message.rs` | Новые API‑сообщения: `MasterDelegationRequest`, `MasterDelegationResponse`, `MasterDelegationBuildRequest/Response`, `MasterDelegationApplyRequest/Response`. |
| Высокоуровневый wallet API | `wallet/core/src/wallet/api.rs`, `wallet/core/src/wallet/mod.rs` | Методы построения/применения делегаций: `build_master_delegation_request`, `apply_master_delegation_response` + `*_call()` реализации для `WalletApi`. |
| Wasm API (JS/TS) | `wallet/core/src/wasm/api/message.rs`, `wallet/core/src/wasm/wallet/wallet.rs` | TS‑интерфейсы `IMasterDelegationRequest/Response` и методы `wallet.buildMasterDelegationRequest(...)`, `wallet.applyMasterDelegationResponse(...)`. |
| Native FFI (desktop / hardware bridge) | `wallet/native/src/types.rs`, `wallet/native/src/runtime.rs` | C‑friendly структуры/функции для парсинга/генерации `MasterDelegationRequest/Response` из JSON/Borsh для оффлайн приложений. |
| CLI | `cli/src/modules/wallet.rs` | Новая команда `wallet master sign-delegation --input deleg.json --out deleg_signed.json` + helper’ы в `master_command`. |
| Документация | `docs/guides/master_cold_storage.md`, `docs/plans/phase2/Phase2_MLDSA_master_key.md`, `docs/IMPLEMENTATION_STATUS.md` | Новый гайд по cold storage, описание форматов `delegation_request` / `delegation_response`, обновление статуса Iteration 6. |
| Интеграционные тесты | `testing/integration/airgap_mldsa.rs` | E2E сценарии формирования запроса, оффлайн‑подписи и применения ответа. |

## 2. Дизайн форматов `MasterDelegationRequest/Response`

### 2.1. Модель данных и инварианты

- **Общие сущности:**
  - `DelegationRecord` (из Iteration 4) — полноразмерная делегация с подписью мастера.
  - `DelegationRecordHeader` — тот же payload **без** подписи; используется как signable‑часть.
  - `MasterDelegationRequestBody` — набор `DelegationRecordHeader` + метаданные с checksum.
  - `MasterDelegationResponseBody` — те же делегации, но уже с подписями (`DelegationRecord`) и ссылкой на исходный `request_id`.

### 2.2. Signable payload (wallet/core/src/message.rs)

В `wallet/core/src/message.rs` вводим структуры и функции хеширования (условный код для ориентира):

```rust
/// Хедер делегации без подписи (совпадает с DelegationRecord, но без поля `signature`).
#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(rename_all = "camelCase")]
pub struct DelegationRecordHeaderV1 {
    pub version: u8,
    pub anchor: [u8; 32],
    pub account_id: AccountId,
    pub spend_pubkey: [u8; 32], // XOnly Schnorr
    pub scan_pubkey: [u8; 32],  // XOnly Schnorr
    pub valid_from_daa: u64,
    pub valid_until_daa: Option<u64>,
    pub nonce: u64,
}

/// Signable тело запроса делегации (одна «сессия» делегирования).
#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(rename_all = "camelCase")]
pub struct MasterDelegationRequestBodyV1 {
    pub version: u8,
    pub master_anchor: [u8; 32],
    pub master_level: u8,               // MlDsaLevel
    pub network_id: NetworkId,          // для UX и безопасного отображения
    pub delegations: Vec<DelegationRecordHeaderV1>,
    pub created_at_unixtime: u64,       // timestamp формирования запроса (online)
    pub request_id: [u8; 32],           // checksum (см. ниже)
}
```

- **Инварианты:**
  - Все `delegations[i].anchor` **равны** `master_anchor` (иначе ошибка при парсинге).
  - `request_id` = `BLAKE2b-256("mldsa-delegation-request" || borsh_encode(body_without_request_id))`.
  - `master_level` должен совпадать с фактическим уровнем master‑ключа в оффлайн‑кошельке.
  - Вектор `delegations` может содержать несколько записей (batch делегаций для разных stealth‑аккаунтов), но все в одной сети и под одним master.

**Response‑payload:**

```rust
#[derive(Clone, Debug, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
#[serde(rename_all = "camelCase")]
pub struct MasterDelegationResponseBodyV1 {
    pub version: u8,
    pub master_anchor: [u8; 32],
    pub master_level: u8,
    pub request_id: [u8; 32],
    pub delegations: Vec<DelegationRecord>, // с валидными подписями MLDSA
}
```

- Инварианты:
  - `response.master_anchor` и `response.master_level` совпадают с оффлайн‑мастером.
  - Для каждого `DelegationRecord`:
    - `record.anchor == response.master_anchor`.
    - Подпись MLDSA проверяется под хешем `hash_delegation_header(header)` и доменом `MasterSignDomain::Delegation`.
  - `response.request_id` должен совпасть с `request.request_id` на online‑стороне, иначе ответ отвергается.

### 2.3. Домены хеширования и подписи

- В `crypto/mldsa/src/params.rs` уже заведён (или будет заведен в Iteration 3–4) домен:
  - `MASTER_SIGN_DOMAIN_DELEGATION = "kaspa.mldsa.delegation"`.
- Функции в `wallet/core/src/message.rs`:
  - `fn hash_delegation_header(header: &DelegationRecordHeaderV1) -> Hash256`.
  - `fn calc_request_id(body: &MasterDelegationRequestBodyV1) -> [u8; 32]` — BLAKE2b по описанной выше схеме.
- Мастер‑аккаунт (`MldsaMasterAccount`) использует эти функции в `sign_message(domain=Delegation, payload=borsh(header))`.

### 2.4. Транспортные форматы

- **Borsh:** используется как каноническое бинарное представление для:
  - Хеширования и подписи (signable‑payload).
  - Потенциальной сериализации в FFI, если аппаратный кошелёк предпочитает бинарный формат.
- **JSON (delegation_request.json / delegation_response.json):**
  - Использует Serde‑деривацию с `camelCase` полями.
  - Все массивы байт (`anchor`, pubkeys, `request_id`) сериализуются как hex‑строки (`"deadbeef..."`), совместимо с существующими `MasterAnchorInfo` и паттернами в `api/message.rs`.
  - JSON является основным форматом для CLI / desktop‑GUI / браузерных клиентов; внутри JSON содержимое строго соответствует Borsh‑структурам по полям и версиям.

Пример JSON‑структуры запроса (упрощённый):

```json
{
  "version": 1,
  "masterAnchor": "a1b2c3d4e5f6...",
  "masterLevel": 2,
  "networkId": "mainnet",
  "createdAtUnixtime": 1730000000,
  "delegations": [
    {
      "version": 1,
      "anchor": "a1b2c3d4e5f6...",
      "accountId": "stealth:abcd1234",
      "spendPubkey": "001122...",
      "scanPubkey": "334455...",
      "validFromDaa": 1000000,
      "validUntilDaa": 1100000,
      "nonce": 5
    }
  ],
  "requestId": "cafebabe..."
}
```

И ответ:

```json
{
  "version": 1,
  "masterAnchor": "a1b2c3d4e5f6...",
  "masterLevel": 2,
  "requestId": "cafebabe...",
  "delegations": [
    {
      "version": 1,
      "anchor": "a1b2c3d4e5f6...",
      "accountId": "stealth:abcd1234",
      "spendPubkey": "001122...",
      "scanPubkey": "334455...",
      "validFromDaa": 1000000,
      "validUntilDaa": 1100000,
      "nonce": 5,
      "signature": "mldsa_sig_base64_or_hex..."
    }
  ]
}
```

Точные типы и кодировки (hex/base64) фиксируются в `wallet/core/src/api/message.rs` и дублируются в `docs/guides/master_cold_storage.md` как часть формального контракта.

### 2.5. Версионирование и совместимость

- Поля `version` в `DelegationRecordHeaderV1`, `MasterDelegationRequestBodyV1` и `MasterDelegationResponseBodyV1`:
  - для первой версии жёстко фиксируем `version = 1`;
  - при появлении `V2`:
    - Borsh‑формат должен оставаться совместимым (новые поля с `#[borsh(default)]` / `Option<…>`),
    - логика валидации на online/offline стороне обязана проверять `version` и явно отказывать для неизвестных значений.
- В JSON:
  - `version` остаётся обязательным полем;
  - клиенты, не понимающие указанную версию, должны **отклонять** файл с чёткой ошибкой, а не пытаться интерпретировать частично.
- Хранилище делегаций:
  - при применении ответа Iteration 6 всегда пишет `V1`, даже если внутри уже есть записи других версий (миграция описывается в Iteration 7);
  - `request_id` служит сквозным идентификатором «сессии делегации» и хранится вместе с делегациями, чтобы можно было корректно повторно импортировать либо откатить конфликтующие ответы.

### 2.6. Тест‑векторы и межъязыковая консистентность

- На уровне `wallet/core` добавляем модуль тест‑векторов:
  - Генерация нескольких фиксированных `MasterDelegationRequestBodyV1` (1 делегация, несколько делегаций, разные `valid_until_daa`, разные `nonce`).
  - Вычисление `request_id` и сериализация в:
    - Borsh (байтовый массив);
    - JSON (строка).
- Эти векторы:
  - сохраняются в `docs/api/MLDSA_MASTER.md` как «канонические примеры»;
  - используются:
    - в wasm‑тестах (decode JSON → Rust → encode обратно);
    - в native FFI‑тестах;
    - в внешних интеграциях (hardware‑кошельки могут взять их как reference для проверки реализации).

## 3. Online‑поток: формирование `delegation_request.json`

### 3.1. Высокоуровневый сценарий

1. Пользователь на **online‑кошельке** выбирает master‑аккаунт и один или несколько stealth‑аккаунтов/веток для делегирования или ротации.
2. Кошелёк рассчитывает `DelegationRecordHeaderV1` для каждой ветки (используя уже реализованную логику Iteration 4: выбор `valid_from_daa`, `valid_until_daa`, `nonce`).
3. Формируется `MasterDelegationRequestBodyV1`:
   - `master_anchor` берётся из master‑аккаунта / `PrvKeyDataVariant::MlDsaMaster`.
   - `network_id` — текущая сеть кошелька (Mainnet/Testnet/Devnet).
   - `master_level` — `MlDsaLevel` мастера.
   - `created_at_unixtime` — текущий timestamp узла/клиента.
4. Вычисляется `request_id`, результат сериализуется:
   - в Borsh (для внутренних вызовов),
   - в JSON (`delegation_request.json`) для вывода пользователю.
5. Пользователь переносит файл/QR на оффлайн‑устройство.

### 3.2. Реализация в wallet/core

**Новые API‑сообщения (`wallet/core/src/api/message.rs`):**

- `MasterDelegationBuildRequest`:
  - Поля (концептуально, точные имена/типы описываем в коде):
    - `wallet_secret: Secret` — для доступа к stealth‑аккаунтам и проверок.
    - `master_anchor: Option<[u8;32]>` — если не указан, можно использовать `master_id`.
    - `master_id: Option<PrvKeyDataId>` — альтернатива `master_anchor`.
    - `targets: Vec<DelegationTarget>` — описания того, какие stealth‑аккаунты и каким окном DAA делегировать (account_id, optional valid_until и т.п.).
- `DelegationTarget`:
  - `account_id: AccountId` (stealth),
  - `valid_from_daa: Option<u64>` (если `None`, кошелёк возьмёт текущий DAA),
  - `valid_until_daa: Option<u64>`,
  - `nonce_hint: Option<u64>` (для advanced‑UX; по умолчанию кошелёк сам возьмёт `last_nonce+1`).
- `MasterDelegationBuildResponse`:
  - `request: MasterDelegationRequestBodyV1` (полностью заполненный payload),
  - `request_json: String` — JSON‑строка (`delegation_request.json`) готовая к сохранению/передаче.
  - (опционально) краткий summary для UI:
    - список `account_id`,
    - диапазон DAA по минимуму/максимуму,
    - количество делегаций.

**Метод в wallet (`wallet/core/src/wallet/mod.rs`):**

- `pub async fn build_master_delegation_request(&self, wallet_secret: &Secret, params: MasterDelegationBuildParams) -> Result<MasterDelegationRequestBodyV1>;`
  - Валидирует:
    - что master существует и активен (по anchor или `PrvKeyDataId`, используя `self.master_anchor_infos().await?` и/или `PrvKeyDataStore` — та же информация уже используется в Iteration 1–2);
    - что все `account_id` — stealth‑аккаунты в этом кошельке и (если требуется) уже привязаны к данному master (`master_anchor` совпадает, см. Iteration 3);
    - что `valid_from_daa` / `valid_until_daa` находятся в допустимых пределах (учитывая reorg/политику из Iteration 5 и `DaaScoreChange`, а также консенсусные параметры из `consensus/params.rs`);
    - что для каждого `(anchor, account_id)` корректно выбран `nonce` (`current_nonce + 1`, где текущее значение читается из стораджа делегаций).
  - Строит `DelegationRecordHeaderV1` и назначает `nonce` по правилам CRDT (из матрицы рисков).
  - Использует:
    - `self.network_id()?` для заполнения `network_id` в `MasterDelegationRequestBodyV1`;
    - `self.utxo_processor().current_daa_score()` как источник «текущего» DAA; при его отсутствии (кошелёк оффлайн) Flow либо:
      - явно требует подключения/синхронизации перед построением запроса;
      - либо запускается в деградирующем режиме с `valid_from_daa = 0` (такая политика должна быть чётко описана в гайде и, по умолчанию, отключена).
  - С точки зрения конкурентности:
    - как и другие методы Wallet (см. `wallet/core/src/wallet/api.rs`), вызов через `WalletApi` должен происходить под `WalletGuard`, чтобы построение запросов не пересекалось с параллельными миграциями/изменениями аккаунтов;
    - прямых запись/commit внутри `build_master_delegation_request` нет — функция чисто читает состояние и формирует signable‑payload.

**Реализация в WalletApi (`wallet/core/src/wallet/api.rs`):**

- `async fn master_delegation_build_request_call(self: Arc<Self>, request: MasterDelegationBuildRequest) -> Result<MasterDelegationBuildResponse>;`
  - Делегирует в `build_master_delegation_request`.
  - Оборачивает результат в JSON (`serde_json::to_string_pretty`) для UX и wasm.

### 3.3. Wasm / JS интерфейс

В `wallet/core/src/wasm/api/message.rs`:

- TS‑интерфейсы:
  - `IMasterDelegationBuildRequest` / `IMasterDelegationBuildResponse`.
  - `IMasterDelegationRequest` (отражение `MasterDelegationRequestBodyV1`) и `IMasterDelegationTarget`.
- Реализация `TryFrom`:
  - `IMasterDelegationBuildRequest -> MasterDelegationBuildRequest`.
  - `MasterDelegationBuildResponse -> IMasterDelegationBuildResponse` (с полями `request` и `requestJson`).

В `wallet/core/src/wasm/wallet/wallet.rs`:

- Метод:
  - `wallet.buildMasterDelegationRequest(request: IMasterDelegationBuildRequest): Promise<IMasterDelegationBuildResponse>;`
  - Для браузера будет основным способом получить `delegation_request.json` и сразу превратить его в QR.

## 4. Offline‑поток: `master sign-delegation` и `delegation_response.json`

### 4.1. UX и безопасность

- Оффлайн‑устройство **никогда не обращается к RPC** и не хранит транзакционную историю — только расшифровывает `MasterSeed`, вычисляет master‑ключ, проверяет соответствие `master_anchor`, отображает пользователю параметры делегаций и подписывает их.
- Основные UX‑элементы:
  - Отображение `master_anchor` (первые 8–12 hex символов) и `network_id`.
  - Список делегируемых stealth‑аккаунтов (по `account_id` + user‑friendly label, если известен из локального хранилища).
  - Диапазон DAA (`valid_from` / `valid_until`) и количество UTXO/адресов, которые потенциально будут подпадать под делегацию (если эту мета‑информацию online‑кошелёк положил в request).
  - Жёсткое подтверждение пользователем (`Type 'DELEGATE' to confirm` / аппаратная кнопка).

### 4.2. Реализация CLI: `wallet master sign-delegation`

В `cli/src/modules/wallet.rs`:

- Внутри `master_command` добавляем ветку:

```text
wallet master sign-delegation --input <path|-?> --out <path|-?>
```

- Поведение:
  1. Проверить, что кошелёк открыт и содержит хотя бы один `PrvKeyDataVariant::MlDsaMaster`.
  2. Прочитать `delegation_request.json`:
     - Если `--input -` → читать из stdin.
     - Иначе — из указанного файла.
  3. Распарсить JSON → `MasterDelegationRequestBodyV1`, пересчитать `request_id` и сверить с полем:
     - Несовпадение → ошибка (`Invalid delegation_request checksum`) с указанием вычисленного и присланного значений (для диагностики, но без логирования полного запроса).
  4. Проверить `network_id`:
     - если локальный `wallet.network_id()` отличается от `request.network_id` → по умолчанию завершить с ошибкой;
     - если указан флаг `--force-network-mismatch` → продолжить, но вывести жирное предупреждение в stderr.
  5. Найти мастер:
     - По `master_anchor` из запроса среди `master_anchor_infos()`.
     - Если не найден — попросить пользователя выбрать из списка возможных (`id` / `anchor`), но по умолчанию — ошибка.
  6. Запросить `wallet_secret` и (при необходимости) `payment_secret` для расшифровки master‑seed.
  7. Для каждой `DelegationRecordHeaderV1`:
     - Вычислить `hash = hash_delegation_header(header)`.
     - Подписать через `MldsaMasterAccount::sign_message(domain=Delegation, payload=borsh(header))`.
     - Сформировать `DelegationRecord` (header + signature).
  8. Собрать `MasterDelegationResponseBodyV1`:
     - `master_anchor`, `master_level`, `request_id` из входа.
     - `delegations` — полученные `DelegationRecord`.
  9. Сериализовать в JSON (`delegation_response.json`) и/или бинарный Borsh:
     - `--out -` → STDOUT, иначе — запись в файл.
  10. Обнулить секреты в памяти и вывести краткую сводку:
      - количество делегаций;
      - минимальный/максимальный DAA по всем записям;
      - обрезанный `request_id` и `master_anchor` (fingerprint).
  11. Дополнительные флаги UX‑уровня:
      - `--summary-only` — печатать только сводку, не дублируя JSON в stdout;
      - `--no-confirm` — отключить интерактивное подтверждение (для автоматизированных сценариев, по умолчанию выключено).

### 4.3. Реализация в wallet/core (оффлайн часть)

- В `wallet/core/src/wallet/mod.rs`:
  - Метод `pub async fn sign_master_delegation_request(&self, wallet_secret: &Secret, request: MasterDelegationRequestBodyV1) -> Result<MasterDelegationResponseBodyV1>;`
    - Локально ищет `PrvKeyDataVariant::MlDsaMaster` с anchor == `request.master_anchor`.
    - Декриптует seed и строит временный `MlDsaKeypair` (в Zeroizing‑обёртке).
    - Для каждого header вызывает `sign_message(MasterSignDomain::Delegation, borsh(header))`.
    - Собирает `DelegationRecord` + response body.
    - Не трогает RPC и не пишет изменения в storage (это делает online‑кошелёк при импорте).

- В `wallet/core/src/wallet/api.rs`:
  - Для offline‑встраивания через `WalletApi` можно добавить:
    - `async fn master_delegation_sign_call(self: Arc<Self>, request: MasterDelegationSignRequest) -> Result<MasterDelegationResponse>;`
    - Где `MasterDelegationSignRequest` содержит `wallet_secret` и `MasterDelegationRequestBodyV1`.

### 4.4. Native FFI / hardware‑интеграция

В `wallet/native/src/types.rs` и `runtime.rs`:

- Определить C‑совместимые структуры:
  - `KaspaMasterDelegationRequest` (минимальный view: anchor, level, network_id, counts, packed JSON pointer).
  - `KaspaMasterDelegationResponse` (в основном указатель на JSON/Borsh, который можно отдать обратно online‑кошельку).
- Функции:
  - `kaspa_wallet_mldsa_delegation_request_parse(json_ptr, json_len, out_summary_ptr, ...) -> bool;`
  - `kaspa_wallet_mldsa_delegation_sign(json_ptr, json_len, wallet_secret_ptr, ..., out_json_ptr, out_json_len, ...) -> bool;`
- Цель: дать desktop‑приложению или hardware‑браузеру минимальный API, не погружая их в детали Borsh/DelegationRecord, но опираясь на JSON‑форматы.

- Модель владения памятью:
  - следовать уже принятому в `wallet/native` паттерну:
    - все буферы, которые аллоцирует Rust‑сторона (строки JSON, summary‑структуры), освобождаются отдельными `*_free`‑функциями;
    - FFI‑контракты чётко помечают, кто владеет буфером в каждый момент;
  - структура summary (`KaspaMasterDelegationSummary` или аналог) может содержать:
    - укороченный `master_anchor`;
    - `network_id`;
    - количество делегаций;
    - флаги/маски ошибок парсинга (например, invalid checksum / unsupported version).

## 5. Online‑поток: импорт `delegation_response.json` и применение делегаций

### 5.1. Логика применения в wallet/core

В `wallet/core/src/api/message.rs`:

- `MasterDelegationApplyRequest`:
  - Поля:
    - `wallet_secret: Secret` — для записи в storage.
    - `request: MasterDelegationRequestBodyV1` — оригинальный запрос (опционально, если хранится локально — можно передавать только `request_id`).
    - `response: MasterDelegationResponseBodyV1`.
- `MasterDelegationApplyResponse`:
  - `applied: usize` — количество успешно применённых делегаций.
  - `skipped: usize` — количество пропущенных (например, из‑за stale `nonce`).

В `wallet/core/src/wallet/mod.rs`:

- `pub async fn apply_master_delegation_response(&self, wallet_secret: &Secret, request: MasterDelegationRequestBodyV1, response: MasterDelegationResponseBodyV1) -> Result<MasterDelegationApplyStats>;`
  - Проверки:
    - `response.request_id == request.request_id`.
    - `response.master_anchor == request.master_anchor`, `response.master_level == request.master_level`.
    - Размеры массивов совпадают или допускают подмножество (ответ может содержать только часть делегаций).
  - Для каждого `DelegationRecord`:
    - Восстановить `DelegationRecordHeaderV1` из record и сравнить с исходным header из запроса.
    - Перепроверить подпись MLDSA (через `MasterSignDomain::Delegation` и публичный мастер‑ключ, восстановленный по anchor).
    - Проверить `nonce`: он должен быть > текущего `delegation_nonce` для данной `(anchor, account_id)`; при нарушении — пометить как `skipped`.
  - При успехе:
    - Сохранить `DelegationRecord` в `wallet/core/src/account/delegation.rs` хранилище.
    - Обновить payload stealth‑аккаунта: `delegation_id` (ссылка на новую запись), `master_anchor` (если не установлен).
    - Эмитить события `MasterDelegationCreated` / `MasterDelegationRotated` / `MasterDelegationRevoked` (зависит от типа делегации, см. Iteration 4).
    - Закоммитить storage (`store.commit(wallet_secret)`).

### 5.2. API, wasm и CLI

- В `wallet/core/src/wallet/api.rs`:
  - `async fn master_delegation_apply_call(self: Arc<Self>, request: MasterDelegationApplyRequest) -> Result<MasterDelegationApplyResponse>;`
- В `wallet/core/src/wasm/api/message.rs`:
  - TS‑интерфейсы `IMasterDelegationApplyRequest/Response`, прокси к Rust‑структурам.
- В `wallet/core/src/wasm/wallet/wallet.rs`:
  - `wallet.applyMasterDelegationResponse(request: IMasterDelegationApplyRequest): Promise<IMasterDelegationApplyResponse>;` — основной entrypoint для браузерных/desktop‑клиентов.
- В CLI (`cli/src/modules/wallet.rs`):
  - Дополнительная online‑команда:

```text
wallet master apply-delegation --input deleg_signed.json
```

  - Использует WalletApi через RPC (или локально) для применения делегаций.

### 5.3. Конфликты, многоустройственность и edge‑cases

- **Повторный импорт одного и того же ответа:**
  - при повторном вызове `apply_master_delegation_response` с тем же `request_id` и теми же делегациями:
    - если `nonce` и содержимое записей совпадают с уже применёнными — операции должны быть idempotent (ничего не менять, но считать `applied` == 0, `skipped` == N);
    - если `nonce` совпадает, но содержимое отличается → жёсткая ошибка `DelegationConflict`, так как это сигнал подделки/рассинхронизации.
- **Ответы с пересекающимися nonce с разных устройств:**
  - CRDT‑правило: для пары `(anchor, account_id)` принятым считается **последний** по `nonce` валидный `DelegationRecord`;
  - если online‑кошелёк получает response, в котором есть запись с `nonce < current_nonce`:
    - такая запись помечается как `skipped` без изменения storage (даже если подпись валидна);
    - в событиях и логах явно фиксируем, что получилаcь устаревшая делегация (можно мапить на `MasterDelegationOutdated` в Iteration 7).
- **Несогласованный `network_id`:**
  - если `request.network_id` не совпадает с `wallet.network_id()` на online‑ или offline‑стороне:
    - CLI/SDK должны показать предупреждение (например, «request built for testnet, but wallet is on mainnet»);
    - по умолчанию блокируем операцию и требуем явного флага `--force-network-mismatch`, чтобы оператор осознанно подтвердил действие.
- **Отсутствие локального аккаунта:**
  - если при apply найдена делегация для `account_id`, которого нет в этом кошельке:
    - такая запись помечается как `skipped`;
    - в ответе/событиях фиксируем `missing_account_ids`, чтобы интеграторы могли подсветить несогласованные устройства.

### 5.4. Взаимодействие с StealthAccount и EphemeralKeyStore

Несмотря на то, что основная привязка делегаций к UTXO/эфемерным ключам реализуется в Iteration 4–5, Iteration 6 должен аккуратно «подшить» результаты оффлайн‑подписи к уже существующему стэку:

- При успешном `apply_master_delegation_response`:
  - структуры делегаций **не меняют** формат `EphemeralKeyEntry` и не влезают напрямую в `EphemeralKeyStore` (весь DAA/anchor‑контекст уже описан в плане Iteration 5 и реализуется там);
  - стелс‑аккаунт получает актуальную `delegation_id`/`master_anchor` в своём payload; при следующем скане или пересборке `EphemeralKeyStore` (см. `StealthAccount::try_claim_utxo_internal`) эти поля используются для пометки UTXO делегированной веткой.
- Потоки:
  - online‑кошелёк может создать и применить делегации **до** появления первых стелс‑UTXO — это важно для UX (создать аккаунт → сразу задать политики делегаций);
  - если делегация применяется после того, как часть UTXO уже найдена (через старую или «no‑delegation» логику):
    - Iteration 5 описывает, как повторное сканирование и DAA‑хуки (`DaaScoreChange`) помечают старые UTXO как orphaned или перепривязывают к новой делегации;
    - Iteration 6 **не** меняет эту механику, но **должен** убедиться, что apply не приводит к неожиданным потерям ключей (EphemeralKeyStore не трогается напрямую, только делегационное хранилище и account payload).

### 5.5. Ошибки и коды возврата

Для консистентного UX между Rust/CLI/wasm/native Iteration 6 вводит чётко нормализованный набор ошибок делегации:

- На уровне Rust:
  - в `wallet/core` добавляется либо отдельный `enum MasterDelegationError`, либо расширение существующего `WalletError` с семейством под‑ошибок:
    - `InvalidRequestChecksum`;
    - `UnsupportedVersion`;
    - `MasterAnchorNotFound`;
    - `MasterLevelMismatch`;
    - `NetworkMismatch`;
    - `StaleNonce`;
    - `DelegationConflict`;
    - `MissingAccount`;
    - `StorageFailure` / `CryptoFailure`.
  - Эти ошибки используются в:
    - `build_master_delegation_request`;
    - `sign_master_delegation_request`;
    - `apply_master_delegation_response`.
- CLI:
  - маппит ошибки на коды выхода:
    - `Usage / InvalidRequestChecksum / UnsupportedVersion` → код «bad input»;
    - `NetworkMismatch / MasterAnchorNotFound / MissingAccount` → «configuration/env error»;
    - `DelegationConflict / StaleNonce` → отдельная категория, которую UI может показать как «конфликт политики»;
    - `StorageFailure / CryptoFailure` → «internal error».
  - текст ошибок аккуратно формулируется без утечки чувствительных данных (без полного дампа JSON).
- WASM / JS:
  - оборачивает ошибки в `JsError`/`Error` с полями:
    - `code` (одна из строковых констант, соответствующих видам ошибок выше);
    - `message` (локализуемое описание);
    - (опционально) `requestId` / `anchorFingerprint` для привязки к UI.

## 6. Документация: `master_cold_storage.md`

### 6.1. Структура гайда

- **Раздел 1. Концепция Master & Delegations:**
  - Краткое напоминание о роли MLDSA‑master, anchor и делегаций.
- **Раздел 2. Поток «первое делегирование»:**
  - Шаги на online‑кошельке: выбор master/stealth, запуск `buildMasterDelegationRequest`, сохранение/печать `delegation_request.json` + QR.
  - Шаги на оффлайн‑кошельке: импорт `delegation_request.json`, визуальная проверка параметров, `sign-delegation`, получение `delegation_response.json`.
  - Возврат на online‑кошелёк и `apply-delegation`.
- **Раздел 3. Ротация и отзыв делегаций:**
  - Как формируется новый запрос на ротацию (`valid_until_daa` для старой ветки, новый header для новой).
  - UX‑подсказки / предупреждения.
- **Раздел 4. Checklist хранения и threat‑model:**
  - Как хранить `delegation_request` / `delegation_response`.
  - Как проверять `request_id`, anchor, network_id.
  - Риски airgap‑компрометации и как их минимизировать (отдельный ПК, проверка checksum на обоих концах).

### 6.2. Синхронизация с главным планом

- В `docs/plans/phase2/Phase2_MLDSA_master_key.md`:
  - Ссылки на новый гайд (`docs/guides/master_cold_storage.md`) в секциях Iteration 6 и Risks/DoD.
- В `docs/IMPLEMENTATION_STATUS.md`:
  - Обновить статус Phase 2: Iteration 6 → In progress / Done, со ссылками на PR и тесты.

### 6.3. События и observability вокруг Airgap‑потока

На уровне событий (`wallet/core/src/events.rs`, wasm‑обёртка и notify/GUI) Iteration 6 добавляет:

- Новые события:
  - `MasterDelegationRequestBuilt { master_anchor, request_id, targets: Vec<AccountId> }` — успешное формирование оффлайн‑запроса.
  - `MasterDelegationSignedOffline { master_anchor, request_id, delegations: usize }` — зафиксирован факт применения подписанного ответа (даже если часть делегаций была `skipped`).
  - `MasterDelegationApplyFailed { master_anchor, request_id, reason: String }` — типизированные ошибки (конфликт nonce, mismatch network_id и т.п.).
- Требования:
  - события должны быть сериализуемы в WASM/JS (см. паттерны для `MasterAnchorCreated` / `MasterSeedExported`);
  - notify‑слой/GUI может использовать их для:
    - подсветки статуса «запрос сформирован, ожидается оффлайн‑подпись»;
    - отображения прогресса и ошибок при импорте `delegation_response.json`.

## 7. Тестирование и критерии готовности

### 7.1. Unit‑тесты

- `wallet/core/src/message.rs`:
  - Roundtrip `DelegationRecordHeaderV1` и `MasterDelegationRequestBodyV1` через Borsh/Serde.
  - Проверка, что `calc_request_id` детерминирован и чувствителен к любому изменению полей.
  - Проверка `hash_delegation_header` + верификация подписи MLDSA под доменом Delegation.
- `wallet/core/src/api/message.rs` и wasm‑bridge:
  - JS‑roundtrip для `IMasterDelegationRequest/Response` аналогично существующим тестам для `MasterAnchorList`.

### 7.2. Integration: `testing/integration/airgap_mldsa.rs`

Сценарии:

1. **Базовый happy‑path:**
   - Поднять devnet, включить `enable_mldsa_master`.
   - Создать кошелёк, master и stealth‑аккаунт, привязать stealth к master.
   - Вызвать `build_master_delegation_request` → сохранить JSON.
   - Смоделировать оффлайн‑подпись, вызвав `sign_master_delegation_request` в отдельном процессе/инстансе без RPC.
   - Вернуть `delegation_response` и вызвать `apply_master_delegation_response`.
   - Отправить транзакцию из stealth‑аккаунта, убедиться что UTXO находится и spend проходит.
2. **Stale/nonced replay:**
   - Сформировать две делегации с одинаковыми `(anchor, account_id)` и разными `nonce`, убедиться, что более старая (`nonce` меньше) отклоняется при apply.
3. **Tampering:**
   - Изменить один из полей в `delegation_request.json` (например, `valid_until_daa`) без пересчёта `request_id` → оффлайн‑подпись должна отвергнуть файл.
   - Изменить `request_id` в `delegation_response.json` → online‑импорт должен завернуться с ошибкой.
4. **Network mismatch:**
   - Собрать `delegation_request.json` для testnet, попытаться применить/подписать его на mainnet‑кошельке без флага `--force-network-mismatch` → операция блокируется с понятной ошибкой.
5. **Missing accounts / частичный импорт:**
   - Создать запрос, содержащий делегации для нескольких stealth‑аккаунтов, затем применить ответ в кошельке, где присутствует только подмножество этих аккаунтов → убедиться, что часть делегаций `applied`, часть `skipped` с корректным отчётом.

### 7.3. Definition of Done (для Iteration 6)

- **Форматы:**
  - Структуры `MasterDelegationRequestBodyV1` / `MasterDelegationResponseBodyV1` и `DelegationRecordHeaderV1` реализованы, снабжены тестами roundtrip и документированы.
- **API и UX:**
  - Есть рабочие методы `buildMasterDelegationRequest` / `applyMasterDelegationResponse` в WalletApi (Rust, wasm, native).
  - CLI команды `wallet master sign-delegation` и `wallet master apply-delegation` покрывают базовый оффлайн‑поток.
- **Тесты:**
  - Unit‑тесты на хеширование/подписи и wasm‑bridge зелёные.
  - Интеграционный тест `airgap_mldsa` проходит, демонстрируя полный сценарий online → offline → online.
  - Для всех опубликованных тест‑векторов (секция 2.6) оффлайн‑ и онлайн‑реализации (Rust, wasm, native FFI) дают бит‑к‑биту совпадающие результаты `request_id` и сериализаций.
- **Документация:**
  - `docs/guides/master_cold_storage.md` заполнен и согласован с `Phase2_MLDSA_master_key.md`.
  - `docs/IMPLEMENTATION_STATUS.md` обновлён с указанием статуса Iteration 6 и ссылками на ключевые артефакты (форматы, команды, тесты).

## 8. Чеклист Iteration 6

1. **Форматы и хеширование**
   - [ ] Добавить `DelegationRecordHeaderV1`, `MasterDelegationRequestBodyV1`, `MasterDelegationResponseBodyV1` и функции `hash_delegation_header` / `calc_request_id` в `wallet/core/src/message.rs`.
   - [ ] Прописать домен `MASTER_SIGN_DOMAIN_DELEGATION` в `crypto/mldsa/src/params.rs` и интегрировать его в `MldsaMasterAccount::sign_message`.
   - [ ] Покрыть форматами unit‑тесты (Borsh/Serde roundtrip, чувствительность `request_id`).
2. **Wallet core API**
   - [ ] Расширить `wallet/core/src/api/message.rs` типами `MasterDelegationBuildRequest/Response`, `MasterDelegationApplyRequest/Response`.
   - [ ] Реализовать методы `build_master_delegation_request`, `sign_master_delegation_request`, `apply_master_delegation_response` в `wallet/core/src/wallet/mod.rs`.
   - [ ] Прописать соответствующие `*_call()` реализации в `wallet/core/src/wallet/api.rs`.
3. **WASM / JS / Native**
   - [ ] Добавить TS‑интерфейсы и `try_from!`‑мэппинги для делегационных запросов/ответов в `wallet/core/src/wasm/api/message.rs`.
   - [ ] Расширить `wallet/core/src/wasm/wallet/wallet.rs` методами `buildMasterDelegationRequest` и `applyMasterDelegationResponse`.
   - [ ] Добавить FFI‑структуры и функции `kaspa_wallet_mldsa_delegation_*` в `wallet/native/src/{types,runtime}.rs`.
4. **CLI**
   - [ ] Реализовать `wallet master sign-delegation` и `wallet master apply-delegation` в `cli/src/modules/wallet.rs` с поддержкой stdin/stdout и файлов.
   - [ ] Добавить help‑тексты и UX‑подсказки (network mismatch, re‑use, хранение файлов).
5. **Интеграционные тесты**
   - [ ] Реализовать `testing/integration/airgap_mldsa.rs` со сценариями happy‑path, replay и tampering.
   - [ ] Включить тест в соответствующий workspace crate и CI матрицу.
6. **Документация и статус**
   - [ ] Написать/обновить `docs/guides/master_cold_storage.md`.
   - [ ] Синхронизировать `docs/plans/phase2/Phase2_MLDSA_master_key.md` и `docs/IMPLEMENTATION_STATUS.md` со статусом Iteration 6.

## 9. Безопасность и threat‑model, специфичные для Iteration 6

1. **Подмена `delegation_request.json` по пути online → offline:**
   - Защита: `request_id` считается по Borsh‑payload’у; offline‑сторона **обязана** пересчитывать его и сравнивать с полем в JSON.
   - Если anchor/nonce/DAA‑окна меняются, но `request_id` нет — файл немедленно отвергается; CLI/SDK должны логировать, какие поля не совпали при диагностике.
2. **Подмена `delegation_response.json` по пути offline → online:**
   - Online‑кошелёк перепроверяет:
     - `request_id`, `master_anchor`, `master_level`;
     - каждую MLDSA‑подпись на основе локально известного master‑паблика;
     - что `DelegationRecord` строго соответствует `DelegationRecordHeaderV1` из сохранённого/переданного запроса.
   - Любое расхождение трактуется как атака/рассинхронизация, apply отклоняется целиком.
3. **Кража/утечка `delegation_request`/`delegation_response`:**
   - Сами по себе эти файлы **не содержат** master‑seed и не позволяют восстановить MLDSA‑ключи; риск — раскрытие структуры делегаций и stealth‑веток (privacy, но не custody).
   - Гайд `master_cold_storage.md` должен явно указать, что:
     - эти файлы можно хранить менее строго, чем сид, но всё равно не публиковать;
     - при компрометации делегаций пользователь может ревокнуть/ротировать их в Iteration 4/5.
4. **Ошибки в UX (не тот anchor / не та сеть):**
   - Все CLI/SDK entrypoint’ы обязаны:
     - показывать `master_anchor` (обрезанный) и `network_id` перед подтверждением;
     - при несовпадении сети требовать явного `--force-network-mismatch`.
5. **Offline‑устройство с частично скомпрометированным окружением:**
   - Вся криптография (подпись MLDSA) должна выполняться в памяти процесса, без записи seed на диск.
   - Там, где это возможно, использовать `Zeroizing` для master‑seed и временных буферов; Iteration 2 уже заложил этот паттерн, Iteration 6 использует те же абстракции (`MlDsaMasterPayload::decrypt_seed` и т.п.).
6. **Логирование и аудит:**
   - Логи online/offline‑кошелька:
     - не содержат полный JSON‑контент запросов/ответов и не логируют `spending_secret`/seed;
     - могут включать только:
       - обрезанные `request_id` и `master_anchor`;
       - количество делегаций;
       - коды ошибок (см. 5.5).
   - Для аудита можно включить более подробный режим (debug‑лог), но только по явному флагу и с предупреждением пользователю о рисках.

## 10. UX/производительность и практические ограничения

- **Размер артефактов:**
  - Одна MLDSA‑подпись ~2.4 KB → одна делегация в `delegation_response.json` ~3 KB с оверхедом полей.
  - Для `N` делегаций:
    - файл может достигать десятков/сотен KB, что важно для QR‑кодирования;
    - гайд должен рекомендовать разумные размеры batch’ей (например, <= 32 делегаций за раз).
- **QR‑кодирование:**
  - Браузерный/desktop‑клиент может:
    - либо использовать single‑QR для небольших файлов (ограничение ≈ 2–3 KB полезной нагрузки),
    - либо реализовать простой chunking (`part`, `total`, `request_id`) для многостраничных QR (это может быть отдельным под‑планом, но формат chunk’ов стоит описать хотя бы на conceptual‑уровне).
- **Время выполнения:**
  - Подпись MLDSA относительно тяжёлая; при большом количестве делегаций offline‑подпись может занимать заметное время.
  - CLI/GUI должны:
    - показывать прогресс (count/total);
    - не блокировать UI‑поток (особенно в wasm, использовать async/await и таймеры для репортинга прогресса).
- **Совместимость с существующими устройствами:**
  - Дизайн форматов (`version`, `request_id`, hex‑поля) должен быть достаточно простым, чтобы его могли реализовать сторонние HSM/аппаратные кошельки без глубокого понимания стека Kaspa.
  - Для них основной контракт — это: «получаю JSON/Borsh с полями, считаю hash по описанной схеме, подписываю MLDSA, возвращаю тот же JSON с подписью».

## 11. Разбиение на PR и порядок внедрения

Чтобы минимизировать риск регрессий и упростить ревью, Iteration 6 разумно разбить на несколько последовательных PR:

1. **Базовые форматы и ядро wallet‑core**
   - PR‑1:
     - добавить новые структуры и функции в `wallet/core/src/message.rs`;
     - завести домен `MASTER_SIGN_DOMAIN_DELEGATION` в `crypto/mldsa/src/params.rs`;
     - внедрить минимальные unit‑тесты (Rust‑уровень, без wasm/CLI).
   - Без внешнего API/CLI; изменение касается только внутренних модулей.
2. **Wallet API и делегационное хранилище**
   - PR‑2:
     - дополнить `wallet/core/src/api/message.rs` и `wallet/core/src/wallet/api.rs` типами/методами `MasterDelegationBuild*` и `MasterDelegationApply*`;
     - реализовать `build_master_delegation_request`, `sign_master_delegation_request`, `apply_master_delegation_response` в `wallet/core/src/wallet/mod.rs`;
     - адаптировать интеграционные тесты, которые напрямую используют `WalletApi` (без wasm).
3. **WASM / JS‑мост**
   - PR‑3:
     - добавить TS‑интерфейсы и `try_from!`‑мэппинги в `wallet/core/src/wasm/api/message.rs`;
     - расширить `wallet/core/src/wasm/wallet/wallet.rs` новыми методами;
     - обновить/добавить wasm‑тесты (по аналогии с существующими тестами для `MasterAnchorListResponse` / `MasterSeedExport`).
4. **Native FFI и desktop‑runtime**
   - PR‑4:
     - расширить `wallet/native/src/{types,runtime}.rs` C‑совместимыми структурами и функциями для парсинга/подписи делегаций;
     - добавить базовые C‑уровневые тесты (если инфраструктура позволяет) или хотя бы Rust‑тесты, проверяющие roundtrip JSON → FFI‑структуры → JSON.
5. **CLI команды и UX**
   - PR‑5:
     - добавить `wallet master sign-delegation` и `wallet master apply-delegation` в `cli/src/modules/wallet.rs`;
     - обеспечить корректную интеграцию с существующим `master_command` и help‑текстами;
     - добавить smoke‑тесты CLI (по возможности) и обновить документацию/usage‑примеры.
6. **Интеграционный тест `airgap_mldsa` и доки**
   - PR‑6:
     - реализовать `testing/integration/airgap_mldsa.rs` с полным e2e потоком;
     - написать/актуализировать `docs/guides/master_cold_storage.md`;
     - обновить `Phase2_MLDSA_master_key.md` и `IMPLEMENTATION_STATUS.md` в части Iteration 6.

Каждый из этих шагов можно выполнять и мёржить независимо, при этом в любой момент времени проект остаётся собираемым и совместимым с существующими клиентами.


