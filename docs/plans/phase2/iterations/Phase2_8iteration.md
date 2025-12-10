# Phase 2 — Iteration 8: Развёртывание MLDSA Master Root и миграция

> Цель итерации: безопасно **включить** стек MLDSA master root (Master & Commander) в сетях QUBIC, синхронизировать документацию и чек‑листы, а также отрепетировать миграцию кошельков и нод так, чтобы ни один пользователь не потерял доступ к средствам и не «сломал» свой процесс бэкапов.

## 0. Контекст и границы итерации

- **Что уже готово (Iter.1–7):**
  - Реализован и задокументирован криптопримитив MLDSA (FIPS‑204) и его интеграция в адреса/tx (Phase 1).
  - Введён детерминированный MLDSA master (Iter.1), его хранение и шифрование в `PrvKeyData` + RPC/CLI/WASM API (Iter.2).
  - Спроектирован и частично реализован master‑аккаунт (`MldsaMasterAccount`), связь со stealth‑аккаунтами и делегациями (Iter.3–5).
  - Подготовлены airgap‑потоки и оффлайн‑подпись делегаций (Iter.6).
  - Расширен тестовый контур (unit/property/fuzz/integration) для проверки крипты, master‑аккаунтов и делегаций (Iter.7).
- **Что делаем в Iteration 8:**
  - Вводим **форк‑флаг** `enable_mldsa_master` на уровне консенсусных параметров (`Params`) и прокидываем его в RPC, чтобы кошельки/сервисы понимали, включён ли стек master root в конкретной сети и на каком DAA.
  - Обновляем стратегическую документацию и чек‑листы:
    - `docs/MIGRATION_STRATEGY.md` — отдельная глава по переходу к MLDSA master root.
    - `docs/FINAL_CHECKLIST.md` — пункты по master‑бэкапам, devnet/testnet rehearsal и регрессионным тестам кошелька/CLI.
    - `docs/PRIVACY_AND_QUANTUM_STRATEGY.md` — фиксируем факт активации Phase 2 и новую модель угроз.
  - Формализуем и репетируем сценарий обновления **узлов и кошельков** на devnet/testnet: порядок обновления, требования к бэкапам, rollback‑стратегия.
  - Готовим черновики релизных заметок и пользовательских инструкций.
- **Чего НЕ делаем в Iteration 8 (остаётся вне скопа):**
  - Не меняем криптографию (MLDSA/stealth) и формат on‑chain транзакций.
  - Не трогаем Kasplex L2 и внешние интеграции сверх того, что требуется для фиксации статуса в документации (это Iteration 9).
  - Не добавляем новые виды аккаунтов/адресов — только включаем уже реализованный стек master root.

**Критерий успеха:** сеть/кошельки имеют чётко определённый момент включения MLDSA master root, документация и чек‑листы отражают реальный процесс миграции, devnet/testnet rehearsal успешно отыгран, а для mainnet есть понятный план и rollback.

> Текущий статус (12.10.2025): кодовая часть активации выполнена — `Params` содержат `mldsa_master_activation` (mainnet=never, testnet=120_000_000, dev/sim=always), RPC отдаёт новые поля с поднятой ревизией, кошелёк уважает сетевой флаг и не автогенерирует master до активации. Добавлен строгий guardrail на overrides: если активация в прошлом или ближе буфера (`max(3 * merge_depth, DAA_сутки)`), RPC логирует ошибку один раз и принудительно отключает `mldsa_master_enabled`.

## 1. Область изменений и файлы

| Подсистема | Файлы | Изменения |
|-----------|-------|-----------|
| Консенсусные параметры | `consensus/core/src/config/params.rs`, `consensus/src/params.rs` | Добавление активации `mldsa_master_activation: ForkActivation` и helper‑метода `Params::mldsa_master_enabled(daa_score) -> bool`. Настройка значений для `MAINNET_PARAMS`, `TESTNET_PARAMS`, `DEVNET_PARAMS`, `SIMNET_PARAMS` и QUBIC‑специфичных `Params` (см. `QUBIC_PARAMS` в `docs/IMPLEMENTATION_PLAN.md` / `docs/MIGRATION_STRATEGY.md`). |
| RPC / Node Info | `rpc/core/src/model/message.rs`, `rpc/service/src/service.rs`, `rpc/core/src/wasm/message.rs`, `kaspa-wrpc-client/*` | Расширение server‑info API (`GetServerInfoResponse`) полями `mldsa_master_enabled` и, опционально, `mldsa_master_activation_daa`. Прокид флага из `Params` + текущего DAA, обновление wasm/TS/gRPC/wRPC слоёв и mock‑тестов. |
| Wallet core | `wallet/core/src/wallet/mod.rs`, `wallet/core/src/api/*`, `wallet/core/src/events.rs` | Связка локального флага `WalletSettings::EnableMldsaMaster` с сетевым флагом `mldsa_master_enabled`. Логирование/события при несовпадении ожиданий (кошелёк ждёт master, сеть ещё нет). |
| CLI / tooling | `cli/src/modules/wallet.rs`, `cli/src/modules/settings.rs`, `docs/TESTNET_DEPLOYMENT_GUIDE.md` | Команды/опции для проверки статуса `mldsa_master_enabled`, подсказки по миграции и бэкапам, обновление гайдов по деплою testnet/devnet. |
| Документация | `docs/MIGRATION_STRATEGY.md`, `docs/FINAL_CHECKLIST.md`, `docs/PRIVACY_AND_QUANTUM_STRATEGY.md`, `docs/IMPLEMENTATION_STATUS.md` | Новые разделы по Phase 2 (master root), чек‑листы миграции, статус Iteration 8. |
| Инфраструктура / CI | `.github/workflows/*`, `docker/Dockerfile.kaspa-wallet`, `docker-compose.test.yml` | Уточнение, что devnet/testnet с включённым master root входят в обязательный regression‑набор; при необходимости — env‑флаги для wallet (`ENABLE_MLDSA_MASTER`). |

## 2. Дизайн флага `enable_mldsa_master` и rollout‑политика

### 2.1. Семантика флага

- **`enable_mldsa_master` (семантически):**
  - `false` — сеть поддерживает MLDSA подписи и адреса (Phase 1), но **master root стек считается экспериментальным**; RPC может не экспортировать anchor/делегации, кошелёк должен рассматривать master‑функциональность как opt‑in/dev‑mode.
  - `true` — сеть официально поддерживает MLDSA master root:
    - В RPC гарантированно доступны методы работы с anchor/делегациями (см. Iter.4–5).
    - Документация и чек‑листы предписывают использовать master root как источник истины для восстановления.
    - Для новых кошельков/аккаунтов по умолчанию включён `WalletSettings::EnableMldsaMaster = true`.
- Флаг зависит от **DAA‑высоты** и хранится в консенсусных параметрах как активация `ForkActivation`, чтобы:
  - Иметь один источник правды для всех нод.
  - Обеспечить воспроизводимость devnet/testnet/mainnet сценариев.

### 2.2. Политика по сетям

- **Devnet:**  
  - `mldsa_master_activation = ForkActivation::always()` — master root включён с нулевой высоты и используется как playground.
- **Simnet:**  
  - `ForkActivation::always()` — обязательный e2e/интеграционный контур.
- **Testnet:**  
  - В коде Iteration 8 выставляем конкретное значение `ForkActivation::new(<DAA>)` и коммитим его вместе с планом; мердж без заполненного значения запрещён.  
  - Значение фиксируется в `MIGRATION_STRATEGY.md` и `TESTNET_DEPLOYMENT_GUIDE.md`, rehearsal обязателен.  
  - Если testnet стартует с нуля — DAA выбираем явно (можно `0` или буфер `N` блоков от генезиса), чтобы CI/доки совпадали.  
  - Если сохраняем историю — DAA обязан быть **в будущем** относительно текущего tip с буфером: `buffer_daa >= max(3 * expected_max_reorg_depth, DAA_сутки)`; проверяется на этапе конфигурации/CI.
- **Mainnet:**  
  - На момент Iteration 8: `ForkActivation::never()`.  
  - Поле остаётся в `Params`, но активация выполняется отдельным change request после успешного testnet rehearsal и обновления доков (см. §7.3).

### 2.3. Связь с кошельком и локальным флагом

- В кошельке уже есть локальный флаг `WalletSettings::EnableMldsaMaster` (см. `wallet/core/src/settings.rs` и `wallet/core/src/wallet/mod.rs::is_mldsa_master_enabled`).
- Для **автоматической генерации master‑записей** и фоновой миграции надо учитывать оба источника:
  - **Локально включено, сеть включена** → создаём/мигрируем master (нормальный production‑режим).
  - **Локально включено, сеть ещё не включена** →:
    - Разрешаем локальные операции (генерация master, экспорт seed/anchor),  
    - но отключаем любые RPC‑операции, которые зависят от сетевого флага (регистрация anchor, публикация делегаций и т.п.).
    - Логируем предупреждение и генерируем event `MasterNetworkDisabled`.
  - **Локально отключено, сеть включена** → кошелёк не создаёт master автоматически, но RPC‑методы работают; это поддерживает сценарий «legacy only» даже после активации.

### 2.4. Сценарии деградации и rollback

- Если после активации `enable_mldsa_master` обнаруживается критическая проблема:
  - На уровне консенсуса флаг изменить **назад** нельзя (fork‑решение), но:
    - можно выключить RPC‑эндпоинты anchor/делегаций через конфиг ноды (non‑consensus),  
    - в кошельке можно через настройки временно отключить auto‑master и делегации,
    - в MIGRATION_STRATEGY документируем «emergency mode»: работа как в Phase 1 (stealth без master).

### 2.5. Матрица акторов и сценариев

Для Iteration 8 важно явно разделять роли:

- **Оператор ноды (L1):**
  - Обновляет бинарники консенсуса/RPC.
  - Включает/валидирует `mldsa_master_activation` в конфигурации сети (devnet/testnet) и следит за метриками.
  - Не управляет кошельками пользователей напрямую, но отвечает за корректность RPC‑флагов (`GetServerInfo`).
- **Разработчик/оператор кошелька (L1/L2):**
  - Встраивает логику чтения `mldsa_master_enabled` и принятия решения, включать ли мастер‑режим по умолчанию (через `WalletSettings::EnableMldsaMaster`).
  - Обновляет CLI/GUI, чтобы пользователи видели состояние сети и понимали последствия включения master root.
- **Конечный пользователь:**
  - Обновляет кошелёк, создаёт/подтверждает master‑запись и anchor, выполняет бэкапы.
  - Может оставаться в legacy‑режиме (без master) даже после активации флага в сети.

В документе миграции (`MIGRATION_STRATEGY.md`) Iteration 8 должна привязать к каждому сценарию (devnet rehearsal, testnet upgrade, mainnet план) явные шаги для каждой роли.

## 3. Изменения в консенсусных параметрах (`Params`)

### 3.1. Структура параметров и активация

- В `consensus/core/src/config/params.rs`:
  - Добавить новое поле в `Params`:
    - `pub mldsa_master_activation: ForkActivation,`
  - В `OverrideParams` добавить опциональное поле:
    - `pub mldsa_master_activation: Option<ForkActivation>,`
  - В `impl From<Params> for OverrideParams` и `Params::override_params` пробросить это поле по аналогии с уже существующими (`crescendo_activation` и т.п.).
- Реализовать helper‑метод:
  - `pub fn mldsa_master_enabled(&self, daa_score: u64) -> bool`:
    - Внутри использовать `ForkedParam::new(false, true, self.mldsa_master_activation).get(daa_score)`.

### 3.2. Настройка по сетям

- В `MAINNET_PARAMS`, `TESTNET_PARAMS`, `DEVNET_PARAMS`, `SIMNET_PARAMS`:
  - Инициализировать `mldsa_master_activation`:
    - `SIMNET_PARAMS`: `ForkActivation::always()`.
    - `DEVNET_PARAMS`: `ForkActivation::always()` (для максимально простого devnet‑rehearsal).
    - `TESTNET_PARAMS`: `ForkActivation::never()` на момент начала Iteration 8; затем в ходе итерации заменить на конкретное значение и задокументировать его в `MIGRATION_STRATEGY.md` и `TESTNET_DEPLOYMENT_GUIDE.md`.
    - `MAINNET_PARAMS`: `ForkActivation::never()` до отдельного решения (см. раздел про mainnet rollout).
- Убедиться, что новое поле **не влияет** на существующую бизнес‑логику до тех пор, пока не будет использовано RPC/кошельком:
  - Нет прямых вызовов `mldsa_master_enabled` из консенсусного ядра (на этой итерации флаг используется только для информации и RPC).

### 3.3. Минимальные тесты для `Params`

- Unit‑тесты в `consensus/core`:
  - Проверка, что `ForkActivation::always()` → `mldsa_master_enabled(0) == true`.
  - Проверка, что `ForkActivation::never()` → всегда `false`.
  - Проверка, что кастомный `ForkActivation::new(X)` даёт `false` до X и `true` начиная с X.

### 3.4. OverrideParams и dev/test overrides

- В Iteration 8 важно, чтобы конфигурации devnet/testnet могли **переопределяться без пересборки**:
  - `OverrideParams` уже умеет менять множество полей (`mass_per_*`, `crescendo_activation`, и т.д.).
  - Добавление `mldsa_master_activation: Option<ForkActivation>` в `OverrideParams` позволяет задать кастомную высоту активации через конфиг/CLI без правки исходников.
- Требования:
  - В `Params::override_params` новый параметр должен обрабатываться по той же схеме, что и `crescendo_activation`:
    - `mldsa_master_activation: overrides.mldsa_master_activation.unwrap_or(self.mldsa_master_activation)`.
  - Документация должна описать, как операторы devnet/testnet могут временно сдвинуть активацию (например, для повторного rehearsal) через overrides.

## 4. RPC / Server Info: видимость флага для клиентов

### 4.1. Расширение API server‑info

- В `kaspa_rpc_core` (обычно `rpc/core/src/model/message.rs`):
  - Расширить структуру ответа `GetServerInfoResponse` полями:
    - `mldsa_master_enabled: bool`
    - `mldsa_master_activation_daa: Option<u64>` — DAA‑высота активации (для devnet может быть `Some(0)`, для `never` → `None`).
  - Обновить `Serializer/Deserializer`:
    - Версию поднять до **4**:
      - **v1** — поля до `virtual_daa_score`;
      - **v2** — добавлен `has_stealth_support`;
      - **v3** — добавлен `has_mldsa_master`;
      - **v4** — добавлены `mldsa_master_enabled` и `mldsa_master_activation_daa` в конце.
    - В десериализации:
      - при `version == 1` — читать только старые поля, а новые задать как `has_stealth_support = false`, `has_mldsa_master = false`, `mldsa_master_enabled = false`, `mldsa_master_activation_daa = None`;
      - при `version == 2` — считать `has_stealth_support`, остальные новые поля в значения по умолчанию;
      - при `version == 3` — считать `has_stealth_support`, `has_mldsa_master`, а поля master‑флага/DAA оставить по умолчанию;
      - при `version >= 4` — читать все поля по порядку.
  - Для JSON/serde:
    - добавить `#[serde(default)]` к `has_stealth_support`, `has_mldsa_master`, `mldsa_master_enabled`, `mldsa_master_activation_daa`, чтобы старые ноды не ломали новых клиентов и наоборот.
- В `rpc/service/src/service.rs`:
  - В хендлере `get_server_info_call` дополнительно подтянуть:
    - `let params = self.config.params;` (или эквивалентный доступ к `Params`);
    - использовать уже вычисленный `virtual_daa_score` как аргумент для helper‑метода:
      - `let enabled = params.mldsa_master_enabled(virtual_daa_score);`
      - `let activation = match params.mldsa_master_activation { ForkActivation::ALWAYS => Some(0), ForkActivation::NEVER => None, _ => Some(params.mldsa_master_activation.daa_score()), };`
  - Заполнить новые поля ответа.
- При расширении `GetServerInfoResponse` повышаем только `RPC_API_REVISION` (не `RPC_API_VERSION`), чтобы старые клиенты оставались совместимыми.

### 4.2. Клиентские библиотеки (wRPC/CLI)

- В `kaspa-wrpc-client`:
  - Обновить типы/IDL, чтобы `GetServerInfo` возвращал новые поля.
  - Добавить helper:
    - `fn is_mldsa_master_enabled(&self) -> bool` — читает флаг из последнего `get_info`.
- В CLI (`cli/src/modules/wallet.rs`):
  - Команда `wallet master list` / `wallet master export` должна:
    - При первом вызове проверять `mldsa_master_enabled` по RPC.
    - Если сеть `false`, но локальный `EnableMldsaMaster == true`, выводить явное предупреждение:
      - «Сеть ещё не активировала MLDSA master root; операции будут локальными, без регистрации anchor/делегаций».

### 4.3. Версионирование и совместимость RPC (тонкие моменты)

- **Два «инфо»-эндпоинта:** в коде уже есть `GetInfo` (старый, минимальный) и `GetServerInfo` (новый, расширяемый).  
  - Для master root используется **только** `GetServerInfo`, чтобы не плодить флаги в legacy‑методе.
- **Старые клиенты / ноды:**
  - Старые клиенты, не знающие про новые поля, игнорируют их благодаря serde‑`default` и версии `GetServerInfoResponse`.
  - Новые клиенты, работающие против старых нод:
    - по версии (`v1`/`v2`) понимают, что поля отсутствуют, и трактуют это как `mldsa_master_enabled = false`.
- **WASM/TS‑интерфейсы:**
  - В `rpc/core/src/wasm/message.rs` интерфейс `IGetServerInfoResponse` уже перечисляет поля:
    - нужно добавить `mldsaMasterEnabled: boolean` и `mldsaMasterActivationDaa?: bigint | null;`.
  - Генераторы `try_from!` для wasm‑обёрток должны маппить новые Rust‑поля в TS‑структуру и обратно, сохраняя обратную совместимость.

### 4.4. Инварианты между `has_stealth_support` и `mldsa_master_enabled`

- Master‑root функциональность опирается на уже включённые стелс‑адреса, поэтому на уровне RPC вводим инвариант:
  - если `mldsa_master_enabled == true`, то `has_stealth_support` **также обязан быть true**;
  - состояния вида `has_stealth_support == false && mldsa_master_enabled == true` считаются некорректной конфигурацией и должны:
    - либо вообще не возникать (за счёт правильной инициализации `Params`),
    - либо приводить к логированию ошибки/варнинга на стороне ноды.
- В `rpc/core/src/model/tests.rs` и/или отдельных unit‑тестах следует зафиксировать это правило:
  - мок‑ответ `GetServerInfoResponse::mock()` должен ставить `has_stealth_support = true` при `mldsa_master_enabled = true`.
  - дополнительные тесты могут проверять, что клиенты (wallet/CLI) не переходят в мастер‑режим, если `has_stealth_support == false`, даже при локально включённом флаге.

## 5. Wallet core: учёт сетевого флага и миграция существующих кошельков

### 5.1. Сетевой флаг в кошельке

- В `wallet/core/src/wallet/mod.rs`:
  - Добавить внутреннее кешированное состояние `mldsa_master_network_enabled: bool` (например, в `Inner` или как lazy‑функцию, читающую `get_info`).
  - Добавить метод:
    - `pub async fn is_mldsa_master_network_enabled(&self) -> Result<bool>`:
      - Делает `rpc_api().get_server_info()` и возвращает флаг (с кешированием и TTL, чтобы не спамить RPC).
- Обновить `is_mldsa_master_enabled()` так, чтобы он учитывал **локальный флаг** и, при необходимости, сетевой:
  - Вариант А (минимальный): `is_mldsa_master_enabled` остаётся чисто локальным, но все RPC‑зависимые операции дополнительно вызывают `is_mldsa_master_network_enabled`.
  - Вариант B (строгий): `is_mldsa_master_enabled` возвращает `local && network`; локальный флаг всё ещё полезен как «принудительное выключение».
  - Конкретный выбор зафиксировать в `MIGRATION_STRATEGY.md` (раздел про backward compatibility).

### 5.2. Поведение при открытии/создании кошелька

- В `Wallet::create_wallet_with_accounts` и `Wallet::import_with_mnemonic`:
  - Уже вызывается `maybe_create_mldsa_master_from_mnemonic`.
  - Для Iteration 8:
    - Если `is_mldsa_master_enabled()` (с учётом сетевого флага) возвращает `false`, не создавать master автоматически; вместо этого:
      - Либо предлагать пользователю включить его явным CLI‑флагом (`--enable-mldsa-master`),
      - Либо не трогать master вообще на pre‑Phase‑2 нодах.
- Для существующих кошельков:
  - При первом открытии после апдейта:
    - Проверить наличие master‑записей (`master_anchor_infos()`).
    - Если master отсутствует, но сеть уже активировала `enable_mldsa_master`:
      - Предложить создать master (через CLI wizard/GUI), явно проговорив последствия для бэкапов.

### 5.3. События и логирование

- В `wallet/core/src/events.rs` добавить события:
  - `MasterNetworkStatus { enabled: bool, activation_daa: Option<u64> }`
  - `MasterNetworkMismatch { local_enabled: bool, network_enabled: bool }`
- Генерировать их:
  - При первом подключении к RPC и при изменении статуса (например, reorg до/после активации).
  - При обнаружении несовпадения ожиданий (локально включен master, а сеть ещё нет).

### 5.4. Edge‑кейсы миграции кошельков (тонкие моменты)

- **Старые `PrvKeyData` с зашифрованным payload’ом:**
  - `hydrate_mldsa_masters()` в текущей реализации пропускает записи, где payload ещё зашифрован (нет доступа к mnemonic без доп. секрета).
  - План Iteration 8 должен учитывать, что:
    - для таких кошельков автоматическая гидратация мастера **невозможна** без участия пользователя;
    - минимальное требование — не пытаться «угадать» mnemonic, а явно просить пользователя пройти через CLI/GUI‑wizard.
- **«Долгая» жизнь seed vs master:**
  - Мастер‑записи (`PrvKeyDataVariant::MlDsaMaster`) уже создаются:
    - при `create_wallet_with_accounts`,
    - при `import_with_mnemonic`,
    - при мультисиг‑импорте (`import_multisig_with_mnemonic`),
    - при ручном `prv_key_data_create` (через `maybe_create_mldsa_master_from_mnemonic`).
  - Iteration 8 **не должна** менять детерминизм: derivation по‑прежнему использует `MlDsaKeypair::from_bip39_root_seed(root_seed, 0, MlDsaLevel::Level2)`.
- **UX‑аспект автогидратации:**
  - При первом `wallet open` после обновления:
    - если `master_anchor_infos()` пуст и сеть уже `mldsa_master_enabled == true`, кошелёк:
      - либо запускает wizard «создать master сейчас» (с явным предупреждением по бэкапам),
      - либо в безопасном режиме оставляет всё как есть и только показывает предупреждение/событие `MasterNetworkStatus`.
  - Это поведение должно быть синхронизировано с CLI (`wallet master list|enable|disable|export`) и документировано в `MIGRATION_STRATEGY.md`.

### 5.5. Связь CLI‑флага и сетевого статуса

- В `cli/src/modules/wallet.rs` уже есть команды:
  - `wallet master enable/disable` (управляет `WalletSettings::EnableMldsaMaster`).
  - `wallet master list/export/verify-anchor`.
- Iteration 8 должна:
  - Обновить `display_master_help`, чтобы он явно упоминал:
    - как проверить сетевой статус (`wallet status` или отдельная команда, если будет добавлена),
    - что `enable/disable` управляет **локальным** режимом работы мастер‑деривации, а не состоянием сети.
  - Добавить явное предупреждение в `set_master_flag`:
    - если сеть ещё не активировала master root, но пользователь включает auto‑master, CLI должен показать текст в духе:
      - «Ваша сеть ещё не включила MLDSA master root (см. getServerInfo). Master будет использоваться только локально».

### 5.6. Карта затрагиваемых модулей и тестов (для разработчика wallet)

- **Код:**
  - `wallet/core/src/wallet/mod.rs` — реализация `is_mldsa_master_enabled`, `is_mldsa_master_network_enabled`, `maybe_create_mldsa_master_from_mnemonic`, `hydrate_mldsa_masters`.
  - `wallet/core/src/events.rs` — новые события `MasterNetworkStatus`, `MasterNetworkMismatch`.
  - `wallet/core/src/tests/rpc_core_mock.rs` — мок RPC‑ответов, используемый в unit‑тестах кошелька; нужно обновить под новые поля `GetServerInfoResponse`.
- **Тесты:**
  - Набор тестов в `wallet/core/src/tests` должен проверять:
    - поведение при разных сочетаниях (`local_flag`, `network_flag`);
    - корректность реакции на mock‑ответы с `mldsa_master_enabled = false/true`;
    - отсутствие автогенерации master на сетях без включённого флага (если такова политика Iteration 8).

## 6. Документация и чек‑листы

### 6.1. `docs/MIGRATION_STRATEGY.md`

- Добавить новую главу **«Phase 2: MLDSA Master Root Migration»** со следующей структурой:
  - **Модель угроз и цели:**  
    - Объяснить, что Phase 2 не отключает Schnorr/старые адреса, а добавляет PQ‑master как «root of trust» для stealth/ephemeral ключей.
  - **Сценарии для операторов нод:**
    - Последовательность обновления:  
      1. Обновить ноду до версии с поддержкой `mldsa_master_activation`.  
      2. Дождаться активации на devnet/testnet, проверить метрики/логи.  
      3. Для mainnet — следовать отдельному объявлению с DAA‑высотой.
  - **Сценарии для разработчиков кошельков:**
    - Когда включать `WalletSettings::EnableMldsaMaster` по умолчанию.
    - Как обрабатывать сети, где `mldsa_master_enabled == false`.
  - **Сценарии для пользователей:**
    - Как проверить, что их кошелёк уже создал master и показал anchor.
    - Как правильно записать/сохранить master‑сид и anchor (ссылка на отдельный cold‑storage гайд).
  - **Rollback / Emergency‑mode:**
    - Описание шагов, если понадобится временно вернуться к «Phase 1‑only» UX.

### 6.2. `docs/FINAL_CHECKLIST.md`

- Добавить секцию **«Phase 2 — MLDSA Master Root»**:
  - **Code & Config:**
    - `[ ]` Все сети имеют заданный `mldsa_master_activation` (devnet/simnet — always, testnet/mainnet — документированные значения или `never` с планом).
    - `[ ]` RPC `get_info` возвращает флаг и DAA‑высоту, CLI умеет его показать.
  - **Wallet & UX:**
    - `[ ]` Master‑аккаунт/anchor корректно отображаются в CLI/GUI.
    - `[ ]` Есть явные предупреждения при экспорте master seed и при работе в сетях без активированного master root.
  - **Testing:**
    - `[ ]` Devnet rehearsal (описан ниже) выполнен и протоколирован.
    - `[ ]` Testnet rehearsal запущен, результаты задокументированы в `TESTNET_DEPLOYMENT_GUIDE.md`.
  - **Docs & Comms:**
    - `[ ]` Обновлены `MIGRATION_STRATEGY.md`, `PRIVACY_AND_QUANTUM_STRATEGY.md`, `IMPLEMENTATION_STATUS.md`.
    - `[ ]` Подготовлены release notes и user‑гайд по master root.

### 6.3. `docs/PRIVACY_AND_QUANTUM_STRATEGY.md`

- Обновить раздел **«Quantum Resistance: The "Master & Commander" Model»**:
  - Добавить подпункт «Status»:
    - Описать, что Phase 2 реализован и активируется через `enable_mldsa_master`.
    - Кратко указать, как пользователям понять, активирован ли master root в их сети (через CLI/RPC).
- Добавить ссылку на `docs/plans/phase2/Phase2_MLDSA_master_key.md` и новый раздел `Phase 2: MLDSA Master Root Migration` в `MIGRATION_STRATEGY.md`.

### 6.4. Обновление `docs/IMPLEMENTATION_STATUS.md`

- Добавить отдельный подпункт **«Phase 2 / Iteration 8 (Deployment & Migration)»**:
  - Краткое описание:
    - «Флаг `enable_mldsa_master` внедрён на уровне консенсуса и RPC; devnet/testnet rehearsal выполнен, mainnet‑план зафиксирован».
  - Ссылки:
    - на этот файл (`Phase2_8iteration.md`),
    - на обновлённые `MIGRATION_STRATEGY.md`, `FINAL_CHECKLIST.md`, `PRIVACY_AND_QUANTUM_STRATEGY.md`.
  - Статус:
    - In progress → Done, когда все чек‑листы из §9 выполнены.

## 7. Devnet/Testnet rehearsal и процедуры развёртывания

### 7.1. Devnet rehearsal

- Цель: проверить end‑to‑end сценарий активации master root в максимально контролируемой среде.
- Шаги:
  1. Собрать ноду и кошелёк из ветки с реализованным `mldsa_master_activation` и RPC‑флагом.
  2. Запустить devnet ноду (`kaspad --devnet`) и убедиться, что:
     - `get_info` возвращает `mldsa_master_enabled = true`.
     - DAA‑высота активации корректно отображается.
  3. С новым кошельком:
     - Создать кошелёк/аккаунт, убедиться, что master‑запись создаётся автоматически (если включен локальный флаг).
     - Создать stealth‑аккаунт, привязать к master, провести хотя бы одну транзакцию.
     - Проверить, что recovery из сид‑фразы восстанавливает anchor и баланс (Iter.7 сценарий).
  4. Задокументировать результаты в devnet‑отчёте (приложить к `FINAL_CHECKLIST.md` или отдельному файлу).

### 7.2. Testnet rehearsal

- Цель: отрепетировать обновление **живой** сети с существующими пользователями.
- Шаги:
  1. Выбрать и зафиксировать конкретный `testnet_mldsa_master_activation_daa` (в коде, `MIGRATION_STRATEGY.md`, `TESTNET_DEPLOYMENT_GUIDE.md`); без этого rehearsal и мердж запрещены.  
     - Если сеть перезапускается с сохранённой историей — DAA берём строго в будущем относительно текущего tip и с буфером `buffer_daa >= max(3 * expected_max_reorg_depth, DAA_сутки)`.  
     - Если сеть чистая — фиксируем DAA (0 или буфер от генезиса) и прогоняем rehearsal с этим значением.
  2. Обновить тестнет‑ноды и убедиться, что:
     - До активации `mldsa_master_enabled == false`, все RPC/кошельки ведут себя как в Phase 1.
     - После достижения DAA‑высоты флаг переключается на `true`.
  3. Сценарий кошелька:
     - До активации: создать кошелёк, провести несколько транзакций (legacy + MLDSA адреса, stealth).
     - После активации: обновить кошелёк, дать ему создать master, привязать stealth‑аккаунт, провести транзакцию, проверить recovery.
  4. Зафиксировать список найденных UX/технических проблем, обновить документацию.

### 7.3. Mainnet план (high‑level)

- В рамках Iteration 8:
  - Не включать master root на mainnet, но:
    - Задокументировать **критерии**, при которых это будет сделано (покрытие тестов, успешный testnet rehearsal, внешний аудит и т.п.).
    - Описать ожидаемый формат объявления (DAA‑высота, сроки, рекомендации по апдейту нод и кошельков).

### 7.4. Матрица сценариев обновления

- **Сценарий A: только нода обновлена (старый кошелёк):**
  - Нода уже знает про `mldsa_master_activation` и отдаёт флаг в `GetServerInfo`.
  - Старый кошелёк игнорирует дополнительные поля и продолжает работать в режиме Phase 1 (без master root).
  - Риск: нулевой, кроме отсутствия новых возможностей.
- **Сценарий B: только кошелёк обновлён (старая нода):**
  - `GetServerInfo` не содержит поля master, десериализация видит `mldsa_master_enabled = false`.
  - Кошелёк может:
    - создать локальный master (по желанию пользователя), но не должен пытаться регистрировать anchor/делегации через RPC;
    - показывать предупреждение, что сеть не поддерживает Phase 2.
- **Сценарий C: частично обновлённый кластер нод:**
  - До достижения DAA‑высоты все ноды должны иметь одинаковый `Params`, иначе возможен рассинхрон RPC‑флагов.
  - Iteration 8 требует:
    - rollout‑план для операторов (обновление всех нод до включения активации),
    - проверки через мониторинг (см. раздел 8) что `GetServerInfo` на всех публичных эндпоинтах возвращает одинаковое состояние.
- **Сценарий D: мульти‑устройство пользовательского кошелька:**
  - Один и тот же seed используется на нескольких устройствах (desktop/mobile).
  - План Iteration 8 для таких кейсов:
    - все устройства используют один и тот же anchor (детерминированная деривация из BIP39);
    - в MIGRATION_STRATEGY отдельно зафиксировать, что перед включением master root пользователь должен:
      - либо обновить все клиенты до версий с поддержкой Phase 2,
      - либо использовать master только на одном «каноническом» устройстве (air‑gapped), а остальные оставить в режиме Phase 1.

### 7.5. Порядок исполнения Iteration 8 (пошаговый pipeline)

Чтобы минимизировать риски, работы внутри итерации выполняются в жёстком порядке:

1. **Consensus / Params (off‑chain подготовка):**
   - добавить поле `mldsa_master_activation` в `Params`/`OverrideParams`, реализовать `mldsa_master_enabled` и unit‑тесты;
   - убедиться, что ни один из продакшн‑build’ов ещё не выставляет активацию (`never` для testnet/mainnet).
2. **RPC слой:**
   - расширить `GetServerInfoResponse` и `get_server_info_call`, обновить wasm/TS/gRPC/wRPC, привести в консистентное состояние все моки и примеры;
   - добавить тесты на совместимость версий (старые/новые ноды/клиенты).
3. **Wallet core + CLI:**
   - внедрить чтение флага, события и UX‑предупреждения;
   - обновить CLI‑команды `wallet master ...` и убедиться, что поведение полностью обратносуместимо до включения master root в сети.
4. **Docs / CI:**
   - обновить документацию (`MIGRATION_STRATEGY`, `FINAL_CHECKLIST`, `PRIVACY_AND_QUANTUM_STRATEGY`, `IMPLEMENTATION_STATUS`);
   - добавить/обновить CI‑job’ы, проверяющие флаг и базовый сценарий работы кошелька.
5. **Devnet → Testnet rehearsal:**
   - только после успешных smoke‑тестов и CI включать активацию сначала на devnet, затем на testnet согласно описанному сценарию.
6. **Mainnet план (отдельным решением):**
   - после успешного testnet rehearsal и апдейта доков выносить отдельное решение по высоте активации mainnet, не входящее в саму Iteration 8.

## 8. Инфраструктура и CI

- Обновить `.github/workflows/*`:
  - Добавить job, который запускает devnet/simnet ноду и проверяет, что `mldsa_master_enabled` совпадает с ожидаемым для данной сети.
  - Добавить smoke‑тест:
    - `cargo test -p kaspa-wallet-core` сценарий, который делает `get_info` и проверяет сетевое состояние master root.
- При необходимости:
  - В `docker/Dockerfile.kaspa-wallet` и `docker-compose.test.yml` добавить/задокументировать использование `ENABLE_MLDSA_MASTER`, если будет принято решение управлять локальным флагом через env (в противном случае — просто обновить доки, чтобы не было рассинхронизации с планом).

- Для regression‑матрицы Iteration 8:
  - Добавить отдельный workflow, который:
    - поднимает `kaspad` нужной сети,
    - запускает небольшой rust‑интеграционный тест, который:
      - вызывает `GetServerInfo`, читает `mldsa_master_enabled`/`mldsa_master_activation_daa`,
      - сверяет их с ожидаемыми значениями для данной сети/конфига,
      - создаёт и открывает кошелёк, проверяя, что поведение `maybe_create_mldsa_master_from_mnemonic` соответствует выбранной политике (см. §5.2/5.4).

## 9. Пошаговый план работ (чек‑лист Iteration 8)

1. **Consensus / Params**
   - [x] Добавить поле `mldsa_master_activation` в `Params` и `OverrideParams`.
   - [x] Реализовать `Params::mldsa_master_enabled(daa_score) -> bool`.
   - [x] Инициализировать активацию для `MAINNET_PARAMS`, `TESTNET_PARAMS`, `DEVNET_PARAMS`, `SIMNET_PARAMS` и (при необходимости) QUBIC‑специфичных `Params`.
   - [x] Добавить unit‑тесты для `mldsa_master_enabled` и корректной работы `OverrideParams` с новым полем.
   - [x] Для testnet закоммитить конкретный `mldsa_master_activation_daa`; PR без значения не мёржится.
   - [x] Добавить строгую валидацию/guardrails для overrides: запрещать DAA в прошлом или ближе, чем `buffer_daa` к текущему tip (при сохранённой истории), и явно задавать значение при чистом запуске; `buffer_daa >= max(3 * expected_max_reorg_depth, DAA_сутки)` (некорректные активации теперь глушатся на RPC: флаг master отключается и логируется ошибка).
2. **RPC / Server Info**
   - [x] Расширить ответ `get_server_info` (`GetServerInfoResponse`) флагом `mldsa_master_enabled` и DAA‑высотой.
   - [x] Обновить wRPC/GRPC клиенты и убедиться в совместимости со старыми клиентами.
   - [x] При необходимости поднять только `RPC_API_REVISION`, убедиться, что `RPC_API_VERSION` не меняется.
3. **Wallet core**
   - [x] Добавить чтение сетевого статуса master root и helper `is_mldsa_master_network_enabled`.
   - [x] Обновить автогенерацию master и hydration так, чтобы она корректно работала при различных сочетаниях локального/сетевого флагов.
   - [x] Добавить события `MasterNetworkStatus` и `MasterNetworkMismatch`.
4. **CLI / UX**
   - [x] Обновить CLI‑команды (`wallet master ...`, `wallet account ...`) для показа статуса master root.
   - [x] Добавить явные предупреждения при работе в сетях без активированного master root и зафиксировать связь локального флага (`EnableMldsaMaster`) с сетевым.
5. **Документация**
   - [x] Дописать раздел «Phase 2: MLDSA Master Root Migration» в `MIGRATION_STRATEGY.md`.
   - [x] Обновить `FINAL_CHECKLIST.md` и `PRIVACY_AND_QUANTUM_STRATEGY.md` согласно пунктам выше.
   - [x] Обновить `docs/IMPLEMENTATION_STATUS.md` (статус Iteration 8, ссылки на выполненные шаги).
6. **Devnet/Testnet rehearsal**
   - [x] Провести devnet rehearsal (создание master, привязка stealth, recovery) и задокументировать результат (см. `docs/TESTNET_DEPLOYMENT_GUIDE.md`, раздел rehearsal devnet).
   - [x] Зафиксировать `testnet_mldsa_master_activation_daa` в коде/доках, провести rehearsal и обновить `TESTNET_DEPLOYMENT_GUIDE.md`, включая обоснование выбранного `buffer_daa`.
7. **Release / Comms**
   - [x] Подготовить и согласовать черновик релизных заметок для Phase 2.
   - [x] Сформировать пользовательский гайд по master root (создание, бэкапы, восстановление) — см. `docs/guides/master_cold_storage.md`.

**Definition of Done (для Iteration 8):**
- Консенсусные параметры содержат флаг активации, для testnet закоммичено фактическое значение DAA, RPC и кошельки отражают состояние master root.
- Документация и чек‑листы обновлены, включают результаты devnet/testnet rehearsal, ссылки на артефакты (логи/отчёты) и зафиксированные guardrails с расчётом `buffer_daa` (чистый запуск vs сохранённая история).
- План mainnet‑активации и rollback‑стратегия зафиксированы и согласованы с командами консенсуса, кошелька и Kasplex.

## 10. Тонкие моменты и риски Iteration 8

1. **RPC API versioning и совместимость с UtxoProcessor.**  
   - `wallet/core/src/utxo/processor.rs::init_state_from_server` жёстко проверяет `rpc_api_version > RPC_API_VERSION` и в этом случае падает с ошибкой `Error::RpcApiVersion`.  
   - Добавление полей в `GetServerInfoResponse` для `mldsa_master_*` **не должно** менять `RPC_API_VERSION`, только (при необходимости) `RPC_API_REVISION`; иначе старые кошельки перестанут подключаться к новым нодам.  
   - В плане Iteration 8 это нужно явно зафиксировать: любые изменения семантики флагов/полей делаются через ревизию, а не через major bump.
2. **Деструктурирование `GetServerInfoResponse` в разных местах.**  
   - Помимо RPC‑слоя, `GetServerInfoResponse` деструктурируется в нескольких местах:
     - `wallet/core/src/utxo/processor.rs::init_state_from_server` (игнорирует `has_stealth_support`, но перечисляет все поля),
     - `rpc/core/src/model/tests.rs` (`Mock for GetServerInfoResponse`),
     - примеры (`rpc/wrpc/examples/simple_client/src/main.rs` и gRPC‑моки).  
   - В Iteration 8 при добавлении новых полей обязательно:
     - обновить все pattern‑matching/деструктуризации (желательно добавить `..` в примерах, чтобы уменьшить хрупкость),
     - обновить mock‑структуры и тесты, чтобы они заполняли новые поля консистентными значениями по умолчанию.
3. **Ложноположительный «enabled» из‑за mis‑config.**  
   - Если оператор ошибочно выставит `mldsa_master_activation` для devnet/testnet (или через `OverrideParams`) раньше, чем кошельки/интеграторы будут готовы, `GetServerInfo` начнёт возвращать `mldsa_master_enabled = true` и UI может преждевременно предлагать пользователям включать master.  
   - Митигация:
     - чётко описать в `MIGRATION_STRATEGY.md` допустимые значения и порядок включения флага;
     - в кошельке опираться не только на флаг, но и на локальные настройки/фиче‑флаги (например, не показывать wizard по master, пока не включены нужные build‑features).
4. **Реорги и «плавающий» `mldsa_master_enabled` на границе активации.**  
   - Поскольку `mldsa_master_enabled` зависит от `virtual_daa_score`, вблизи высоты активации при глубоких reorg теоретически возможно расхождение состояния (некоторые ноды уже считают master включённым, другие — ещё нет).  
   - Для Iteration 8 важно:
     - использовать достаточно «далёкую» активацию на testnet, чтобы к моменту DAA сеть была стабильно обновлена;
     - зафиксировать в кошельке правило: если при повторном `get_server_info` флаг «откатился» (был `true`, стал `false`), считать это аварийным сигналом и не проводить автоматических операций с master (только показать предупреждение).
5. **Мульти‑устройство и частичные обновления клиентов.**  
   - Если один клиент (desktop) уже умеет Phase 2 и создаёт master/anchor, а другой (старый мобильный) нет, то:
     - мастер‑аккаунт и делегации будут видны только на новом клиенте;
     - старыe клиенты, импортировав тот же сид, увидят только Phase 1 состояние (stealth без master).  
   - План Iteration 8 должен требовать от продуктивных приложений:
     - минимум — явное предупреждение при обнаружении, что сид использовался на устройствах с разными версиями (через события/логи);
     - желательно — рекомендацию пользователю выбрать «каноническое» устройство для master‑операций.
6. **Ошибки операторов при использовании OverrideParams.**  
   - Неправильное значение `mldsa_master_activation` в overrides (например, DAA в прошлом или слишком близко к текущему) может привести к резкому включению master root без rehearsal.  
   - В `MIGRATION_STRATEGY.md` Iteration 8 должна задать «guardrails»:
     - запрещать активацию «в прошлом» в конфигурационных инструментах (валидировать DAA),
     - для testnet — требовать, чтобы тестовый rehearsal выполнялся на другом окружении перед изменением боевого `override`.


