# Phase 2 — Iteration 5: Stealth scan, reorg & ephemeral key lifecycle

> Цель итерации: сделать так, чтобы стелс‑кошелёк корректно восстанавливал и сопровождал UTXO, опираясь на мастер‑делегации, не терял ключи на реоргах и умел эффективно отбрасывать «чужие» якоря на мобильных клиентах.

## 0. Контекст и границы итерации

- **Что уже есть к началу Iteration 5:**
  - Phase 1: стелс‑адреса на secp256k1, `StealthAccount`, `EphemeralKeyStore`, fallback‑сканирование через `get_utxos_by_script_version` и `get_block_view_tags` (`testing/integration/src/stealth_flow.rs` покрывает базовые сценарии).
  - Iteration 1–2: детерминированный MLDSA master (`MasterSeed`, `MasterAnchor`), безопасное хранение в `PrvKeyDataVariant::MlDsaMaster`, FFI/WASM/CLI команды (`master list/export/verify-anchor`), события `MasterAnchorCreated`, `MasterSeedExported`.
  - Iteration 3: `MldsaMasterAccount`, привязка стелс‑аккаунтов к master через `master_anchor` в payload, базовый UX/CLI/SDK вокруг мастер‑аккаунтов.
  - Iteration 4 (предполагается завершённой к старту Iteration 5): структура `DelegationRecord`, хранение делегаций в `wallet/core`, `StealthAccount` знает о текущей мастер‑делегации, RPC `register_mldsa_anchor` / `list_mldsa_delegations`, TLV `delegation_id` в стелс‑подписях, обновлённые CLI/SDK сценарии `link-stealth-to-master`, revoke/rotate.
- **Что делаем в Iteration 5:**
  - Ужесточаем сканер и UTXO‑пайплайн так, чтобы каждый стелс‑UTXO был связан с конкретной делегацией (anchor + pubkeys + DAA‑окно), а при несоответствии помечался как «orphaned».
  - Расширяем `EphemeralKeyStore` метаданными делегации (`delegation_id`, `anchor`, `valid_from_daa`, `valid_until_daa`) и политиками очистки, устойчивыми к реоргам.
  - Добавляем в RPC `get_block_view_tags` поле `anchor_hint` (best‑effort, опционально), плюс лёгкий индексатор/кэш, который позволяет отдавать хинты без повторного разбора скриптов.
  - Вводим новые wallet‑события (`MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch`) и обновляем интеграционные тесты на реорги и восстановление после делегаций.
- **Чего НЕ делаем в Iteration 5:**
  - Не меняем консенсусные скрипты и не добавляем ончейн‑формат для анкера (ScriptPublicKey остаётся тот же, все изменения — на уровне кошелька/RPC).
  - Не реализуем полноценный CRDT‑синк делегаций между устройствами (это остаётся на Iteration 6/7).
  - Не внедряем BIP158/compact filters — только view tags и лёгкий якорный кэш (см. `docs/todo/stealth_view_tags.md` и план Phase 2).

**Критерий успеха:** при включённом master‑режиме кошелёк:
1. При скане находит только те стелс‑UTXO, которые покрыты активными делегациями; остальные помечаются как orphaned и не используются для новых трат.
2. Не теряет ключи при реоргах в пределах DAA‑окна действия делегации.
3. Может после восстановления из сид‑а и загрузки делегаций переиздать/перепривязать UTXO, не переподписывая историю.
4. RPC `get_block_view_tags` выдаёт `anchor_hint` (когда это возможно), позволяя мобильному клиенту быстро отфильтровать блоки по своим якорям.

### 0.1. Архитектурный TL;DR (быстрый конспект для ревью и реализации)

1. **EphemeralKeyStore как источник правды.**  
   В Iteration 4 `EphemeralKeyEntry` уже получил поля `master_anchor` и `delegation_id` + ручной `BorshDeserialize`; в Iteration 5 мы добавляем `created_daa_score`, `valid_until_daa` и новые статусы `Orphaned { OrphanReason }` / `Expired`, по‑прежнему без отдельного v1‑типа: старые файлы читаются как `created_daa_score = 0`, `valid_until_daa = None`, `master_anchor/delegation_id = None`.
2. **Жёсткая связь стелс‑UTXO ↔ делегация.**  
   При успешном `try_claim_utxo_internal` каждый стелс‑UTXO либо однозначно покрыт окном `DelegationRecord` по `(account_id, anchor, valid_from/valid_until, nonce)`, либо считается orphaned (см. §2.1–2.4). Для orphaned‑случаев мы всё равно сохраняем `EphemeralKeyData`.
3. **Overlay вместо правки общего UTXO‑пайплайна.**  
   `UtxoContext` и `TransactionRecord` не меняются; orphan‑статус живёт в `OrphanOverlayMap` внутри `StealthAccount` и восстанавливается из `EphemeralKeyStore` + `UtxoContext` (см. §3.4–3.5). Любые изменения делегаций/DAA сначала попадают в `EphemeralKeyStore`, затем отражаются в overlay.
4. **DAA‑чистка и reorg‑устойчивость.**  
   Через `StealthUtxoHandler::on_daa_score_changed` стелс‑аккаунт вызывает `EphemeralKeyStore::cleanup_expired(current_daa_score)` и проверку истечения делегаций (см. §3.1–3.3). До `valid_until_daa + safety_margin` секретные ключи не теряются, даже если UTXO временно исчезает из основной цепи.
5. **RPC `anchor_hint` и индексатор.**  
   `RpcStealthOutputInfo` получает поле `anchor_hint: Option<String>` с версионной сериализацией (`version 3`, см. §5.1), а `indexes/processor` — `StealthAnchorHintCache` для быстрого ответа `(txid, index) → anchor_hint` (см. §6.1). Лёгкие клиенты могут отбрасывать UTXO с чужими якорями без ECDH.
6. **Generator остаётся универсальным.**  
   При формировании `GeneratorSettings` стелс‑аккаунт фильтрует `utxo_iterator` и `priority_utxo_entries` по overlay, чтобы orphaned‑UTXO не попадали в автоматические платежи/компаунд (см. §3.6). Для ручных сценариев (consolidate/spend‑orphaned) аккаунт формирует специальный список входов и явно включает orphaned‑монеты.
7. **События и UX.**  
   Добавляем `MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch` (см. §4) и используем их для подсветки истекающих/ревокнутых делегаций и anchor‑mismatch. В UI orphaned‑баланс показывается отдельно, с причиной, и по умолчанию не тратится.

## 1. Область изменений и файлы

| Подсистема | Файлы | Изменения |
|-----------|-------|-----------|
| Stealth UTXO handler | `wallet/core/src/utxo/stealth_handler.rs`, `wallet/core/src/utxo/processor.rs`, `wallet/core/src/account/variants/stealth.rs` | Расширение `StealthUtxoHandler` данными о делегации и хендлерами DAA‑изменений; реализация в `StealthAccount`, привязка к `DelegationRecord` и master‑anchor. |
| Хранилище эфемерных ключей | `wallet/core/src/storage/ephemeral_keys.rs` | Расширение `EphemeralKeyEntry` полями DAA (`created_daa_score`, `valid_until_daa`) поверх уже существующих `master_anchor`/`delegation_id`, добавление статусов (`Orphaned`, `Expired`), методов очистки по DAA и инвариантов по reorg’ам. |
| Модель аккаунта / делегаций | `wallet/core/src/account/variants/stealth.rs`, `wallet/core/src/account/delegation.rs` (из Iteration 4) | Использование делегаций для маркировки UTXO, вычисление `valid_until_daa` на основе окна делегации, пометка orphaned при mismatch. |
| Wallet events / notify | `wallet/core/src/events.rs`, `wallet/core/src/wasm/events.rs` (если есть), JS/TS биндинги | Новые события `MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch` + обновление `EventKind`, сериализация/JS‑интерфейсы. |
| RPC модель | `rpc/core/src/model/message.rs`, `rpc/core/src/wasm/message.rs`, `rpc/grpc/core/proto/rpc.proto`, `rpc/grpc/core/src/convert/message.rs` | Добавление `anchor_hint` в `RpcStealthOutputInfo`, bump версии сериализации, прокидка поля через gRPC/wRPC/WASM. |
| RPC сервис / конвертер | `rpc/service/src/converter/consensus.rs`, `rpc/service/src/service.rs` | Расширение `extract_stealth_outputs_from_block` и `get_block_view_tags_call` для заполнения `anchor_hint` из индексатора (если доступен). |
| Индексатор | `indexes/processor/src/processor.rs`, при необходимости — новый модуль `indexes/processor/src/stealth_anchor_cache.rs`, расширения в `kaspa_utxoindex` | Лёгкий кэш `outpoint → anchor_hint`/`(anchor, view_tag)` на основе делегаций и UTXO diff; API для RPC‑слоя. |
| Тесты | `wallet/core/src/storage/ephemeral_keys.rs` (unit), `wallet/core/src/account/variants/stealth.rs` (unit), `testing/integration/src/stealth_flow.rs` (integration), новые тесты в `testing/integration/mldsa_master.rs` | Тесты reorg‑устойчивости ключей, истечения делегаций, сигналов событий, RPC `anchor_hint`. |
| Документация | `docs/plans/phase2/Phase2_MLDSA_master_key.md`, `docs/todo/stealth_view_tags.md`, `docs/IMPLEMENTATION_STATUS.md`, `docs/api/MLDSA_MASTER.md` | Уточнение статуса Iteration 5, описание формата `anchor_hint`, обновление тестовой матрицы. |

## 2. Дизайн: делегация ↔ стелс‑UTXO ↔ эфемерный ключ

### 2.1. Связка UTXO с делегацией

В Iteration 4 у нас уже есть:

- `DelegationRecord { anchor, account_id, scan_pubkey, spend_pubkey, valid_from_daa, valid_until_daa, nonce, signature }`.
- В `StealthAccount::Payload` (новая версия из Iteration 4) поля `master_anchor: Option<[u8;32]>` и `delegation_id: Option<u64>` с привязкой к активной делегации.

В Iteration 5 вводим инварианты:

- Каждый стелс‑UTXO, который кошелёк считает **нормально делегированным**, должен удовлетворять:
  - `account.master_anchor == delegation.anchor`;
  - `(utxo.block_daa_score >= delegation.valid_from_daa)` и  
    либо `delegation.valid_until_daa.is_none()`,  
    либо `utxo.block_daa_score <= delegation.valid_until_daa.unwrap()`.
- Если хотя бы одно условие нарушено, но UTXO всё равно математически принадлежит аккаунту (view‑tag + ECDH прошли), UTXO считается **orphaned**:
  - эфемерный ключ сохраняем;
  - orphan‑статус фиксируем только в overlay‑карте стелс‑аккаунта (`OrphanOverlayMap`, см. §3.4), **без** изменения `TransactionRecord`/`UtxoEntryReference` и базового `UtxoContext`;
  - в UI/CLI этот баланс может отображаться отдельно и не должен использоваться для автоматических трат.

### 2.2. Расширение `EphemeralKeyEntry` (с учётом текущего Borsh‑формата)

К началу Iteration 5 `EphemeralKeyEntry` в коде (`wallet/core/src/storage/ephemeral_keys.rs`) уже выглядит так:

```rust
#[derive(Clone, BorshSerialize, Serialize, Deserialize)]
pub struct EphemeralKeyEntry {
    pub outpoint: TransactionOutpoint,
    pub data: EphemeralKeyData,
    pub status: EphemeralKeyStatus,
    /// Optional master anchor associated with this UTXO (Iteration 4)
    pub master_anchor: Option<[u8; 32]>,
    /// Optional delegation id associated with this UTXO (Iteration 4)
    pub delegation_id: Option<u64>,
}
```

Контейнер хранения остаётся тем же: `EphemeralKeyStore::save_to_storage` сериализует `Encrypted<Vec<EphemeralKeyEntry>>` **без собственного `StorageHeader`/версии**, а десериализация реализована ручным `impl BorshDeserialize for EphemeralKeyEntry`, который:

- читает первые три поля `outpoint/data/status` так же, как в Phase 1;
- затем пробует дочитать `master_anchor` и `delegation_id` как `Option<…>`;
- при `UnexpectedEof`/несовпадении длины трактует их как `None` (миграция со старого формата).

Это накладывает ограничения, которые важны для Iteration 5:

- нельзя вводить отдельный `EphemeralKeyEntryV1` с заголовком — все изменения делаем только через добавление полей в существующий struct;
- порядок уже существующих полей менять нельзя; новые поля добавляем **в конец** и поддерживаем их в ручной десериализации как «хвост» с дефолтами.

В Iteration 5 нам нужны дополнительные DAA‑метаданные. Обновлённая структура:

```rust
#[derive(Clone, BorshSerialize, Serialize, Deserialize)]
pub struct EphemeralKeyEntry {
    pub outpoint: TransactionOutpoint,
    pub data: EphemeralKeyData,
    pub status: EphemeralKeyStatus,

    /// Anchor мастера, под который делегирован UTXO (если известен, Iteration 4)
    pub master_anchor: Option<[u8; 32]>,

    /// ID делегации, по которой был получен UTXO (если была, Iteration 4)
    pub delegation_id: Option<u64>,

    /// DAA‑высота, на которой UTXO впервые был зафиксирован кошельком
    /// (обычно `utxo.block_daa_score`)
    pub created_daa_score: u64,

    /// DAA, после которого делегация гарантированно истекла для этого UTXO
    /// (как минимум `delegation.valid_until_daa`, возможно с буфером)
    pub valid_until_daa: Option<u64>,
}
```

Миграция:

- ручной `BorshDeserialize` расширяем так же, как это уже сделано для `master_anchor`/`delegation_id`:
  - после чтения `delegation_id` пробуем прочесть `created_daa_score` и `valid_until_daa`;
  - при `UnexpectedEof`/`InvalidData` с «Unexpected length…» заполняем `created_daa_score = 0`, `valid_until_daa = None`;
- старые файлы, где сериализованы только первые 3 или 5 полей, по‑прежнему читаются корректно — новые поля принимают дефолтные значения.

`EphemeralKeyStatus` расширяем:

```rust
pub enum EphemeralKeyStatus {
    Pending { added_daa_score: u64 },
    Confirmed { confirmed_daa_score: u64 },
    /// Делегация больше не покрывает UTXO (истекла или ревокирована),
    /// но ключ сохранён для возможного ручного управления/аудита.
    Orphaned { reason: OrphanReason },
    /// Ключ удалён из активного набора (после истечения окна reorg/valid_until)
    Expired,
}

pub enum OrphanReason {
    DelegationExpired,
    DelegationRevoked,
    AnchorMismatch,
    NoDelegation,
}
```

 Инварианты:

- Записи с `status == Expired` **не должны попадать в активный in‑memory кэш** (`EphemeralKeyStore::keys/statuses`); если мы хотим удержать их только в логах/аудите, загружать можно отдельно (через вспомогательный путь), но runtime‑операции с ними не выполняются.
- Для ключей, созданных до Iteration 5 (`created_daa_score = 0`, `valid_until_daa = None`, `master_anchor/delegation_id = None`), логика очистки/TTL должна быть устойчива к этим дефолтам (например, считать `valid_until_daa = None` как «храним до ручного решения или глобального лимита возраста»).

### 2.3. Логика заполнения метаданных при скане

При первом успешном `try_claim_utxo_internal` (см. `StealthAccount::try_claim_utxo_internal`):

1. Берём `current_daa_score` из `UtxoProcessor::current_daa_score()` и `utxo_block_daa` из `RpcUtxoEntry`.
2. Получаем активную делегацию для аккаунта: `DelegationRecord` по `self.delegation_id` (из Iteration 4):
   - если делегаций нет — `delegation = None`;
   - если есть, но `anchor` не совпадает с `master_anchor` аккаунта — считаем `AnchorMismatch`.
3. Вычисляем:
   - `created_daa_score = utxo_block_daa` (или `current_daa_score`, если информации нет);
   - `valid_until_daa = delegation.valid_until_daa` (опционально + safety‑буфер, например `+ user_transaction_maturity_period_daa`).
4. Определяем статус:
   - если делегация есть и `utxo_block_daa` попадает в её окно — `Pending`/`Confirmed` в зависимости от зрелости;
   - иначе `status = Orphaned { reason: ... }`, но ключ всё равно сохраняем.

Хранить `valid_until_daa` важно для:

- безопасной очистки ключей по мере движения `current_daa_score`;
- возможности отличать «старые/истёкшие» делегированные UTXO от текущих при повторном скане и reorg‑ах.

### 2.4. Множественные делегации, приоритет окон и пересчёт статусов

У одного стелс‑аккаунта и одного `master_anchor` может быть несколько `DelegationRecord` (ротации, продления окна, revoke‑записи). Чтобы поведение было детерминированным и хорошо восстанавливалось после CRDT‑слияний (Iter 6/7), Iteration 5 фиксирует простые правила:

- **Выбор делегации для UTXO при скане:**
  - считаем, что для каждой пары `(account_id, anchor)` в памяти есть упорядоченный по `nonce` список делегаций;
  - для UTXO с `utxo_block_daa`:
    1. находим все делегации с этим `account_id` и `anchor`, для которых `valid_from_daa <= utxo_block_daa <= valid_until_daa` (или `valid_until_daa.is_none()` → «открытый конец»);
    2. если их несколько — выбираем делегацию с **максимальным `nonce`** (последняя по времени/версии);
    3. если ни одна делегация не покрывает UTXO, но есть делегации с тем же anchor:
       - если `utxo_block_daa > max(valid_until_daa)` → `OrphanReason::DelegationExpired`;
       - если anchor аккаунта не совпадает с anchor делегаций → `OrphanReason::AnchorMismatch`;
    4. если делегаций вообще нет → `OrphanReason::NoDelegation`.
  - выбранный `delegation_id` (если есть) записываем в `EphemeralKeyEntry.delegation_id`.
- **Ревокация и ротация:**
  - revoke/rotate реализуются Iteration 4 через новые `DelegationRecord` с тем же `(account_id, anchor)` и бóльшим `nonce`;
  - в Iteration 5 при применении новой делегации:
    - выполняем ленивый пересчёт статусов для уже известных `EphemeralKeyEntry` этого аккаунта:
      - если новая делегация расширяет окно (продление) — UTXO, которые раньше были `Orphaned { DelegationExpired }`, могут оставаться orphaned (мы не изменяем историю задним числом), если явно не предусмотрен сценарий «переосвятить» старые выходы;
      - если новая делегация — revoke (окно сузилось) — UTXO, лежащие за пределами нового окна, помечаются как `Orphaned { DelegationRevoked }`.
  - важно, что `delegation_id` в `EphemeralKeyEntry` остаётся ссылкой на **делегацию, действовавшую в момент приёма UTXO**, даже если позже появилась более новая делегация с большим `nonce`.
- **Пересчёт orphan‑статусов при синхронизации делегаций:**
  - при мердже делегаций с другого устройства (Iter 6/7) или при загрузке кошелька после долгого оффлайна стелс‑аккаунт может выполнять:
    - фоновый проход по `EphemeralKeyStore` и `DelegationRecord` с пересчётом `OrphanReason` (на основе вышеописанных правил окон/nonce);
    - обновление overlay‑карты `OrphanOverlayMap` после такого пересчёта.
  - Iteration 5 не реализует сам протокол синхронизации делегаций, но в плане явно фиксируется, что логика orphan‑статусов должна быть **идемпотентной**: повторный прогон «применить все делегации к всем UTXO» даёт тот же результат, независимо от порядка, в котором делегации приехали.

### 2.5. End‑to‑end поток данных (от блока до UX)

Чтобы было понятно, как все компоненты Iteration 5 стыкуются между собой, фиксируем целостный сценарий:

1. **Блок попадает в ноду / индексатор:**
   - Consensus генерирует `UtxosChangedNotification` с добавленными/удалёнными UTXO.
   - `indexes/processor::Processor` обновляет `UtxoIndex`, а для стелс‑выходов дополнительно обновляет `StealthAnchorHintCache` (см. §6.1).
2. **RPC формирует `get_block_view_tags` / `StealthUtxosChanged`:**
   - `rpc/service::converter::extract_stealth_outputs_from_block` извлекает стелс‑выходы, смотрит в `StealthAnchorHintCache` и собирает `RpcStealthOutputInfo { view_tag, ephemeral_pubkey, destination_pubkey, amount, anchor_hint, ... }`.
   - `rpc/service::service::get_block_view_tags_call` возвращает массив таких записей клиенту (кошельку/мобильному SDK).
3. **UtxoProcessor принимает уведомления:**
   - либо через `UtxosChanged`/`UtxoIndex` (полный индексатор),
   - либо через fallback‑скан по `get_utxos_by_script_version`/`get_block_view_tags` (режим без utxoindex).
   - Для каждого UTXO, который попал в адресное пространство аккаунтов, `UtxoContext` обновляет свои `mature/pending/stasis` и эмитит события `Pending`/`Maturity`/`Reorg`/`Stasis` (см. существующую логику).
4. **StealthUtxoHandler / StealthAccount сканируют стелс‑выходы:**
   - `StealthUtxoHandler::try_claim_utxo` получает `RpcUtxosByAddressesEntry` (с view‑tag, скриптом, и т.д.), выполняет fast‑path по view‑tag, затем ECDH‑чек.
   - При успехе вызывает `StealthAccount::try_claim_utxo_internal`, который:
     - определяет подходящую `DelegationRecord` (см. §2.4);
     - вычисляет `created_daa_score`, `valid_until_daa`;
     - создаёт/обновляет `EphemeralKeyEntry` в `EphemeralKeyStore` с нужным `EphemeralKeyStatus` (обычно `Pending`/`Confirmed` или `Orphaned{…}`).
5. **EphemeralKeyStore и overlay:**
   - `EphemeralKeyStore` хранит секретный материал + метаданные делегации, статусы и DAA‑окна.
   - На основе `EphemeralKeyStore` и `UtxoContext` стелс‑аккаунт строит/поддерживает `OrphanOverlayMap` (см. §3.4, §3.5).
6. **DAA‑события и очистка:**
   - При каждом `Events::DaaScoreChange { current_daa_score }`:
     - `UtxoProcessor::handle_daa_score_change` обновляет свои pending/stasis и вызывает `StealthUtxoHandler::on_daa_score_changed` для всех стелс‑аккаунтов.
     - `StealthAccount::on_daa_score_changed`:
       - запускает `EphemeralKeyStore::cleanup_expired(current_daa_score)`;
       - проверяет истечение делегаций, обновляет `EphemeralKeyStatus`/overlay и, при необходимости, эмитит `MasterDelegationExpired` (см. §4).
7. **Генератор трат:**
   - Когда пользователь инициирует платёж/компаунд:
     - стелс‑аккаунт формирует `GeneratorSettings` с отфильтрованным по overlay `utxo_iterator` / `priority_utxo_entries` (см. §3.6);
     - `Generator` строит дерево транзакций, не зная ни про master, ни про orphaned‑статусы.
8. **События / история / UX:**
   - События `Pending`/`Maturity`/`Reorg`/`Stasis` продолжают доставлять `TransactionRecord` в Wallet/GUI.
   - Стелс‑слой и UI поверх них:
     - отмечают в истории транзакции, затронувшие orphaned‑UTXO;
     - показывают список orphaned‑баланса и позволяют запускать ручные сценарии (consolidate, spend‑orphaned) поверх того же генератора.

Таким образом, Iteration 5 встраивается в существующий стек не как «монолитный новый модуль», а как минимальные доработки на каждом слое:

- консенсус/индексатор → `anchor_hint`/StealthAnchorHintCache;
- RPC → расширенный `RpcStealthOutputInfo` и `get_block_view_tags`;
- wallet core → делегации, `EphemeralKeyStore`, overlay, новые события;
- generator/UX → аккуратная фильтрация и отдельные ручные сценарии для orphaned‑монет.

## 3. StealthUtxoHandler и reorg‑устойчивость

### 3.1. Расширение интерфейса `StealthUtxoHandler`

Текущий интерфейс (`wallet/core/src/utxo/stealth_handler.rs`) уже содержит:

- `async fn try_claim_utxo(&self, utxo: &RpcUtxosByAddressesEntry) -> Option<UtxoContext>;`
- `async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()>;`
- `fn ephemeral_key_store(&self) -> Option<Arc<EphemeralKeyStore>>;`

В Iteration 5 добавляем:

- новый хук на изменение DAA:

```rust
#[async_trait]
pub trait StealthUtxoHandler: Send + Sync {
    // ...

    /// Вызывается UtxoProcessor при изменении DAA‑высоты.
    /// Используется для очистки/обновления эфемерных ключей и делегаций.
    async fn on_daa_score_changed(&self, _current_daa_score: u64) -> Result<()> {
        Ok(())
    }
}
```

и в `UtxoProcessor::handle_daa_score_change`:

- после стандартной обработки pending/outgoing:
  - пробегаемся по всем `stealth_handlers()` и вызываем `on_daa_score_changed(current_daa_score).await`.

### 3.2. Поведение `StealthAccount::handle_utxo_removed`

Сейчас (`wallet/core/src/account/variants/stealth.rs`) реализация:

- при удалении UTXO:
  - `ephemeral_keys.remove(outpoint)` (без различения spend/reorg);
  - удаление из `UtxoProcessor`/`UtxoContext`.

В Iteration 5:

- Заменяем прямой `remove` на более «мягкую» политику:

```rust
async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()> {
    let current_daa = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);
    self.ephemeral_keys.mark_removed(outpoint, current_daa).await
}
```

Где в `EphemeralKeyStore` (концептуально):

- `mark_removed`:
  - обновляет `status` записи для `outpoint`:
    - если у записи есть `valid_until_daa` и `current_daa < valid_until_daa` — помечаем как «кандидат на reorg» (например, `Orphaned { DelegationExpired }` или отдельный промежуточный статус), но **не** стираем `EphemeralKeyData`;
    - если окна делегации нет (`valid_until_daa == None`) — консервативно сохраняем ключ до явного `cleanup_expired` или глобального лимита возраста;
  - устанавливает флаг `modified`, чтобы при следующем `save_to_storage` изменение попало на диск.

### 3.3. Очистка по DAA: `EphemeralKeyStore::cleanup_expired`

Добавляем в `EphemeralKeyStore`:

```rust
impl EphemeralKeyStore {
    pub fn cleanup_expired(&self, current_daa_score: u64) {
        // проход по DashMap:
        // - если valid_until_daa.is_some() && current_daa_score > valid_until_daa + margin
        //   и статус == Orphaned/Expired → удалить запись (zeroize data)
        // - опционально: удалять «очень старые» записи без valid_until_daa
        //   по глобальному лимиту возраста (created_daa_score + max_age)
    }
}
```

И в `StealthAccount::on_daa_score_changed`:

```rust
async fn on_daa_score_changed(&self, current_daa_score: u64) -> Result<()> {
    self.ephemeral_keys.cleanup_expired(current_daa_score);
    // Дополнительно проверяем истечение делегаций и шлём события (см. §4)
    self.check_delegations_expiry(current_daa_score).await
}
```

Инварианты:

- Реорг внутри окна `valid_until_daa` **не** приводит к потере `EphemeralKeyData`: ключи остаются в store и могут быть переиспользованы для переиндексации (в т.ч. через fallback‑скан `scan_via_view_tags`).
- После того как DAA перешагнул `valid_until_daa + safety_margin`, ключи безопасно выбрасываются (через `cleanup_expired`), причём:
  - удаление сопровождается `Zeroize` для секретного материала;
  - логика должна быть устойчивой к случаям, когда `current_daa_score` не обновляется (например, кошелёк долго был оффлайн) — при следующем bump’е DAA производится «массовая» очистка старых записей.

Важно: хук `on_daa_score_changed` и DAA‑чистка завязаны на `UtxoProcessor::handle_daa_score_change`, который в текущей архитектуре работает **только при наличии utxoindex** (см. `init_state_from_server` и `Error::MissingUtxoIndex`).  
Для конфигураций без utxoindex (fallback‑режим, который уже покрыт тестами в `testing/integration/src/stealth_flow.rs`) поведение Iteration 5 должно быть:

- базовый функционал стелс‑аккаунтов и сканирования остаётся неизменным (fallback‑скан по view tags/block replay);
- очистка `EphemeralKeyStore` по DAA считается «лучшим усилием» (best effort) и может выполняться:
  - либо только при наличии utxoindex/DAA‑событий,
  - либо через отдельные ленивые проходы (например, при unlock/lock аккаунта или явном maintenance‑API);
- план явно фиксирует, что **отсутствие utxoindex не должно ломать ни один из существующих тестов** (`test_stealth_fallback_scan_without_utxoindex`, `test_stealth_fallback_progress_events` и др.), а новая логика должна быть обёрнута в проверки `has_utxoindex`/`is_connected` там, где это релевантно.

### 3.4. Orphaned‑UTXO как оверлей над `UtxoContext` / `TransactionRecord`

Важно: Iteration 5 **не ломает** существующую модель UTXO и транзакций в `wallet/core` — и `UtxoContext`, и `TransactionRecord` остаются общими для всех аккаунтов и не знают про master/делегации. Учёт orphaned‑UTXO делается как **отдельный оверлей**, привязанный только к стелс‑аккаунтам:

- **Базовый слой (как сейчас):**
  - `UtxoContext` по‑прежнему ведёт три пула: `mature`, `pending`, `stasis` (`wallet/core/src/utxo/context.rs`), и генерирует события `Pending` / `Reorg` / `Stasis` / `Maturity` с `TransactionRecord`.
  - `TransactionRecord` описывает только «чистую» UTXO‑семантику (Reorg/Incoming/Stasis/External/Outgoing/Batch/Transfer/Change), не зная про master‑anchor и статусы делегаций.
- **Оверлей делегаций для стелс‑аккаунта:**
  - Внутри `StealthAccount` держим отдельную карту `orphaned_utxos: HashSet<TransactionOutpoint>` (или более богатую структуру `HashMap<Outpoint, OrphanReason>`), которая заполняется:
    - при `try_claim_utxo_internal`, если математика (view‑tag+ECDH) прошла, но делегация не покрывает UTXO (anchor mismatch, истёкшее окно, отсутствие записи и т.п.);
    - при `on_daa_score_changed` / ревоке делегации, когда ранее «нормальные» UTXO выходят из окна действия.
  - Для всех операций расхода/отображения баланса стелс‑аккаунт накладывает оверлей:
    - входы, чьи outpoint есть в `orphaned_utxos`, **не предлагаются** генератору как кандидаты для автоматических трат;
    - UI/CLI может подсвечивать их отдельно (через фильтрацию по `orphaned_utxos`) как «требующие ручного решения».
- **Связка с `TransactionRecord` / событиями:**
  - Сами `TransactionRecord` не меняем; orphan‑статус восстанавливаем по `(binding, utxo.outpoint)`:
    - при обработке `Events::Pending` / `Events::Maturity` в слое Wallet/GUI можно смотреть, содержат ли `record.data.utxoEntries` outpoint’ы, помеченные как orphaned для данного `AccountId` → и маркировать такие записи в истории (иконка/флаг).
  - При генерации событий `MasterDelegationExpired` / `MasterDelegationRevoked` / `MasterAnchorMismatch` (см. §4) оверлей обновляется, но структура `TransactionRecord` и формат событий `Pending`/`Maturity`/`Reorg` остаются прежними.

Такой подход позволяет:

- не трогать общий UTXO‑пайплайн и не добавлять master‑специфичные поля в `UtxoContext` и `TransactionRecord`;
- эволюционировать отображение orphaned‑UTXO (новые причины, фильтры, UX) в рамках стелс‑аккаунта и верхнего слоя Wallet/GUI, без изменения RPC/consensus;
- хранить строгую границу: «UTXO‑жизненный цикл» (Context/Record) vs. «легитимность с точки зрения master‑делегаций» (overlay в StealthAccount).

### 3.5. Структура overlay‑карты orphaned‑UTXO, хранение и миграции

Чтобы не дублировать данные и не усложнять миграции, Iteration 5 фиксирует следующие принципы:

- **Источник истины по orphan‑статусу — `EphemeralKeyStore`:**
  - флаг `status = EphemeralKeyStatus::Orphaned { reason: OrphanReason }` и поля `delegation_id/master_anchor/valid_until_daa` в `EphemeralKeyEntry` являются единственным персистентным состоянием;
  - overlay‑карта в `StealthAccount` — чисто *in‑memory*‑структура, которая восстанавливается на основе загруженного `EphemeralKeyStore` и текущего `UtxoContext`.
- **Формат overlay в рантайме (внутри `StealthAccount`):**
  - используем уже определённый `OrphanReason` (см. §2.2), чтобы не плодить дублирующие enum’ы;
  - поверх него определяем:
    ```rust
    pub struct OrphanOverlayEntry {
        pub reason: OrphanReason,
        pub first_marked_daa: u64,
    }
    
    type OrphanOverlayMap = AHashMap<TransactionOutpoint, OrphanOverlayEntry>;
    ```
  - при первом переводе UTXO в orphan‑состояние (`try_claim_utxo_internal` или `on_daa_score_changed`) заполняем `first_marked_daa = current_daa_score` и записываем этот же `reason` в `EphemeralKeyEntry.status`;
  - последующие обновления (смена причины, истечение делегации) меняют `status` в `EphemeralKeyStore` и перезаписывают `reason`/`first_marked_daa` в overlay.
- **Как overlay строится при старте/разблокировке:**
  - последовательность:
    1. `EphemeralKeyStore::load_from_storage(...)` загружает `Vec<EphemeralKeyEntry>` (включая старый формат, см. §2.2);
    2. `StealthAccount` проходит по всем записям:
       - если `status == Orphaned { reason }` и outpoint присутствует в `UtxoContext` → добавляем в `OrphanOverlayMap` с `first_marked_daa = created_daa_score` (или `0`, если старый формат);
       - если `status == Expired` → запись не попадает ни в overlay, ни в UTXO‑кандидаты;
       - `Pending/Confirmed` → overlay не трогаем.
  - таким образом, после любого рестарта/restore overlay детерминированно восстанавливается из персистентного хранилища, а `UtxoContext` остаётся неизменным.
- **Сериализация и версии payload’а аккаунта:**
  - `Payload` стелс‑аккаунта (см. начало файла `stealth.rs`) **не расширяем** под orphan‑UTXO:
    - все данные, нужные для статуса (anchor, delegation_id, created_daa_score, valid_until_daa, OrphanReason), уже живут в `EphemeralKeyEntry`;
    - overlay‑карта в рантайме редуцируема из `EphemeralKeyStore` + `UtxoContext`, поэтому отдельное поле в payload’е не даёт новой информации, но усложняет миграции.
  - Миграции ограничиваются только:
    - добавлением полей с `#[borsh(default)]` в `EphemeralKeyEntry` (см. §2.2);
    - расширением `EphemeralKeyStatus` значениями `Orphaned/Expired`.
  - Версия `Payload::STORAGE_VERSION` для стелс‑аккаунта в Iteration 5 **может не меняться**, если новые данные не кладём в сам payload; при необходимости будущих UX‑фич (persisted пометки orphan‑UTXO даже без stealth‑ключей) можно отдельно спланировать `STORAGE_VERSION = 1` и миграцию, но это уже выход за рамки Iteration 5.
- **Инварианты и проверки:**
  - любое изменение orphan‑статуса (через делегации, DAA, reorg) сначала обновляет `EphemeralKeyStore`, а уже затем — overlay‑карту;
  - overlay считается *кешем представления* и может быть безопасно пересобран из `EphemeralKeyStore`/`UtxoContext` в любой момент (в т.ч. по maintenance‑API `rebuild_orphan_overlay()`).

Итог: orphaned‑UTXO в Iteration 5 получает чёткий формат (`OrphanOverlayMap` + `OrphanReason` в `EphemeralKeyEntry`), но при этом мы избегаем лишних полей/версий в payload’ах аккаунтов и держим все миграции локализованными внутри `ephemeral_keys`‑хранилища.

### 3.6. Интеграция OrphanOverlayMap с генератором трат и UX

Задача Iteration 5 — не только пометить orphaned‑UTXO, но и гарантировать, что:

- они **не попадают** в автоматические платежи/компактификацию, пока пользователь явно не решит, что с ними делать;
- при этом мы не ломаем существующий `Generator` и API `GeneratorSettings`.

Подход:

- **Фильтрация кандидатов UTXO до попадания в `Generator`:**
  - сегодня `GeneratorSettings::try_new_with_account` строит `UtxoIterator` поверх `account.utxo_context()` и передаёт его в `Generator` как `utxo_iterator: Box<dyn Iterator<Item = UtxoEntryReference>>`.
  - В Iteration 5 логика стелс‑аккаунта при создании настроек для генератора должна:
    - оборачивать этот итератор фильтром по overlay:
      ```rust
      let overlay = self.orphan_overlay(); // ссылка на OrphanOverlayMap
      let base_iter = UtxoIterator::new(self.utxo_context());
      let filtered_iter = base_iter.filter(move |entry: &UtxoEntryReference| {
          let outpoint = entry.outpoint();
          !overlay.contains_key(&outpoint)
      });
      ```
    - и отдавать уже `Box::new(filtered_iter)` в `GeneratorSettings`:
      - **без** изменения `Generator`/`GeneratorSettings` (они по‑прежнему знают только про «множество UTXO»).
  - Аналогично, если используются `priority_utxo_entries`, стелс‑аккаунт перед тем, как передать их в `GeneratorSettings::try_new_with_context`, отфильтровывает их по `OrphanOverlayMap`.
- **Приоритизация внутри генератора:**
  - сам `Generator` не знает про orphaned‑статус и не должен его знать; приоритеты остаются такие же, как сейчас:
    - сначала `priority_utxo_entries` (после фильтрации overlay’ем на уровне аккаунта);
    - затем поток `utxo_iterator`.
  - Если в будущем появится кейс «приоритетно тратить orphaned‑UTXO» (например, пользователь хочет «очистить» спорные монеты), это делается не изменением генератора, а формированием отдельного списка входов (см. следующий пункт про ручной UX).
- **Ручной UX для использования orphaned‑монет:**
  - Верхний слой (Wallet/GUI/CLI) получает из стелс‑аккаунта:
    - список orphaned‑UTXO: `Vec<(TransactionOutpoint, OrphanOverlayEntry, amount)>`, восстановленный из `EphemeralKeyStore` + `UtxoContext`;
    - метаданные делегации/якоря (`delegation_id`, `master_anchor`, `valid_until_daa`) — по необходимости.
  - Возможные сценарии:
    - **Ручная консолидация orphaned‑монет:**
      - UI позволяет выбрать один или несколько orphaned‑UTXO и явно создать транзакцию «consolidate_orphaned» на новый адрес/аккаунт;
      - под капотом стелс‑аккаунт формирует `GeneratorSettings` с:
        - `priority_utxo_entries =` выбранные UTXO (включая orphaned, т.к. пользователь подтвердил намерение);
        - `utxo_iterator` может быть пустым или обычным (но UI может вывести предупреждение, что будут использоваться *только* перечисленные UTXO);
      - в этом режиме overlay всё ещё учитывается, но при построении `priority_utxo_entries` явно допускает orphaned‑входы.
    - **Явное включение orphaned‑UTXO в обычный платёж:**
      - в интерфейсе платежа (send form) возможен флаг «включить orphaned UTXO»/«использовать и спорные входы»;
      - при включении флага стелс‑аккаунт:
        - делает объединённый список `priority_utxo_entries =` (выбранные обычные UTXO + выбранные orphaned);
        - остальной пул кандидатов по‑прежнему фильтруется по overlay, чтобы ненамеренно не подтягивать другие orphaned‑монеты.
- **Инварианты безопасности:**
  - по умолчанию (`happy path`) **ни один** orphaned‑UTXO не попадает в платёж/компаундинг без явного действия пользователя:
    - базовый `utxo_iterator` и `priority_utxo_entries`, используемые обычным `send`/`sweep`, всегда проходят через `OrphanOverlayMap::filter_out_orphans`;
  - ручные сценарии (консолидация, «специальный» платёж) всегда идут через отдельные методы/флаги, которые:
    - прозрачно помечены в UX (отдельное предупреждение/confirm);
    - логируются с `master_anchor=<hex8>` (см. Iteration 10) и, при необходимости, с указанием `OrphanReason`.
- **Связь с событиями и историей:**
  - когда orphaned‑UTXO всё‑таки был потрачен (через ручной сценарий):
    - при получении `Events::Maturity`/`Events::Outgoing` по соответствующей транзакции overlay‑запись удаляется (`orphan_overlay.remove(outpoint)`), а в `EphemeralKeyStore` статус может быть переведён в `Expired` (если ключ больше не нужен);
    - история транзакций (UI/CLI) может пометить такую операцию как «spend orphaned funds» по признаку, что хотя бы один вход транзакции ранее числился в overlay.

Таким образом, генератор трат в Iteration 5 остаётся максимально «общим» компонентом, а вся специфичная логика по master‑делегациям и orphaned‑UTXO живёт:

- в фильтрации источников UTXO (`utxo_iterator` / `priority_utxo_entries`) на уровне стелс‑аккаунта;
- в overlay‑карте `OrphanOverlayMap` и сценариях UX/CLI, которые явно позволяют или запрещают использование таких UTXO.

## 4. Wallet events: делегации и mismatch

### 4.1. Новые события в `wallet/core/src/events.rs`

Расширяем enum `Events`:

```rust
pub enum Events {
    // ...
    #[serde(rename_all = "camelCase")]
    MasterDelegationExpired {
        account_id: AccountId,
        delegation_id: u64,
        anchor: [u8; 32],
        valid_until_daa: u64,
    },
    #[serde(rename_all = "camelCase")]
    MasterDelegationRevoked {
        account_id: AccountId,
        delegation_id: u64,
        anchor: [u8; 32],
    },
    #[serde(rename_all = "camelCase")]
    MasterAnchorMismatch {
        account_id: AccountId,
        expected_anchor: [u8; 32],
        actual_anchor: [u8; 32],
    },
    // ...
}
```

и `EventKind`:

- добавляем варианты `MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch` с корректным `From<&Events>`/`Display`/`FromStr`.

### 4.2. Где эмитим события

- **`MasterDelegationExpired`:**
  - в `StealthAccount::on_daa_score_changed`, когда `current_daa_score >= delegation.valid_until_daa`:
    - помечаем все связанные `EphemeralKeyEntry` как `Orphaned { DelegationExpired }`;
    - шлём событие с `account_id`, `delegation_id`, `anchor`, `valid_until_daa`.
- **`MasterDelegationRevoked`:**
  - при применении обновлённого `DelegationRecord` (из Iteration 4) со статусом revoke/rotate:
    - аналогично отмечаем связанные UTXO как orphaned;
    - шлём соответствующее событие.
- **`MasterAnchorMismatch`:**
  - при unlock мастер‑аккаунта (`Iteration 3`) уже есть проверка;
  - в контексте Iteration 5 дополнительно можем эмитить его при:
    - обнаружении UTXO, который матчит по view‑tag/ECDH, но текущая `master_anchor` аккаунта отличается от `DelegationRecord.anchor`.

UX ожидания:

- CLI/GUI могут подписываться на эти события и:
  - подсвечивать аккаунты, у которых истекают или уже истекли делегации;
  - явно показывать orphaned UTXO и предлагать сценарий ручного разрешения (создать новую делегацию, переместить средства и т.п.).

## 5. RPC `get_block_view_tags` и `anchor_hint`

### 5.1. Расширение `RpcStealthOutputInfo`

Текущий формат (`rpc/core/src/model/message.rs`):

```rust
pub struct RpcStealthOutputInfo {
    pub transaction_id: RpcTransactionId,
    pub output_index: u32,
    pub view_tag: u8,
    pub ephemeral_pubkey: String,
    pub destination_pubkey: String,
    pub amount: u64,
    pub is_coinbase: bool,
}
```

В Iteration 5 добавляем:

```rust
pub struct RpcStealthOutputInfo {
    // ...
    /// Best‑effort подсказка по якорю мастера (первые 4 байта anchor или их функция),
    /// если узел располагает такой информацией. Может быть None.
    pub anchor_hint: Option<String>, // 8 hex chars, соответствует [u8;4]
}
```

и меняем версию сериализации:

- `Serializer`:
  - увеличиваем `version` с `2` до `3`;
  - в версии `3` пишем дополнительное поле `anchor_hint` (как `Option<String>`).
- `Deserializer`:
  - при `version < 3` читаем старый формат и устанавливаем `anchor_hint = None`;
  - при `version >= 3` читаем новое поле.

Соответствующие обновления:

- `rpc/grpc/core/proto/rpc.proto`:
  - в `message RpcStealthOutputInfo` добавляем поле `optional bytes anchorHint = 7;` (или `string anchorHint = 7;` для читаемости).
- `rpc/grpc/core/src/convert/message.rs`:
  - маппинг поля туда‑обратно.
- `rpc/core/src/wasm/message.rs`:
  - поле `anchorHint?: string` в интерфейсах TypeScript, корректная конвертация.

### 5.2. Кто и как заполняет `anchor_hint`

Ключевое ограничение: консенсус сам по себе **не знает**, к какому `MasterAnchor` относится конкретный стелс‑output — эта информация живёт в делегациях кошелька. Поэтому:

- `anchor_hint` — **best effort**, не обязательное и не криптографически обязательное поле.
- В Iteration 5 мы готовим инфраструктуру:
  - поле в модели;
  - трассу через gRPC/wRPC/WASM;
  - место для интеграции с индексатором (см. §6).
- Реальное наполнение может зависеть от того, как в Iteration 4/9 будет реализован RPC/индекс для `register_mldsa_anchor`/делегаций.

Модель, к которой мы стремимся:

- индексатор (`indexes/processor` + `kaspa_utxoindex`) поддерживает таблицу/кэш:

```text
(transaction_id, output_index) ↦ anchor_hint (Option<[u8;4]>)
```

или более общий:

```text
(view_tag, destination_pubkey_prefix) ↦ { anchor_hint_1, anchor_hint_2, ... }
```

- `rpc/service/src/converter/consensus.rs::extract_stealth_outputs_from_block`:
  - парсит стелс‑output (как сейчас);
  - для каждого `(tx_id, idx)` запрашивает `anchor_hint` у индексатора;
  - заполняет поле в `RpcStealthOutputInfo`.
- Если индексатор не знает про якоря/делегации — `anchor_hint = None`.

На стороне клиентов:

- мобильные кошельки/легкие клиенты могут держать множество якорей (multi‑master).
- При получении `RpcStealthOutputInfo`:
  - если `anchor_hint` есть и не совпадает ни с одним локальным якорем — UTXO можно быстро отбросить;
  - если `anchor_hint` совпадает хотя бы с одним — блок/строка попадает в «кандидаты» и обрабатывается обычным стелс‑сканером (view tag + ECDH).

### 5.3. Обновления тестов

- `rpc/core/src/model/tests.rs`:
  - обновляем mock/round‑trip тесты `RpcStealthOutputInfo` и `GetBlockViewTagsResponse` с учётом `anchor_hint`.
- `testing/integration/src/stealth_flow.rs`:
  - добавляем тест, который:
    - вызывает `get_block_view_tags` на блоке со стелс‑выходами;
    - проверяет, что `anchor_hint` сериализуется/десериализуется и хотя бы `None` стабильна;
    - после внедрения реального кэша — проверяет совпадение с ожидаемыми значениями.

## 6. Индексатор и лёгкий кэш якорей

### 6.1. Расширение `indexes/processor::Processor`

Сейчас `Processor` (`indexes/processor/src/processor.rs`) обслуживает только:

- приём `ConsensusNotification::UtxosChanged`/`PruningPointUtxoSetOverride`;
- обновление `UtxoIndex` и генерацию `kaspa_index_core::notification::UtxosChangedNotification`.

В Iteration 5 добавляем лёгкий кэш (in‑memory, плюс при необходимости persistence):

```rust
pub struct StealthAnchorHintCache {
    // Ключ: (transaction_id, output_index)
    // Значение: anchor_hint (u32 как первые 4 байта anchor) и дополнительная мета (optional)
    map: DashMap<(RpcTransactionId, u32), u32>,
}
```

и поле в `Processor`:

```rust
pub struct Processor {
    utxoindex: Option<UtxoIndexProxy>,
    // ...
    stealth_anchor_cache: Arc<StealthAnchorHintCache>,
}
```

Интеграция с UTXO diff:

- в `process_utxos_changed` после вызова `utxoindex.update(...)`:
  - для каждого **добавленного** UTXO с `script_public_key.version() == STEALTH_SCRIPT_VERSION`:
    - пытаемся сопоставить его с делегацией по данным `kaspa_utxoindex`/дополнительного индекса (это часть Iteration 4/9, здесь описываем как интерфейс);
    - если нашли anchor — вычисляем `anchor_hint = u32::from_le_bytes(anchor[0..4])` и кладём в кэш по `(txid, index)`.
  - для **удалённых** UTXO — удаляем/помечаем записи кэша (в зависимоти от того, хотим ли мы хранить информацию и после удаления).

API для RPC‑слоя:

- `StealthAnchorHintCache::get(txid: &RpcTransactionId, index: u32) -> Option<u32>`.
- Обёртка в `kaspa_utxoindex::api` или `indexes/processor` (через notifier/конвертер к `rpc/service`), которая позволяет `RpcCoreService` запросить hint по `(txid, idx)` при построении ответа `GetBlockViewTagsResponse`.

### 6.2. Открытые вопросы (фиксируем в плане)

- Источник знания о `anchor ↔ (scan_pubkey, spend_pubkey)`:
  - предполагается, что Iteration 4 создаёт RPC/индекс, который регистрирует делегации/анкера на ноде (либо через отдельный сервис, либо через kasplex‑relay).
- Как долго хранить anchor‑hint после удаления UTXO:
  - для devnet/testnet можем хранить до `valid_until_daa + margin`;
  - для mainnet потребуется баланс между памятью и пользой.
- Нагрузочные тесты:
  - стоит зафиксировать таргет по количеству уникальных anchor‑hint в памяти (десятки/сотни тысяч записей).

## 7. Тесты и критерии готовности

### 7.1. Unit‑тесты

- `wallet/core/src/storage/ephemeral_keys.rs`:
  - сериализация/десериализация обновлённого `EphemeralKeyEntry` (включая миграцию со старого формата без дополнительных полей);
  - логика `cleanup_expired` при разных комбинациях `valid_until_daa`/статусов.
- `wallet/core/src/account/variants/stealth.rs`:
  - `try_claim_utxo_internal` с:
    - валидной делегацией и окном;
    - истёкшей делегацией;
    - anchor mismatch;
    - отсутствующей делегацией;
  - проверка, что статус/метаданные `EphemeralKeyEntry` выставляются корректно.
- `wallet/core/src/events.rs`:
  - round‑trip новых событий (`MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch`) через Borsh/serde/JS.
- `rpc/core/src/model/message.rs`:
  - сериализация/десериализация `RpcStealthOutputInfo` с/без `anchor_hint`.

### 7.2. Integration‑тесты

Расширения к `testing/integration/src/stealth_flow.rs` и/или новый файл `testing/integration/src/mldsa_master.rs`:

1. **Reorg‑устойчивость эфемерных ключей:**
   - Поднять два узла, смоделировать короткий reorg с откатом стелс‑UTXO.
   - Проверить, что `EphemeralKeyData` не теряется до тех пор, пока `current_daa_score < valid_until_daa`.
   - После восстановления цепочки убедиться, что баланс и ключи совпадают.
2. **Истечение делегации:**
   - Создать делегацию с небольшим `valid_until_daa`, получить несколько стелс‑UTXO.
   - Промотать DAA > `valid_until_daa`, убедиться, что:
     - новые стелс‑UTXO под старую делегацию не принимаются как «нормальные» (orphaned);
     - срабатывает событие `MasterDelegationExpired`.
3. **Anchor mismatch:**
   - Смоделировать ситуацию, когда аккаунт привязан к одному anchor, а полученный UTXO фактически соответствует другому (через ручную подмену делегации на уровне теста).
   - Проверить событие `MasterAnchorMismatch` и статус `Orphaned { AnchorMismatch }`.
4. **RPC `anchor_hint`:**
   - На devnet‑узле с включённым индексатором:
     - отправить несколько стелс‑транзакций;
     - вызвать `get_block_view_tags` и убедиться, что `anchor_hint` корректно сериализуется/десериализуется (минимум — `None`, после внедрения кэша — реальные значения).

### 7.3. Обновление матрицы тестов

- `docs/plans/phase2/Phase2_MLDSA_master_key.md` и `docs/TEST_COVERAGE_SUMMARY.md`:
  - добавить строки в разделы Unit/Integration/Fuzz (см. §3 матрицы в основном плане), отражающие:
    - покрытие `EphemeralKeyStore`/reorg;
    - тесты делегаций/anchor mismatch;
    - RPC `anchor_hint`.

## 8. Пошаговый план работ (чек‑лист Iteration 5, по файлам и порядку)

1. **EphemeralKeyStore / формат хранения** (`wallet/core/src/storage/ephemeral_keys.rs`)
   - [ ] Добавить поля `created_daa_score`, `valid_until_daa` к `EphemeralKeyEntry` (порядок полей сохранить, новые в хвост).
   - [ ] Расширить ручной `BorshDeserialize` чтением хвостовых полей с дефолтами при `UnexpectedEof`.
   - [ ] Расширить `EphemeralKeyStatus` (`Orphaned { OrphanReason }`, `Expired`) и ввести `OrphanReason`.
   - [ ] Добавить `cleanup_expired(current_daa_score)` + вспомогательные геттеры/обновления статусов.
   - [ ] Unit‑тесты: миграция старого формата → новый, кейсы `cleanup_expired`.

2. **DAA‑хуки и обработка удаления** (`wallet/core/src/utxo/stealth_handler.rs`, `wallet/core/src/utxo/processor.rs`, `wallet/core/src/account/variants/stealth.rs`)
   - [ ] В трейд `StealthUtxoHandler` добавить `on_daa_score_changed`.
   - [ ] В `UtxoProcessor::handle_daa_score_change` вызывать `on_daa_score_changed` для всех stealth‑хендлеров.
   - [ ] В `StealthAccount` реализовать `on_daa_score_changed`: `cleanup_expired` + проверки делегаций.
   - [ ] Заменить прямое `ephemeral_keys.remove` на `mark_removed(outpoint, current_daa)` (мягкое удаление, reorg‑дружественно).

3. **Orphan‑overlay и интеграция с генератором** (`wallet/core/src/account/variants/stealth.rs`, `wallet/core/src/tx/generator/*`)
   - [ ] Ввести `OrphanOverlayMap` (outpoint → {reason, first_marked_daa}) и хранить его в стелс‑аккаунте.
   - [ ] Наполнять overlay при `try_claim_utxo_internal`/`try_claim_utxo` для UTXO вне окна делегации; восстанавливать overlay при загрузке из `EphemeralKeyStore`.
   - [ ] Фильтровать `utxo_iterator`/`priority_utxo_entries` для обычных платежей через overlay; предусмотреть отдельный путь для ручных сценариев (consolidate/spend‑orphaned).

4. **События кошелька** (`wallet/core/src/events.rs`, `wallet/core/src/wasm/events.rs` при наличии)
   - [ ] Добавить события `MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch` + `EventKind`.
   - [ ] Эмитить: истечение окна делегации (DAA‑хук), revoke/rotate делегации, anchor‑mismatch при скане.

5. **RPC `anchor_hint`** (`rpc/core/src/model/message.rs`, `rpc/grpc/core/proto/rpc.proto`, `rpc/grpc/core/src/convert/message.rs`, `rpc/core/src/wasm/message.rs`, `rpc/service/src/converter/consensus.rs`, `rpc/service/src/service.rs`)
   - [ ] В `RpcStealthOutputInfo` добавить `anchor_hint: Option<String>`, bump version `2 → 3` с обратной совместимостью.
   - [ ] Протянуть поле через gRPC/wRPC/WASM.
   - [ ] В сервисе пока заполнять `anchor_hint = None` (до появления индексатора).

6. **Индексатор (можно отдельным шагом)** (`indexes/processor/src/processor.rs` + новый модуль кэша)
   - [ ] Добавить `StealthAnchorHintCache (outpoint → anchor_hint u32)` в `Processor`.
   - [ ] Кэшировать хинты на `UtxosChanged` для стелс‑скриптов; предоставить API `get(txid, index)`.
   - [ ] В RPC‑слое использовать кэш при формировании `RpcStealthOutputInfo`.

7. **Тесты**
   - Unit: `ephemeral_keys` (миграция, cleanup), `stealth.rs` (delegation window, orphan reasons), RPC модель `RpcStealthOutputInfo` с/без `anchor_hint`.
   - Integration: `stealth_flow.rs` reorg + истечение делегации (ключи не теряются до `valid_until_daa`), обратная совместимость fallback без utxoindex; `mldsa_master.rs` — истечение/ревок делегации → событие + orphaned.

8. **Документация/статус**
   - [ ] Обновить `Phase2_MLDSA_master_key.md`, `docs/todo/stealth_view_tags.md`, `docs/IMPLEMENTATION_STATUS.md` после реализации.

## 9. Definition of Done (Iteration 5)

- **Функциональность:**
  - Стелс‑сканер учитывает окна делегаций; UTXO вне окна помечаются как orphaned и не используются автоматически.
  - Эфемерные ключи не теряются на реоргах до истечения `valid_until_daa`, очистка происходит детерминированно по DAA.
  - RPC `get_block_view_tags` стабильно работает с расширенным форматом `RpcStealthOutputInfo` (включая обратную совместимость), `anchor_hint` либо заполняется из кэша, либо `None`.
- **Тесты:**
  - Юнит‑тесты для `EphemeralKeyStore`, `StealthAccount` и RPC моделей зелёные.
  - Интеграционные тесты reorg/делегаций/seed‑recovery обновлены и проходят.
- **Docs/UX:**
  - Основной план Phase 2, `stealth_view_tags.md`, API‑дока и статус‑файл обновлены и отражают реализацию Iteration 5.
  - CLI/GUI (если есть) отображают orphaned UTXO и события делегаций в понятном для пользователя виде.

## 10. Замечания по реализации и подводные камни

Этот раздел фиксирует вещи, о которые проще всего «споткнуться» при реальной реализации Iteration 5:

- **Borsh + зашифрованные контейнеры:**
  - `EphemeralKeyEntry` сериализуется как часть `Vec<EphemeralKeyEntry>` внутри `Encrypted`‑контейнера без собственного `StorageHeader`:
    - любые изменения структуры возможны только через добавление полей с `#[borsh(default)]`;
    - порядок полей должен оставаться прежним, новые поля всегда добавляем **в конец** struct;
    - тестами нужно прогнать round‑trip со старыми файлами (см. §7.1), в идеале — с реальными test‑vectors из предыдущей версии.
- **Ссылочная целостность `delegation_id`:**
  - `delegation_id` в `EphemeralKeyEntry` ссылается на делегацию, которая действовала при приёме UTXO:
    - при удалении/ротации делегаций из хранилища их `id` нельзя «переиспользовать»;
    - миграции Iteration 4→5 должны аккуратно проставлять `delegation_id` только там, где связь однозначна (иначе `None` + `OrphanReason::NoDelegation`).
- **DAA и режим без utxoindex:**
  - `UtxoProcessor::current_daa_score()` может быть недоступен:
    - все места, где он используется (mark_removed, cleanup_expired, выбор окна делегаций), должны корректно обрабатывать `MissingDaaScore` (см. `Error::MissingDaaScore`) и вести себя консервативно (не удалять ключи, не метить UTXO orphaned «по недоразумению»);
    - для конфигураций без utxoindex DAA‑чистка рассматривается как best‑effort — план уже закрепляет, что поведение тестов Phase 1 не меняется.
- **0 / `None` как сигналы «старого формата»:**
  - `created_daa_score = 0` и `valid_until_daa = None` в старых записях `EphemeralKeyEntry` не означают ошибку, а обозначают «ключ создан до Iteration 5»:
    - логика очистки должна быть устойчивой к этим значениям (например, не выбрасывать все такие ключи сразу);
    - для них можно применять более «мягкую» политику TTL (удалять только по глобальному возрасту или никогда без явного действия пользователя).
- **Согласованность overlay и хранилища:**
  - overlay‑карта (`OrphanOverlayMap`) должна рассматриваться как кеш:
    - любые изменения делегаций/DAA/статусов сначала применяются к `EphemeralKeyStore`, а затем к overlay;
    - при любых сомнениях допускается «жёсткий» пересчёт overlay из `EphemeralKeyStore`+`UtxoContext` (maintenance‑API).
- **Тонкости UX:**
  - orphaned‑баланс никогда не должен «пропадать» из UI:
    - даже если ключи помечены как `Orphaned`, они отображаются отдельно, с понятной причиной (`DelegationExpired`, `AnchorMismatch`, ...);
  - все действия, которые тратят orphaned‑монеты, должны иметь явный UX‑маркер и логирование (это важно и для аудита, и для отладки).

Фиксация этих моментов в планах и код‑ревью должна заметно снизить риск неожиданных регрессий при реализации Iteration 5.


