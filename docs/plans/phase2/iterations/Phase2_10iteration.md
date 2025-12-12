## Phase 2 — Iteration 10: Observability & Telemetry

> **Цель итерации:** сделать использование MLDSA master и делегаций «прозрачным» в проде: чёткие счётчики, алерты и логи, по которым можно быстро увидеть аномалии (частые подписи, ротации, истекающие делегации, anchor mismatch), не трогая сам протокол и криптографию.

### 0. Контекст и границы итерации

- **Что предполагается готово (Iter.1–9):**
  - Детерминированный MLDSA master, хранение сидов и anchor (`MasterSeed`, `MasterAnchor`, `PrvKeyDataVariant::MlDsaMaster`, FFI/CLI/WASM).
  - Master‑аккаунт как `AccountKind` (`mldsa_master`), базовые события (`MasterAnchorCreated`, `MasterSeedExported`, планируемые `MasterAccountCreated`, `MasterAnchorMismatch` и т.п.).
  - Структуры делегаций и связь master ↔ stealth‑аккаунты (`DelegationRecord`, `master_anchor`, `delegation_id` в payload’ах), базовые RPC/airgap‑флоу (Iter.4–6).
  - UTXO‑сканер и handler’ы, понимающие делегации и истечение (`valid_until_daa`, события `MasterDelegationExpired`, `MasterDelegationRevoked` из Iter.5).
- **Что делаем в Iteration 10:**
  - Вводим **стабильные счётчики** вокруг операций мастера: подписи, ротации, создание/ревокация делегаций и airgap‑флоу.
  - Добавляем **уведомление** и события `MasterDelegationExpiringSoon` при приближении `valid_until_daa`.
  - Вводим **единообразный тег в логах** `master_anchor=<hex8>` для всех master‑операций и связанных делегаций.
  - Обновляем Docker‑образ кошелька (`Dockerfile.kaspa-wallet`) и описываем **healthcheck/флаги** для MLDSA master и airgap‑сервиса.
  - Описываем ожидания по **дашбордам и алертам** (инфра‑команда реализует их поверх экспортируемых метрик/логов).
- **Чего не делаем в Iteration 10:**
  - Не меняем формат `DelegationRecord` и ончейн‑протокол.
  - Не трогаем консенсус/`OpCheckSigMLDSA` и правила валидации транзакций.
  - Не меняем UX вокруг создания мастер‑аккаунта и делегаций (только добавляем поверх телеметрию и нотификации).

### 0.1. Architectural TL;DR

- **Где живут новые метрики:** только в `wallet/core` через `MasterMetrics` + новый variant `MetricsUpdate::MasterMetrics`, которые уезжают наружу по уже существующему каналу `Events::Metrics`. `metrics/core` и node‑метрики не меняются.
- **Что наблюдаем:** суммарное количество операций мастера (`sign`, `rotate`, issue/revoke делегаций, airgap‑request/response, healthcheck‑ошибки) и ранние предупреждения об истекающих делегациях (`MasterDelegationExpiringSoon`), без high‑cardinality label’ов (`anchor`, `account_id`).
- **Как это связано с ранее реализованным:** Iteration 10 **не трогает** семантику `valid_until_daa`/`EphemeralKeyEntry`/orphaned‑UTXO из Iteration 5 и airgap‑протокол из Iteration 6 — только дописывает поверх наблюдаемость (метрики, события, логи).
- **Интеграция с инфраструктурой:** Docker‑образ кошелька включает `ENABLE_MLDSA_MASTER=1` и healthcheck `kaspa-wallet health --mode=airgap`; внешние экспортёры и дашборды строятся поверх `Events::Metrics` и логов с тегом `master_anchor=<hex8>`, при сбоях телеметрии поведение кошелька остаётся прежним (деградация только в наблюдаемости).

### 0.2. План доработок (отладка, не выкатываем сейчас)

> Статус: отлаживаем, код не трогаем, готовим безопасный rollout.

- **Гейтинг TLV delegation_id:** привязать включение TLV `0xA1 || delegation_id` к сетевому флагу активации (mldsa_master/kip10), чтобы до активации оставаться в строгом формате. Базовое поведение уже работает, задача — лишь фичефлаг.
- **Notify‑бридж expiring soon:** `Events::MasterDelegationExpiringSoon` уже генерится в кошельке и тип добавлен в notify; нужно только мостить его в notify‑пайплайн (idempotent), без изменения протокола.
- **Тесты метрик:** добавить юнит/интеграцию для `MetricsUpdate::MasterMetrics` (serde + доставка через `UtxoProcessor::deliver_metrics_snapshot`), чтобы зафиксировать поведение.
- **Тесты watcher’а:** покрыть `DelegationExpiryWatcher` (одно срабатывание в warn‑окне, отсутствие дублей, игнор просроченных делегаций).
- **Документация/дашборды:** описать экспорт master‑метрик и примеры алертов; в `IMPLEMENTATION_STATUS.md` отметить, что итерация 10 в отладке и ждёт выката после тестов.
- **Smoke‑гейт:** перед выкладкой — целенаправленные тесты: `cargo test -p kaspa-wallet-core metrics delegation_watch stealth_signer` и `cargo test -p kaspa-testing-integration airgap_mldsa`.

### 1. Область изменений и файлы

| Подсистема | Файлы | Изменения |
|-----------|-------|-----------|
| Wallet metrics | `wallet/core/src/metrics.rs`, `wallet/core/src/events.rs`, `wallet/core/src/utxo/processor.rs` | Расширение `MetricsUpdate` и `MetricsUpdateKind` мастер‑счётчиками, доставка метрик через `Events::Metrics`. |
| Master / Delegations | `wallet/core/src/account/variants/mldsa_master.rs`, `wallet/core/src/account/delegation.rs`, `wallet/core/src/account/variants/stealth.rs` | Инструментация счётчиков (sign/rotate/delegate/revoke), генерация событий `MasterDelegationExpiringSoon`. |
| Notify | `notify/src/events.rs`, при необходимости `notify/src/notification.rs`, `notify/src/root.rs` | Добавление типа события/нотификации для истекающих делегаций, привязка к существующей системе подписок. |
| Node / metrics core | `metrics/core/src/{data.rs,lib.rs}` | Согласовать, что node‑метрики по‑прежнему живут в `metrics/core`, а **wallet‑master счётчики реализуются внутри `wallet/core` и экспортируются через `Events::Metrics`**; при необходимости документировать их как `wallet_master_*` для внешних экспортеров (Prometheus/Grafana), не меняя wire‑формат `GetMetricsResponse`. |
| Логирование | `wallet/core/src/{account/variants/mldsa_master.rs,account/delegation.rs,tx/generator/stealth_signer.rs,storage/ephemeral_keys.rs,wallet/mod.rs}` | Введение helper’ов для `master_anchor=<hex8>` и унифицированных лог‑сообщений. |
| Docker / CI | `docker/Dockerfile.kaspa-wallet`, `docker-compose.test.yml`, `docs/IMPLEMENTATION_STATUS.md`, `docs/TEST_COVERAGE_SUMMARY.md` | Env‑флаг `ENABLE_MLDSA_MASTER`, healthcheck для airgap‑режима, обновление статуса и матрицы тестов. |
| Observability‑доки | `docs/plans/phase2/Phase2_MLDSA_master_key.md`, `docs/NETWORK_TESTING.md`, `docs/PERFORMANCE_BENCHMARKS.md` | Описание новых метрик, событий и алертов, ссылки для инфра‑команды. |

### 2. Дизайн метрик MLDSA master

#### 2.1. Цели и ограничения

- **Цели:**
  - Видеть частоту и характер использования мастера (подписи, ротации, делегации).
  - Быстро находить аномалии (скачок sign‑операций, частые ротации, массовые ревокации).
  - Иметь базовые SLO: «не более N ротаций в день», «нет истёкших делегаций без алертов» и т.п.
- **Ограничения:**
  - Никаких high‑cardinality label’ов по якорям/аккаунтам (anchor только в логах).
  - Метрики не должны раскрывать приватную структуру кошелька (число master‑ов можно считать, но не связывать с конкретными сид‑ами).
  - Инструментация не должна тянуть тяжёлые зависимости (Prometheus и т.п. — на стороне обвязки; внутри — простые счётчики).

#### 2.2. Набор счётчиков и их семантика

Предлагаемый набор **глобальных** (по процессу кошелька) счётчиков **без внутренних label’ов** (все разрезы делаются уже на уровне экспортёра по `network`/`instance` и корреляции с логами):

- **`wallet_master_sign_ops_total`**
  - Инкремент: каждый успешный вызов `MldsaMasterAccount::sign_message` (любого домена).
  - Используется как общий индикатор нагрузки на master; детализация по доменам (`anchor_export`, `delegation`, `custom`) делается через анализ логов.
- **`wallet_master_rotations_total`**
  - Инкремент: каждый успешный переход статуса `MasterStatus::Active/Rotated → Rotated`.
  - Интерпретация «слишком частые ротации» строится уже на уровне дашбордов, без дополнительных label’ов внутри метрики.
- **`wallet_master_delegations_issued_total`**
  - Инкремент: при создании нового `DelegationRecord` (Iter.4/6).
  - В сочетании с ревокациями даёт общую динамику делегаций.
- **`wallet_master_delegations_revoked_total`**
  - Инкремент: при явной ревокации делегации или ротации мастера, которая убивает набор делегаций.
- **`wallet_master_delegations_expiring_soon_total`**
  - Инкремент: при первой генерации события `MasterDelegationExpiringSoon` для конкретной делегации.
  - Используется для алертов: если счётчик растёт, а обработки/продления нет — возможно, проблема в UX/инфре.

Важно: **ни один из счётчиков не содержит `anchor`/`account_id` как label**, чтобы не создавать неконтролируемую кардинальность. Идентификация конкретных мастеров и доменов операций — через логи с тегом `master_anchor=<hex8>` и человекочитаемым `domain`/`reason`.

#### 2.3. Структура `MasterMetrics` в `wallet/core`

- **Новый модуль/структура в `wallet/core/src/metrics.rs`:**

```rust
#[derive(Default)]
pub struct MasterMetrics {
    sign_ops_total: AtomicU64,
    rotations_total: AtomicU64,
    delegations_issued_total: AtomicU64,
    delegations_revoked_total: AtomicU64,
    delegations_expiring_soon_total: AtomicU64,
}

#[derive(Debug, Clone, Serialize, Deserialize, BorshSerialize, BorshDeserialize)]
pub struct MasterMetricsSnapshot {
    pub sign_ops_total: u64,
    pub rotations_total: u64,
    pub delegations_issued_total: u64,
    pub delegations_revoked_total: u64,
    pub delegations_expiring_soon_total: u64,
}
```

- **Синглтон‑доступ:**
  - `MasterMetrics::global() -> &'static MasterMetrics` через `OnceLock`/`lazy_static`.
  - Методы: `inc_sign_ops(..)`, `inc_rotations(..)`, `inc_delegations_issued(..)`, `inc_delegations_revoked(..)`, `inc_delegations_expiring_soon(..)`, `snapshot() -> MasterMetricsSnapshot`.
  - Семантика атомарных операций: достаточно `Ordering::Relaxed` (используем только для монотонных счётчиков, без кросс‑поточных инвариантов), но можно оставить `SeqCst` для единообразия с остальным кодом кошелька, если инфра не чувствительна к микрокостам.

> Тонкий момент: `MasterMetrics` не должен утекать в публичный API напрямую. Внешнему миру мы показываем только сериализованный `MasterMetricsSnapshot` через `Events::Metrics` и/или отдельные API, чтобы в будущем можно было менять внутреннюю реализацию счётчиков без wire‑лома.

#### 2.4. Расширение `MetricsUpdate` и доставки событий

- **`wallet/core/src/metrics.rs`:**
  - Расширить enum:

```rust
pub enum MetricsUpdate {
    WalletMetrics {
        mempool_size: u64,
    },
    MasterMetrics {
        metrics: MasterMetricsSnapshot,
    },
}

pub enum MetricsUpdateKind {
    WalletMetrics,
    MasterMetrics,
}
```

- **`wallet/core/src/utxo/processor.rs`:**
  - В `Inner` поле `metrics_kinds: Mutex<Vec<MetricsUpdateKind>>` уже есть.
  - В `deliver_metrics_snapshot` добавить ветку:

```rust
MetricsUpdateKind::MasterMetrics => {
    let master = MasterMetrics::global().snapshot();
    let metrics = MetricsUpdate::MasterMetrics { metrics: master };
    self.try_notify(Events::Metrics { network_id: self.network_id()?, metrics })?;
}
```

  - Таким образом:
    - `WalletMetrics` продолжает опираться на `MetricsSnapshot` из `metrics/core` (mempool).
    - `MasterMetrics` берёт данные из `MasterMetrics::global()` и «едет» тем же `Events::Metrics`.

- **API для включения мастер‑метрик:**
  - В `UtxoProcessor::enable_metrics_kinds` добавить возможность передавать `MetricsUpdateKind::MasterMetrics`.
  - В high‑level API кошелька (WASM/native/CLI) добавить флаг/метод `enableMasterMetrics()`/`--enable-master-metrics`, который добавляет этот вид в `metrics_kinds`.

> Тонкий момент совместимости: `MetricsUpdate` используется внутри `wallet/core` и на внешнем API как `Events::Metrics` (serde JSON для CLI/WASM). Добавление новой variant:
> - требует синхронно обновить все декодеры (CLI, WASM bridge) так, чтобы они хотя бы **молча игнорировали** незнакомые типы метрик или явно их отображали;
> - не меняет формат node‑метрик (`metrics/core` и `GetMetricsResponse` остаются прежними);
> - должен сопровождаться bump’ом минимальной версии кошелька в документации (старые клиенты не должны ожидать новых метрик).

#### 2.5. Инструментация точек в коде

- **`wallet/core/src/account/variants/mldsa_master.rs`:**
  - В `sign_message(..)` инкрементировать `MasterMetrics::global().inc_sign_ops(domain, result)`.
  - В `rotate(..)` после успешной ротации вызывать `inc_rotations(level_before, level_after, reason)`.
- **`wallet/core/src/account/delegation.rs` (Iter.4):**
  - При создании делегации (`DelegationRecord::new`) — `inc_delegations_issued(..)`.
  - При ревокации/отзыве (`DelegationRecord::revoke`/`DelegationManager::revoke`) — `inc_delegations_revoked(..)`.
- **`MasterDelegationExpiringSoon` (см. ниже)** — при первой генерации события для конкретной делегации инкрементировать `inc_delegations_expiring_soon(..)`.

Каждая точка инкремента должна быть **прикрыта юнит‑тестом**, чтобы не сломать телеметрию при будущих рефакторах.

#### 2.6. Метрики airgap‑флоу и ошибок

Помимо базовых счётчиков вокруг master/делегаций имеет смысл фиксировать **качество и надёжность airgap‑флоу** (Iter.6), не раскрывая содержимого запросов:

- **`wallet_master_delegation_requests_total`**
  - Инкремент: каждый успешный `build_master_delegation_request` (online‑сторона).
- **`wallet_master_delegation_responses_total`**
  - Инкремент: каждый успешный `apply_master_delegation_response`.
- **`wallet_master_delegation_responses_failed_total`**
  - Инкремент: любой фатальный отказ при apply (несовпадение `request_id`, неверная подпись, конфликт nonce и т.п.).
- **`wallet_master_anchor_mismatch_total`**
  - Инкремент: каждый раз, когда возникает событие `MasterAnchorMismatch` (см. Iter.5/7).
- **`wallet_master_healthcheck_failures_total`**
  - Инкремент: неуспешные выполнения `kaspa-wallet health --mode=airgap` (healthcheck Docker’а).

Эти счётчики:

- реализуются как дополнительные поля в `MasterMetrics`/`MasterMetricsSnapshot` (например, `delegation_requests_total`, `delegation_responses_total`, `delegation_responses_failed_total`, `anchor_mismatch_total`, `healthcheck_failures_total`);
- экспортируются тем же каналом `Events::Metrics`, а уже экспортёр вешает на них стандартные label’ы (`network`, `instance` и т.п.) и строит производные дашборды (доли ошибок, rate‑графики и т.д.).

#### 2.7. Экспорт метрик и дашборды

Важно зафиксировать **как именно** мастер‑метрики будут доходить до Prometheus/Grafana (или другого стека), не навязывая кошельку конкретного провайдера:

- **Источник:** `Events::Metrics { network_id, metrics: MetricsUpdate }` от кошелька.
- **Экспортёр:**
  - отдельный процесс/daemon (или модуль внутри существующего runtime), подписывающийся на wallet‑multiplexer и конвертирующий входящие `Events::Metrics` в формат целевой системы (Prometheus `/metrics`, OTLP и т.п.);
  - приёмник обязан:
    - маппить `network_id` в label `network`;
    - при желании добавлять `instance`/`wallet` label (например, по директории storage), но **не** якоря и не идентификаторы аккаунтов.
- **Рекомендованные панели и алерты (описать подробнее в `docs/NETWORK_TESTING.md`):**
  - Панель **Master usage**:
    - графики `rate(wallet_master_sign_ops_total[5m])` и `rate(wallet_master_rotations_total[1h])` с фильтром по `network`;
    - alert: «подозрительно много подписей» (`rate(sign_ops[5m]) > X` для mainnet) и «частые ротации» (`rate(rotations_total[1d]) > 3`).
  - Панель **Delegations health**:
    - `wallet_master_delegations_issued_total`, `revoked_total`, `delegations_expiring_soon_total`;
    - alert: если `delegations_expiring_soon_total` растёт, а за N часов не было соответствующих `delegations_issued_total`/`revoked_total`, это сигнал застрявших делегаций/UX‑проблем.
  - Панель **Airgap reliability**:
    - доля успешных apply vs. ошибок:
      - `rate(wallet_master_delegation_responses_failed_total[15m]) / rate(wallet_master_delegation_responses_total[15m])`;
    - alert: если процент ошибок превышает порог (например, 5%), поднять инцидент (возможен баг в оффлайн‑подписи или дрифт форматов).
  - Панель **Healthcheck**:
    - `wallet_master_healthcheck_failures_total` по инстансам;
    - alert: любой ненулевой рост по mainnet‑инстансам.

При описании дашбордов и алертов важно **не жёстко привязываться к Prometheus**, а зафиксировать только:

- перечень измеряемых величин;
- желаемые SLO/пороги;
- взаимосвязь метрик с рисками из основного плана (утечка мастера, расхождение делегаций, anchor mismatch и т.д.).

#### 2.8. Матрица «метрика ↔ событие ↔ итерация»

Для удобства ревью/аудита фиксируем, откуда каждая метрика берётся и к каким итерациям Phase 2 она относится:

| Метрика | Источник инкремента / событие | Основная итерация |
|--------|--------------------------------|--------------------|
| `wallet_master_sign_ops_total` | `MldsaMasterAccount::sign_message` (успех/ошибка по доменам `anchor_export`, `delegation`, `custom`) | Iter.2–3 (master account API) |
| `wallet_master_rotations_total` | Успешные `MldsaMasterAccount::rotate` (смена anchor/level) | Iter.3 (master account lifecycle) |
| `wallet_master_delegations_issued_total` | Создание `DelegationRecord` (`DelegationRecord::new` / `apply_master_delegation_response`) | Iter.4/6 (delegations + airgap) |
| `wallet_master_delegations_revoked_total` | Ревокация/ротация делегаций (`DelegationManager::revoke` / rotate‑потоки) | Iter.4/5 |
| `wallet_master_delegations_expiring_soon_total` | Первое событие `Events::MasterDelegationExpiringSoon` для делегации | Iter.5 (valid_until_daa) + Iter.10 |
| `wallet_master_delegation_requests_total` | Онлайн‑вызовы `build_master_delegation_request` | Iter.6 |
| `wallet_master_delegation_responses_total` | Успешные `apply_master_delegation_response` | Iter.6 |
| `wallet_master_delegation_responses_failed_total` | Ошибки `apply_master_delegation_response` с разными `reason` | Iter.6/10 |
| `wallet_master_anchor_mismatch_total` | Событие `Events::MasterAnchorMismatch` (unlock или обнаружение mismatch при работе со стелс‑UTXO) | Iter.3/5 |
| `wallet_master_healthcheck_failures_total` | Неуспешные `kaspa-wallet health --mode=airgap` | Iter.8/10 |

Эта матрица:

- помогает держать трассировку «план ↔ код ↔ метрики» в одном месте;
- используется в `docs/TEST_COVERAGE_SUMMARY.md` как каркас для проверки того, что каждая метрика покрыта хотя бы одним тестом;
- служит входом для `docs/NETWORK_TESTING.md`, где на её основе описываются сценарии нагрузочного/инцидентного тестирования.

#### 2.9. Поведение по умолчанию и включение метрик

Чтобы избежать расхождений между окружениями, фиксируем ожидаемое поведение по умолчанию:

- **Клиентский API кошелька (`Wallet` / WASM / native):**
  - При создании runtime‑кошелька в типичном приложении (desktop/мобильный) рекомендуется:
    - всегда включать `MetricsUpdateKind::WalletMetrics` (как уже сделано через `UtxoProcessor::start_metrics`);
    - включать `MetricsUpdateKind::MasterMetrics` и airgap‑метрики:
      - в dev/test окружениях — по умолчанию;
      - в production — по умолчанию **включено**, но допускается конфиг‑флаг (env/CLI) для временного выключения (например, при отладке проблем с экспортёром).
- **CLI:**
  - Добавить флаг/команду (пример):  
    - `wallet metrics enable --kinds wallet,master,airgap`  
    - `wallet metrics disable --kinds master`  
  - По умолчанию `wallet start` (или аналогичная команда) включает как минимум `wallet`+`master` метрики, если `EnableMldsaMaster == true`.
- **WASM / JS SDK:**
  - В `WalletApi` зафиксировать метод `enableMetricsKinds(kinds: Array<'wallet' | 'master' | 'airgap'>)`, который маппится на `Wallet::enable_metrics_kinds`.
  - В доках указать, что, если приложение **не** использует наблюдаемость (например, чистый браузерный dApp без бекенда), оно может не подписываться на `Events::Metrics` и просто игнорировать master‑метрики.

### 3. Дизайн уведомлений `MasterDelegationExpiringSoon`

#### 3.1. Модель события в `wallet/core`

- **Новый вариант в `wallet/core/src/events.rs::Events`:**

```rust
Events::MasterDelegationExpiringSoon {
    account_id: AccountId,
    delegation_id: u64,
    anchor: String,          // hex‑строка (короткая или полная)
    valid_until_daa: u64,
    current_daa_score: u64,
    warn_window_daa: u64,    // фактическое окно предупреждения
}
```

- **Расширение `EventKind`:**
  - Добавить `MasterDelegationExpiringSoon` в enum, `From<&Events>` и `Display`/`FromStr`.
  - Строковое имя, например: `"master-delegation-expiring-soon"`.

#### 3.2. Алгоритм детекции «истекает скоро»

- **Источник данных:**
  - `DelegationRecord` (Iter.4) содержит `valid_until_daa: u64 (optional)` и `anchor`.
  - Текущий `DAA` приходит из `UtxoProcessor::current_daa_score()` и события `Events::DaaScoreChange`.
- **Порог‑окно:**
  - Конфигурируемый `warn_window_daa` (по умолчанию, например, эквивалент ~7 дням для mainnet и меньше для devnet/testnet).
  - Значение берётся из:
    - настроек кошелька (`WalletSettings::DelegationExpiryWarnWindowDaa`),
    - либо env‑переменных (например, `MLDSA_DELEGATION_WARN_DAA`).
- **Условие срабатывания:**
  - Работает **только** для делегаций, у которых задано окно `valid_until_daa`:

```text
if let Some(valid_until) = delegation.valid_until_daa {
   // Уже истекла → не предупреждаем, пусть сработает логика Iteration 5 (MasterDelegationExpired)
   if current_daa_score >= valid_until {
       return;
   }

   // Находимся в пред‑окне предупреждения и раньше ещё не предупреждали в этом окне
   if current_daa_score >= valid_until - warn_window_daa &&
      !delegation.warned_recently(current_daa_score, warn_window_daa) {
       emit MasterDelegationExpiringSoon;
   }
}
```

- **Хранение состояния предупреждений:**
  - **Целевой вариант (с учётом Iteration 5/6):**
    - в `wallet/core/src/account/delegation.rs` у `DelegationRecord` добавляется поле `warned_at_daa: Option<u64>` с `#[borsh(default)]`;
    - helper `warned_recently(current_daa, warn_window_daa)` реализуется как:
      - `false`, если `warned_at_daa.is_none()`;
      - `true`, если `current_daa - warned_at_daa < warn_window_daa`;
      - при генерации `MasterDelegationExpiringSoon` мы записываем `warned_at_daa = Some(current_daa)`.
  - **Временный вариант (до добавления поля `warned_at_daa`, если он внедряется другой итерацией):**
    - runtime‑кэш `HashSet<(account_id, delegation_id)>` или `HashMap<DelegationKey, last_warned_daa>` в `DelegationExpiryWatcher`;
    - план фиксирует, что как только поле `warned_at_daa` появится в `DelegationRecord` (например, в Iteration 5/7), логика watcher’а должна быть переведена на него, а runtime‑кэш останется только как in‑memory‑акселерация.
  - При перезапуске кошелька:
    - если `warned_at_daa` реализовано в `DelegationRecord` — поведение полностью детерминировано;
    - если мы пока живём на runtime‑кэше — допустимы повторные предупреждения, и это явно задокументировано для инфра/UX.

#### 3.3. Реализация наблюдателя делегаций

- **Новый модуль, например `wallet/core/src/account/delegation_watch.rs`:**
  - Хранит:
    - слабую ссылку на `Wallet`/`AccountStore`,
    - доступ к `UtxoProcessor` (для `current_daa_score`),
    - runtime‑set «уже предупреждали» (`HashSet<DelegationKey>`).
  - API:

```rust
pub struct DelegationExpiryWatcher { /* ... */ }

impl DelegationExpiryWatcher {
    pub fn new(wallet: Arc<Wallet>, utxo: UtxoProcessor, warn_window_daa: u64) -> Self { /* ... */ }
    pub async fn on_daa_score_change(&self, current_daa: u64) -> Result<()> { /* ... */ }
}
```

  - Внутри `on_daa_score_change`:
    - обойти активные `StealthAccount` с привязанным `master_anchor`,
    - для каждой активной делегации (`delegation.valid_until_daa.is_some()`) проверить условие из 3.2
      с использованием и `valid_until_daa`, и `warned_at_daa`,
    - сгенерировать `Events::MasterDelegationExpiringSoon { ... }`,
    - пометить делегацию как «предупреждённую» в runtime‑сете,
    - инкрементировать `MasterMetrics::global().inc_delegations_expiring_soon(..)`.

- **Интеграция с `UtxoProcessor`:**
  - **Не** встраивать watcher напрямую в `UtxoProcessor::handle_daa_score_change` (чтобы не плодить жёсткие зависимости и не блокировать UTXO‑поток).
  - Вместо этого завести отдельную таску внутри `Wallet`, подписанную на `Events::DaaScoreChange` через wallet‑multiplexer (аналогично CLI‑слою в `cli/src/cli.rs`), и уже из этой таски вызывать `delegation_watcher.on_daa_score_change(current_daa_score)`.
  - Инициализацию `DelegationExpiryWatcher` и регистрацию подписки на `Events::DaaScoreChange` делать внутри `Wallet` при создании runtime‑окружения (там же, где поднимается UTXO‑процессор), чтобы вся логика master/delegations оставалась на стороне кошелька, а не UTXO‑ядра.

#### 3.4. Интеграция с `notify`

- **`notify/src/events.rs`:**
  - При необходимости добавить новый `EventType::MasterDelegationExpiringSoon` и увеличить `EVENT_COUNT`.
  - Использовать его для подписок внешних клиентов (например, мобильного UI, который показывает баннер «делегации истекают»).
- **`notify/src/notification.rs` и `notify/src/root.rs`:**
  - Добавить трансляцию wallet‑события `Events::MasterDelegationExpiringSoon` в notify‑pipeline (если уже есть мост кошелёк → notify).
  - Обеспечить человекочитаемое описание (`title`, `body`) для UI.

> Тонкий момент: исходный `notify`‑стек в этом репо обслуживает node‑уровневые события (`BlockAdded`, `UtxosChanged`, `StealthUtxosChanged`). Для master‑делегаций мы работаем **на уровне кошелька**; связывать эти два мира стоит только через чётко очерченный мост (например, отдельный wallet‑daemon, который транслирует `Events::MasterDelegationExpiringSoon` в `notify`), чтобы не «тащить» кошелёк внутрь ноды.

### 3.5. Reorg, повторные срабатывания и масштабирование

- **Reorg и DAA:**
  - DAA‑скора в Kaspa монотонна, поэтому watcher может опираться на неубывающий `current_daa_score`, не делая rollback’ов.
  - Логика реального истечения (`MasterDelegationExpired`, из Iter.5) должна быть вынесена в общий helper (например, `DelegationRecord::is_expired(current_daa)`) и использоваться **и** в watcher, **и** в местах фактического отключения делегаций (сканер/ephemeral store), чтобы избежать рассинхронизации.
- **Повторные нотификации:**
  - Даже при runtime‑подходе (in‑memory set) важно явно задать политику: «одно предупреждение за окно DAA» и описать это в API, иначе внешние алерты могут флапать.
  - При переходе на персистентное поле `warned_at_daa` в `DelegationRecord` нужно bump’нуть его версию и добавить миграцию (как в `StealthAccount::Payload`), чтобы старые записи читались прозрачно (значение `None` трактуется как «никогда не предупреждали»).
- **Масштабирование:**
  - На старте можно обойтись простым проходом по всем активным делегациям при каждом `DaaScoreChange` — количество master/stealth‑аккаунтов в реальном кошельке ограничено.
  - Если в будущем количество делегаций станет большим, стоит добавить индекс по `valid_until_daa` (например, `BTreeMap<valid_until_daa, DelegationKey>`) и проверять только те записи, у которых `valid_until_daa` попадает в окно `[current_daa_score, current_daa_score + warn_window_daa]`.

### 3.6. Синхронизация с Iteration 5/6 (`valid_until_daa`, `warned_at_daa`)

- **Связь с Iteration 5 (lifecycle делегаций и эфемерных ключей):**
  - Iteration 5 уже трактует `valid_until_daa` как жёсткую границу, после которой делегация считается истёкшей (`MasterDelegationExpired`) и ключи/UTXO начинают помечаться как orphaned/expired (через `EphemeralKeyEntry.valid_until_daa` и расширенный `EphemeralKeyStatus`).
  - Iteration 10 **не меняет** эту семантику: watcher `DelegationExpiryWatcher`:
    - использует `DelegationRecord.valid_until_daa` только для раннего уведомления до фактического истечения;
    - **никогда** не генерирует `MasterDelegationExpiringSoon` для делегаций, которые уже считаются истёкшими по правилам Iteration 5 (см. условие в §3.2: `current_daa < valid_until`).
  - Вся «тяжёлая» работа по статусам UTXO и `EphemeralKeyEntry` (Orphaned/Expired, очистка `cleanup_expired`) остаётся в Iteration 5; Iteration 10 добавляет над этим только наблюдаемость и алерты.
- **Связь с Iteration 6 (airgap и offline‑делегации):**
  - Iteration 6 управляет жизненным циклом `DelegationRecord` (через `MasterDelegationRequest/Response` и `apply_master_delegation_response`), в т.ч. заполняет `valid_from_daa`/`valid_until_daa` и `nonce`.
  - `DelegationExpiryWatcher` опирается на уже применённые и проверенные делегации:
    - watcher не знает и не должен знать о «сырых» request/response до их применения;
    - как только новый `DelegationRecord` закоммичен (через Iteration 6), он автоматически попадает в область видимости watcher’а.
  - При импорте ответа (Iteration 6), если `valid_until_daa` уже близко к текущему `DAA`, алгоритм §3.2 сработает немедленно:
    - `current_daa_score >= valid_until_daa - warn_window_daa` → `MasterDelegationExpiringSoon` может быть сгенерирован сразу после apply.
- **`warned_at_daa` как общее поле:**
  - План Iteration 10 предполагает, что `warned_at_daa: Option<u64>` будет добавлено непосредственно в `DelegationRecord` (в том же стиле, как Iteration 5 расширяет `EphemeralKeyEntry` полями `valid_until_daa` и статусами).
  - Это поле используется:
    - watcher’ом Iteration 10 для подавления повторных «expiring soon»‑ивентов;
    - потенциально в Iteration 7 (property‑тесты/инварианты), чтобы формально зафиксировать, что каждая делегация генерирует не более одного предупреждения за окно.
  - Миграция:
    - реализуется аналогично миграции payload’ов в Iteration 3/5: новое поле с `#[borsh(default)]`, старые записи получают `warned_at_daa = None`.
  
#### 3.7. Интеграция watcher’а в жизненный цикл `Wallet`

Чтобы не было расхождений в реализации, фиксируем, **где именно** должен жить `DelegationExpiryWatcher`:

- **Структуры:**
  - В `wallet/core/src/wallet/mod.rs` (во внутреннем `Inner`) появляется поле:
    - `delegation_expiry_watcher: Option<DelegationExpiryWatcher>`,
    - `delegation_expiry_task_ctl: DuplexChannel` (по паттерну других фоновых задач).
- **Старт:**
  - В `Wallet::start_task` (или в месте, где уже поднимается UTXO‑процессор и подписка на multiplexer):
    1. Создать `DelegationExpiryWatcher::new(self.clone(), self.utxo_processor().clone(), warn_window_daa_from_settings)`.
    2. Сохранить его в `inner.delegation_expiry_watcher`.
    3. Запустить фоновую таску:
       - таска слушает wallet‑multiplexer (канал, который уже читает CLI, см. `cli/src/cli.rs`) и отфильтровывает только `Events::DaaScoreChange { current_daa_score }`;
       - при каждом таком событии вызывает `watcher.on_daa_score_change(current_daa_score).await`.
    4. Управление остановкой/завершением таски (через `delegation_expiry_task_ctl`) синхронизируется с уже существующим `Wallet::stop_task`.
- **Стоп и очистка:**
  - В `Wallet::stop_task`:
    - послать сигнал через `delegation_expiry_task_ctl`, дождаться завершения таски;
    - очистить `inner.delegation_expiry_watcher` (в т.ч. runtime‑кэш предупреждений).
- **Многократные старты/рестарты:**
  - План явно предполагает, что:
    - повторный вызов `start_task` при уже запущенной таске должен быть невозможен (существующая логика `task_is_running` это уже обеспечивает);
    - при рестарте кошелька watcher восстанавливается вместе с остальным runtime, и, благодаря `warned_at_daa` в `DelegationRecord`, повторных «expiring soon» уведомлений не будет.

### 4. Логирование `master_anchor=<hex8>`

#### 4.1. Общие правила

- **Ключевая идея:** все операции, меняющие состояние мастера или делегаций, должны писать в логи строку с единым ключом `master_anchor=<short_hex>`.
- **Требования:**
  - Не логировать секреты (сид, приватные ключи, raw seed).
  - Для anchor — по умолчанию короткий префикс (например, первые 8 байт в hex), полный anchor — только в debug/trace при необходимости.
  - Лог‑сообщения должны быть доступны в Elastic/Grafana Loki и легко фильтроваться по `master_anchor=...`.

#### 4.2. Helper для форматирования якоря

- **В `wallet/core/src/account/variants/mldsa_master.rs` или отдельном utils‑модуле:**

```rust
pub fn format_master_anchor_short(anchor: &MasterAnchor) -> String {
    let bytes = anchor.as_bytes();
    hex::encode(&bytes[..4]) // 8 hex символов
}
```

- Аналогичный helper можно предоставить для `DelegationRecord`, чтобы в логах всегда была **одинаковая форма** представления.

#### 4.3. Точки логирования

- **Создание/ротация master‑аккаунта:**
  - `MldsaMasterAccount::create` / `Wallet::create_account_mldsa_master`:
    - `log_info!("Created MLDSA master account: master_anchor={} level={:?}", format_master_anchor_short(&anchor), level);`
  - `MldsaMasterAccount::rotate`:
    - `log_info!("Rotated MLDSA master: master_anchor={} level_before={:?} level_after={:?} reason={:?}", ...)`.
- **Операции подписи:**
  - В `sign_message` логировать:
    - `domain`, `result` (`ok`/`error`), `master_anchor`.
  - Уровень — `trace`/`debug` по умолчанию, чтобы не шуметь в проде, но иметь возможность реконструировать поток.
- **Делегации:**
  - Создание: `log_info!("Created master delegation: master_anchor={} delegation_id={} valid_until_daa={:?}", ...)`.
  - Ревокация: `log_info!("Revoked master delegation: master_anchor={} delegation_id={} reason={:?}", ...)`.
  - Истечение/близость к истечению:
    - `log_warn!("Master delegation expiring soon: master_anchor={} delegation_id={} valid_until_daa={} current_daa_score={} warn_window_daa={}", ...)`.
    - `log_warn!("Master delegation expired: master_anchor={} delegation_id={} valid_until_daa={} current_daa_score={}", ...)`.
- **Anchor mismatch:**
  - При `MasterAnchorMismatch`:
    - `log_error!("Master anchor mismatch: master_anchor_expected={} master_anchor_actual={} account_id={}", ...)`.

Все новые лог‑точки должны быть **привязаны к событиям** (`Events::MasterAccountRotated`, `Events::MasterDelegationExpired`, `Events::MasterDelegationExpiringSoon` и т.д.) — это упростит поиск инцидентов по журналу событий.

Дополнительно:

- Для airgap‑флоу (Iter.6) лог‑записи вокруг:
  - `build_master_delegation_request`;
  - `sign_master_delegation_request` (оффлайн);
  - `apply_master_delegation_response`;
  должны содержать:
  - `master_anchor=<hex8>`;
  - `delegation_request_id=<hex8>` (первые байты `request_id` из Iter.6) — это позволит чётко связывать метрики (`*_responses_failed_total`) и конкретные сессии делегаций в логах.
- При healthcheck’ах:
  - `log_error!("Wallet healthcheck failed: mode=airgap reason={:?}", err);` с тегом `master_anchor` (если релевантно) и идентификатором storage/instance.

### 5. Docker, флаги и healthcheck

#### 5.1. Env‑флажки для MLDSA master

- **`docker/Dockerfile.kaspa-wallet`:**
  - В секции runtime добавить:

```dockerfile
ENV ENABLE_MLDSA_MASTER=1
```

  - Это значение должно:
    - мапиться на `WalletSettings::EnableMldsaMaster` по умолчанию,
    - при необходимости переопределяться через конфиг/CLI в тестовых окружениях.

- **`docker-compose.test.yml`:**
  - Прописать `ENABLE_MLDSA_MASTER=1` для сервисов, использующих кошелёк.

#### 5.2. Healthcheck для airgap‑сервиса

- **Требование:** иметь простой бинарный health‑endpoint для Kubernetes / Docker, который проверяет базовое здоровье MLDSA‑фич (особенно airgap).
- **CLI/daemon:**
  - В `cli/src/main.rs`/`cli/src/modules/wallet.rs` ввести команду:

```text
kaspa-wallet health --mode=airgap
```

  - Поведение:
    - Проверить, что:
      - хранилище wallet открывается,
      - `PrvKeyDataVariant::MlDsaMaster` доступен (если `ENABLE_MLDSA_MASTER=1`),
      - базовые RPC/FFI маршруты, необходимые для airgap‑флоу (export/import delegation request), регистрируются без ошибок.
    - Вернуть код `0` при успехе, `!=0` при ошибке.
- **Docker‑healthcheck:**
  - В `Dockerfile.kaspa-wallet`:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD /app/kaspa-wallet health --mode=airgap || exit 1
```

  - Для dev/test окружений healthcheck можно отключать через переменную окружения (`DISABLE_WALLET_HEALTHCHECK`).

#### 5.3. Согласование с Consensus / params

- Проверить, что флаг `enable_mldsa_master` в консенсус‑параметрах (Iter.8) **согласован** с Docker‑флагом:
  - devnet: оба включены по умолчанию.
  - testnet/mainnet: включение через отдельный rollout‑план, чтобы не сломать старые кошельки.

### 6. Тестирование и валидация наблюдаемости

#### 6.1. Unit‑тесты

- **`wallet/core/src/metrics.rs`:**
  - Тесты на `MasterMetrics`:
    - инкременты потокобезопасны (`Relaxed`/`SeqCst` semantics),
    - snapshot возвращает ожидаемые значения.
  - Проверка сериализации `MasterMetricsSnapshot` (Borsh/serde).
- **Инструментация мастера:**
  - `MldsaMasterAccount::sign_message`:
    - успешный sign увеличивает `sign_ops_total`,
    - ошибка (например, lock/нет ключа) не увеличивает или помечается `result=error` — по выбранной политике.
  - `rotate`/делегации — аналогично.
  - Метрики airgap‑флоу:
    - `wallet_master_delegation_requests_total`/`responses_total`/`responses_failed_total` корректно отражают результат вызовов `build_master_delegation_request`/`apply_master_delegation_response`;
    - для разных причин ошибок (подпись, `request_id`, nonce, сеть) корректно инкрементируется общий `responses_failed_total`, а детализация по причинам фиксируется в логах/событиях (без дополнительных label’ов внутри метрик).

#### 6.2. Интеграционные тесты

- **MLDSA master + метрики:**
  - В `testing/integration/mldsa_master.rs`:
    - сценарий: создать master → выполнить N подписей → проверить, что `MasterMetrics::global().snapshot().sign_ops_total == N`.
    - ротация/делегации аналогично.
- **Expiry‑watcher:**
  - Новый тест, например `testing/integration/mldsa_delegation_expiry.rs`:
    - задать делегации с `valid_until_daa = X`,
    - прогнать серию `handle_daa_score_change` через watcher (имитация роста DAA),
    - убедиться, что:
      - событие `Events::MasterDelegationExpiringSoon` сгенерировано ровно один раз на делегацию,
      - счётчик `delegations_expiring_soon_total` соответствует количеству делегаций.

#### 6.3. Manual/observability‑тесты

- Сценарий для инфра‑команды:
  - Поднять devnet‑кластер с включённым `ENABLE_MLDSA_MASTER=1`.
  - Создать несколько master‑ов и делегаций, намеренно ускорить `valid_until_daa`.
  - Проверить:
    - наличие новых метрик в экспортируемом endpoint’е/логах,
    - приход событий `MasterDelegationExpiringSoon` на клиента,
    - корректную работу healthcheck’а контейнера.
  - Отдельно прогнать сценарии airgap‑флоу:
    - несколько успешных `build → sign → apply`, убедившись, что:
      - счётчики `*_responses_failed_total` == 0;
      - в логах есть привязка `master_anchor` + `delegation_request_id`;
    - сознательно сломанные ответы (подмена `request_id`, подписи, неправильная сеть), проверив:
      - рост `wallet_master_delegation_responses_failed_total` с нужными причинами;
      - отсутствие побочных изменений в состоянии делегаций/кошелька (idempotency ошибок).

### 7. Пошаговый чек‑лист Iteration 10

1. **Базовая модель метрик**
   - [x] Добавить `MasterMetrics` и `MasterMetricsSnapshot` в `wallet/core/src/metrics.rs`.
   - [x] Расширить `MetricsUpdate` и `MetricsUpdateKind`, обновить `UtxoProcessor::deliver_metrics_snapshot`.
   - [x] Добавить API включения мастер‑метрик (`enable_master_metrics`).
2. **Инструментация мастера и делегаций**
   - [x] Инкременты в `MldsaMasterAccount::sign_message` и `rotate`.
   - [x] Инкременты в создании/ревокации делегаций (`DelegationRecord`/`DelegationManager`).
   - [x] Юнит‑тесты на корректный подсчёт.
3. **Watcher истечения делегаций**
   - [x] Реализовать `DelegationExpiryWatcher` и интегрировать его через подписку на `Events::DaaScoreChange` (wallet‑multiplexer), не изменяя внутренний код `UtxoProcessor`.
   - [x] Добавить событие `Events::MasterDelegationExpiringSoon` и привязать к watcher’у.
   - [ ] Опционально — интегрировать с `notify` (новый `EventType`).
4. **Логирование `master_anchor`**
   - [x] Добавить helper форматирования якоря и использовать его в master/delegation/scan‑логах.
   - [x] Покрыть ключевые операции (create/rotate/sign/delegate/revoke/expiry/mismatch).
5. **Docker и healthcheck**
   - [x] Включить `ENABLE_MLDSA_MASTER=1` в `Dockerfile.kaspa-wallet` и `docker-compose.test.yml`.
   - [x] Реализовать CLI‑команду `kaspa-wallet health --mode=airgap`.
   - [x] Добавить `HEALTHCHECK` в Dockerfile и описать его в документации.
6. **Документация и статус**
   - [ ] Обновить `docs/plans/phase2/Phase2_MLDSA_master_key.md` (раздел Iteration 10 → подробный, со ссылкой на этот файл).
   - [x] Обновить `docs/IMPLEMENTATION_STATUS.md` с пометкой «Iteration 10 в отладке» и шагами по телеметрии.
   - [x] Обновить `docs/TEST_COVERAGE_SUMMARY.md` (статус наблюдаемости: в отладке, доп. тесты после фичефлагов).
   - [x] Зафиксировать требования к дашбордам/алертам в `docs/NETWORK_TESTING.md` (пометка: observability блок не выкатываем, включим после фичефлага TLV/notify).

### 8. Definition of Done для Iteration 10

- **Метрики:** счётчики `wallet_master_*` доступны через стандартный канал метрик кошелька (Events/endpoint), покрыты юнит‑тестами.
- **Нотификации:** реализовано событие `MasterDelegationExpiringSoon`, watcher стабильно отрабатывает на рост `DAA`.
- **Логи:** все ключевые операции мастера и делегаций содержат тег `master_anchor=<hex8>` и не логируют секреты.
- **Инфраструктура:** Docker‑образ кошелька включает `ENABLE_MLDSA_MASTER=1`, healthcheck для airgap‑режима работает, документация и матрица тестов обновлены.

### 9. Риски Iteration 10 и стратегия деградации

Чтобы телеметрия и наблюдаемость не стали новым источником отказов/регрессий, фиксируем отдельным списком риски именно этой итерации и ожидаемое поведение при деградации:

1. **Отказ экспортёра метрик или несоответствие версий.**  
   - *Риск:* экспортёр, читающий `Events::Metrics`, не понимает новый variant `MasterMetrics` или airgap‑метрики.  
   - *Ожидаемая деградация:*  
     - кошелёк продолжает работать штатно, просто без части метрик;  
     - экспортер по умолчанию должен игнорировать неизвестные типы `MetricsUpdate` или логировать soft‑warning, но не падать.  
   - *Митигаторы:*  
     - в этом плане и в `docs/IMPLEMENTATION_STATUS.md` фиксируется минимальная версия клиента/экспортёра, поддерживающая master‑метрики;  
     - тесты для JS/WASM/CLI‑декодеров (`Events::Metrics`) гарантируют, что добавление новых variant не ломает существующее поведение.

2. **Флаттер алертов по `MasterDelegationExpiringSoon`.**  
   - *Риск:* при неточностях в конфиге `warn_window_daa` или при переездах кошелька с сильно сдвинутым DAA появляются частые уведомления об «истекающих делегациях».  
   - *Ожидаемая деградация:*  
     - алерты могут быть шумными, но не ломают протокол и не блокируют операции;  
     - максимум одно предупреждение на делегацию за окно `warn_window_daa` (через `warned_at_daa`), что ограничивает частоту.  
   - *Митигаторы:*  
     - явный параметр `WalletSettings::DelegationExpiryWarnWindowDaa` и документация по его тюнингу в `docs/NETWORK_TESTING.md`;  
     - property‑/integration‑тесты на «однократное срабатывание» watcher’а при росте DAA.

3. **Ложные выводы из агрегированных счётчиков.**  
   - *Риск:* оператор пытается интерпретировать рост `wallet_master_sign_ops_total` как сигнал утечки, хотя это, например, валидное массовое делегирование или миграция.  
   - *Ожидаемая деградация:*  
     - метрика сама по себе не может инициировать ончейн‑блокировки/аварий;  
     - решения принимаются только после сверки с логами (`master_anchor`, `delegation_request_id`) и бизнес‑контекстом.  
   - *Митигаторы:*  
     - в `docs/PRIVACY_AND_QUANTUM_STRATEGY.md` и `docs/NETWORK_TESTING.md` фиксируются рекомендации по интерпретации метрик;  
     - алерты строятся не только на абсолютных значениях, но и на сочетании показателей (например, `sign_ops_total` + `delegations_issued_total`).

4. **Перегрузка логов master‑ивентами.**  
   - *Риск:* при слишком подробном логировании (особенно на `debug/trace`) объем логов может резко вырасти.  
   - *Ожидаемая деградация:*  
     - при прод‑конфиге ключевые сообщения (`rotate`, `expired`, `expiring_soon`, `anchor_mismatch`, healthcheck‑ошибки) идут на уровне `info/warn/error`;  
     - детальные трассировки (каждый `sign_message`) держатся на `debug/trace` и выключаются в production по умолчанию.  
   - *Митигаторы:*  
     - централизованный конфиг лог‑уровней (через env/конфигурацию) и гайды по нему в `docs/NETWORK_TESTING.md`;  
     - выборочно включаемый trace‑режим для расследования конкретных инцидентов.

5. **Несогласованность метрик между устройствами (multi‑device).**  
   - *Риск:* пользователь использует один и тот же сид на нескольких устройствах, но экспортёр смотрит только на один источник метрик.  
   - *Ожидаемая деградация:*  
     - глобальные счётчики `wallet_master_*` становятся «per‑instance», их не следует трактовать как «абсолют по сид‑у»;  
     - агрегирование по нескольким инстансам — задача уровня observability‑стека, а не кошелька.  
   - *Митигаторы:*  
     - в этом плане и в `Phase2_MLDSA_master_key.md` явно указано, что метрики — **per‑process**, а не per‑сид;  
     - при необходимости внешняя система может аггрегировать их по совпадающим `master_anchor` в логах, но это делается вне кошелька.

6. **Баги в healthcheck’е блокируют деплой.**  
   - *Риск:* некорректная реализация `kaspa-wallet health --mode=airgap` может помечать контейнер как unhealthy при несущественных проблемах.  
   - *Ожидаемая деградация:*  
     - dev/test окружения могут отключать healthcheck через `DISABLE_WALLET_HEALTHCHECK=1`;  
     - в mainnet‑окружении healthcheck должен проверять только минимально необходимый набор инвариантов (хранилище, наличие master, базовые RPC/FFI), не завязываясь на тонкие UX‑детали.  
   - *Митигаторы:*  
     - отдельные интеграционные тесты для healthcheck‑команды;  
     - явное описание того, что он проверяет, в `docs/NETWORK_TESTING.md` и `docs/MIGRATION_STRATEGY.md`, чтобы операторы могли быстро интерпретировать статус.

### 10. Зависимости от других итераций Phase 2

Iteration 10 опирается на результаты предыдущих итераций и должна быть реализована **после** их завершения:

- **Iteration 1–3:** детерминированный MLDSA master, структуры `MasterSeed`, `MasterAnchor`, `PrvKeyDataVariant::MlDsaMaster`, базовый API `MldsaMasterAccount::sign_message` и `rotate`. Без них не будет точек инструментации для метрик.
- **Iteration 4:** структура `DelegationRecord`, `DelegationManager`, базовые операции создания/ревокации делегаций. Необходима для счётчиков `delegations_issued_total`/`revoked_total` и watcher'а истечения.
- **Iteration 5:** семантика `valid_until_daa`, события `MasterDelegationExpired`, логика обработки истёкших делегаций через `EphemeralKeyEntry`. Watcher `DelegationExpiryWatcher` использует `valid_until_daa` для ранних предупреждений, но не дублирует логику фактического истечения из Iteration 5.
- **Iteration 6:** airgap‑протокол (`build_master_delegation_request`, `apply_master_delegation_response`). Метрики airgap‑флоу (`delegation_requests_total`, `delegation_responses_total`, `delegation_responses_failed_total`) инструментируют именно эти точки.
- **Iteration 7–9:** property‑тесты, консенсус‑интеграция, миграции. Iteration 10 добавляет телеметрию поверх уже стабилизированного функционала, но не требует их завершения для базовой реализации метрик/логов.

**Параллельная работа:** части Iteration 10 (например, структура `MasterMetrics` и helper'ы логирования) могут разрабатываться параллельно с Iteration 6–9, но финальная интеграция watcher'а и healthcheck'а должна происходить после стабилизации airgap‑протокола (Iteration 6).

### 11. Связи с документацией и внешними системами

#### 11.1. Обновляемые документы

- **`docs/plans/phase2/Phase2_MLDSA_master_key.md`:** добавить раздел "Iteration 10: Observability & Telemetry" с кратким резюме и ссылкой на этот план.
- **`docs/IMPLEMENTATION_STATUS.md`:** отметить Iteration 10 как "In Progress" → "Done", перечислить новые метрики и события.
- **`docs/TEST_COVERAGE_SUMMARY.md`:** добавить строки для тестов метрик (`MasterMetrics`, `DelegationExpiryWatcher`, healthcheck), указать покрытие по каждому счётчику из §2.8.
- **`docs/NETWORK_TESTING.md`:** расширить раздел "MLDSA Master Observability" с описанием:
  - рекомендованных дашбордов (Prometheus/Grafana или альтернативы);
  - порогов алертов и SLO;
  - интерпретации метрик в контексте безопасности (утечки, аномалии).
- **`docs/MIGRATION_STRATEGY.md`:** описать поведение метрик при миграции кошельков (старые версии не экспортируют `MasterMetrics`, новые — экспортируют; экспортёры должны быть обратно совместимы).

#### 11.2. Интеграция с инфраструктурой

- **Экспортёры метрик:** внешние системы (Prometheus exporter, OTLP collector) должны:
  - подписываться на `Events::Metrics` от кошелька;
  - маппить `MetricsUpdate::MasterMetrics` в целевой формат (Prometheus `/metrics`, OTLP spans/metrics);
  - добавлять label'ы `network`, `instance` (но **не** `master_anchor`/`account_id`).
- **Логирование:** централизованные системы (Elasticsearch, Grafana Loki) должны индексировать логи с тегом `master_anchor=<hex8>` для быстрого поиска по конкретному мастеру.
- **Алертинг:** настройка алертов в Prometheus Alertmanager или аналогах на основе порогов из §2.7, с уведомлениями в Slack/PagerDuty при превышении.

#### 11.3. API и версионирование

- **Wire‑формат `Events::Metrics`:** добавление `MetricsUpdate::MasterMetrics` требует bump'а версии API кошелька (например, в `WalletApi::version()` или отдельном `MetricsApiVersion`).
- **Обратная совместимость:** старые клиенты (CLI/WASM/JS SDK), не знающие о `MasterMetrics`, должны молча игнорировать этот variant или логировать предупреждение, но не падать при десериализации.
- **Документация API:** обновить OpenAPI/Swagger‑спецификации (если есть) и JS/WASM SDK‑документацию с описанием новых метрик и событий.

### 12. Заключение

Iteration 10 завершает Phase 2 добавлением **наблюдаемости и телеметрии** для MLDSA master и делегаций, не меняя сам протокол и криптографию. Основные результаты:

- **Метрики:** глобальные счётчики `wallet_master_*` для операций мастера, делегаций и airgap‑флоу, экспортируемые через стандартный канал `Events::Metrics`.
- **Уведомления:** событие `MasterDelegationExpiringSoon` и watcher `DelegationExpiryWatcher`, предупреждающие об истекающих делегациях до фактического истечения.
- **Логирование:** единообразный тег `master_anchor=<hex8>` во всех логах master‑операций, упрощающий поиск инцидентов.
- **Инфраструктура:** Docker‑образ с `ENABLE_MLDSA_MASTER=1`, healthcheck для airgap‑режима, документация для инфра‑команды по дашбордам и алертам.

Iteration 10 **не изменяет** семантику `valid_until_daa`, формат `DelegationRecord`, консенсус/валидацию транзакций и UX создания мастер‑аккаунтов — только добавляет поверх наблюдаемость. При сбоях телеметрии (отказ экспортёра, несовместимость версий) кошелёк продолжает работать штатно, деградируя только в наблюдаемости.

**Следующие шаги после Iteration 10:**
- Инфра‑команда настраивает дашборды и алерты на основе экспортируемых метрик.
- Мониторинг в проде (devnet/testnet/mainnet) для валидации порогов и тюнинга `warn_window_daa`.
- Итеративное улучшение наблюдаемости на основе реальных инцидентов и обратной связи операторов.

