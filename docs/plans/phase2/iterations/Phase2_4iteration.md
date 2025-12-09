# Phase 2 — MLDSA master — Итерация 4: Делегации, RPC и сигнатуры

> Цель: ввести формальную **DelegationRecord** между оффлайн MLDSA‑master и стелс‑ветками, протащить делегацию до уровня транзакции (TLV в сигнатуре) и RPC, не ломая существующий stealth‑MVP и не меняя консенсусную семантику проверки подписи (Schnorr по P\_dest).

## 0. Контекст и ограничения

- Текущая реализация стелс‑аккаунта (`wallet/core/src/account/variants/stealth.rs`) уже:
  - генерирует/хранит `EphemeralKeyData` для каждого стелс‑UTXO;
  - автоскейнит через `get_utxos_by_script_version` и fallback по `get_block_view_tags`;
  - вообще не знает про MLDSA master и делегации.
- `EphemeralKeyData` (`wallet/core/src/storage/ephemeral_keys.rs`):
  - содержит только `spending_secret`, `blinding_factor`, `destination_pubkey`;
  - сериализуется через `BorshSerialize/BorshDeserialize` без явной версии → любое изменение полей без аккуратной миграции ломает существующие файлы.
- `StealthSigner` (`wallet/core/src/tx/generator/stealth_signer.rs`):
  - достаёт `EphemeralKeyData` по outpoint;
  - считает sighash через `calc_schnorr_signature_hash` и пишет в `signature_script` ровно `64B sig || 1B sighash_type` (65 байт).
- Консенсусный слой (`crypto/txscript/src/lib.rs` + `standard.rs`):
  - для `STEALTH_SCRIPT_VERSION=16` полностью обходит байткод и валидирует через `execute_stealth_spend` **без исполнения скрипта**;
  - ожидает `script_public_key.script().len() == STEALTH_OUTPUT_SIZE (=66)` и `signature_script.len() == 65` и не допускает префиксов;
  - `get_sig_op_count` и `get_sig_op_count_upper_bound` уже жёстко считают stealth‑вход как 1 sigop, не глядя на `signature_script` (даже если он станет длиннее).
- RPC (`rpc/core/src/api/rpc.rs`, `rpc/service/src/service.rs`):
  - уже даёт `get_utxos_by_script_version` и `get_block_view_tags`, но не знает ничего про `anchor` и делегации;
  - `GetServerInfoResponse` содержит только `has_stealth_support`, без флагов по MLDSA master.
- MLDSA‑мастер (`kaspa_mldsa`, `wallet/keys/src/keypair_mldsa.rs`, `wallet/core/src/storage/keydata/data.rs`):
  - `MlDsaLevel` задаёт размеры ключей/подписей (Level2: подпись 2420 байт);
  - `MlDsaKeypair::anchor()` даёт `MasterAnchor([u8;32])`, который уже хранится в `MlDsaMasterPayload` (`PrvKeyDataVariant::MlDsaMaster`);
  - `MlDsaMasterPayload` зашифрован, Borsh‑формат с `VERSION=0`, менять его в Итерации 4 нельзя — мы только читаем `anchor`/`level`.

**Вывод:** итерация 4 должна:
- ввести явную модель делегаций и их хранение в кошельке;
- расширить ephemeral‑ключи и сайнер так, чтобы они умели «нести» информацию о делегации;
- расширить `signature_script` стелс‑входов до формата `[TLV*][64B sig][1B sighash]` и научить консенсус принимать этот формат **под управляемым флагом активации**;
- добавить минимальный RPC‑слой вокруг anchor/delegation, не связывая его жёстко с консенсусом (миграция остаётся мягкой).

#### Δ Итоговые исправления/доделки, которые нужно выполнить
- Протокол делегаций: выровнять подпись/проверку — использовать единый `delegation_message_hash` без дополнительных префиксов (ни `tag`, ни `anchor`), доменное разделение реализовать через keyed BLAKE2b; привести кошелёк к этой схеме.
- Консенсус: приём `signature_script` длиной `>=65` для stealth-входов должен быть gated (используем существующий флаг `kip10_enabled` как переключатель Phase 2); при отключённом флаге оставлять строго `len == 65`.
- Кошелёк: флаг `EnableMldsaMaster` должен реально запрещать создание новых делегаций, если пользователь его выключил.
- TLV в консенсусе: в Iteration 4 TLV-префикс **полностью игнорируется**, разбор/использование откладываются; обновить описание.
- `has_mldsa_master` в `GetServerInfoResponse`: сейчас поле возвращается `false` — нужно либо вычислять по реальной поддержке, либо явно пометить как «заглушка».
- RPC `register_mldsa_anchor` / `list_mldsa_delegations`: сейчас `NotImplemented`; либо реализовать минимально (in-memory/пустой список), либо явно оставить статус «заглушка».
- Тесты: добавить отсутствующий интеграционный тест на end-to-end поток (master → delegation → TLV spend → восстановление).
- CLI/UX: скорректировать описание команд под фактические (`account delegation <link|list|revoke>`), либо переименовать код — в плане фиксируем текущий фактический API.

### 0.1. Область изменений и файлы (привязка к реальному коду)

| Подсистема | Файлы | Что меняем в Итерации 4 |
|-----------|-------|--------------------------|
| Модель делегаций | `wallet/core/src/account/delegation.rs` (новый), `wallet/core/src/account/variants/stealth.rs` | Ввод `DelegationRecord`, связь `StealthAccount` ↔ master anchor/делегация. |
| Хранение master | `wallet/core/src/storage/keydata/data.rs`, `wallet/keys/src/keypair_mldsa.rs` | Используем существующий `MlDsaMasterPayload`/`MasterAnchor`, не меняя формат, для проверки делегаций. |
| Ephemeral keys | `wallet/core/src/storage/ephemeral_keys.rs` | Обогащаем `EphemeralKeyEntry`/`EphemeralKeyData` метаданными делегации, не ломая `Encrypted<Vec<EphemeralKeyEntry>>`. |
| Generator/Signer | `wallet/core/src/tx/generator/settings.rs`, `.../generator.rs`, `.../pending.rs`, `.../stealth_signer.rs` | Прокидываем флаг TLV, добавляем сериализацию `[TLV delegation_id]` перед сигнатурой. |
| Consensus | `crypto/txscript/src/lib.rs` | Ослабляем проверку длины `signature_script` в `execute_stealth_spend`, парсим и игнорируем TLV‑префикс. |
| RPC ядро/сервис | `rpc/core/src/model/message.rs`, `rpc/core/src/api/rpc.rs`, `rpc/service/src/service.rs` | Базовые сообщения/методы для anchor/делегаций (wallet‑oriented, без консенсуса). |
| Wallet API / CLI / WASM | `wallet/core/src/api/message.rs`, `wallet/core/src/api/traits.rs`, `cli/src/modules/wallet.rs`, `wallet/core/src/wasm/api` | Команды/методы создания/списка/ревокации делегаций. |
| Документация/матрица | `docs/plans/phase2/Phase2_MLDSA_master_key.md`, `docs/IMPLEMENTATION_STATUS.md` | Синхронизация статуса и тестовой матрицы с фактическим дизайном. |

### 0.2. Границы итерации: что делаем / чего не делаем

- **Что уже есть к старту Iteration 4 (из итераций 0–3):**
  - MLDSA‑master: `MasterSeed`, `MasterAnchor`, хранение в `PrvKeyDataVariant::MlDsaMaster`, CLI/FFI/WASM для работы с мастером.
  - Stealth‑MVP: `StealthAccount`, `EphemeralKeyStore`, fallback‑сканер (`get_utxos_by_script_version` + `get_block_view_tags`), `execute_stealth_spend` с чистым Schnorr.
  - Базовый master‑аккаунт и привязка stealth ↔ master через `master_anchor` (итерация 3).
- **Что делаем в Iteration 4:**
  - Формализуем **делегации**: `DelegationRecordV1`, хранение и CRDT‑логика выбора активной записи.
  - Протаскиваем делегацию до **уровня сигнатуры** стелс‑входа (TLV c `delegation_id` в `signature_script`).
  - Добавляем минимальный **RPC‑слой** вокруг anchor/delegations + wallet‑API/CLI/WASM для UX (`link-stealth-to-master`, список/ревокация).
  - Обновляем **TxScript** для поддержки переменной длины `signature_script` у stealth‑входов **без изменения проверки Schnorr**.
- **Чего НЕ делаем в Iteration 4 (сознательно откладываем):**
  - Не меняем **формат ScriptPublicKey** stealth‑адресов и не записываем anchor/делегацию ончейн.
  - Не меняем **количество sigops** (по‑прежнему 1 sigop на stealth‑вход, независимо от длины `signature_script`).
  - Не реализуем сканер/orphaned‑UTXO, DAA‑чистку и `anchor_hint` — это зона Iteration 5.
  - Не реализуем air‑gap UX и CRDT‑синхронизацию делегаций между устройствами — это Iteration 6+.
  - Не встраиваем проверку TLV в консенсус (TxScript игнорирует TLV, валидирует только Schnorr по P\_dest; семантика делегации остаётся на стороне кошелька).
  - Не привязываем поведение к Kasplex/внешним L2 — в этой итерации только L1‑RPC и кошелёк.

## 1. Формат DelegationRecord и хеширование

### 1.1. Структура и типы

Создать новый модуль `wallet/core/src/account/delegation.rs` с базовой моделью:

- `DelegationId(u64)` — внутренняя идентичность делегации (локальный счётчик/nonce).
- `DelegationStatus`:
  - `Active`,
  - `Revoked { revoked_daa: u64 }`,
  - `Expired { expired_daa: u64 }`.
- `DelegationRecordV1` (borsh + serde, wire‑формат для хранения и RPC):
  - `version: u8` (=1);
  - `level: u8` — MLDSA security level (`MlDsaLevel` как `u8`, по факту сейчас всегда `Level2`);
  - `anchor: [u8; 32]` — `MasterAnchor`;
  - `account_id: AccountId` — стелс‑аккаунт, на который делегируется;
  - `spend_pubkey: [u8; 32]` — x‑only spend;
  - `scan_pubkey: [u8; 32]` — x‑only scan;
  - `valid_from_daa: u64`;
  - `valid_until_daa: Option<u64>`;
  - `nonce: u64` — monotonic per `(anchor, account_id)` (CRDT‑слой);
  - `status: DelegationStatus`;
  - `signature: Vec<u8>` — MLDSA‑подпись с длиной `MlDsaLevel::signature_len()` для соответствующего `level` (на практике 2420 байт для Level2).

Требования:
- **Иммутабельность:** любые изменения статуса должны порождать новый `DelegationRecordV1` с `nonce+1`, старая запись остаётся только в истории.
- **Размер:** MLDSA подпись ~2.4 KB, полный Borsh‑пакет ≈ 2.7–3 KB → учитывать при RPC/FFI (особенно в WASM).

### 1.2. Хеширование и подпись мастером

- Доменные строки:
  - `DOMAIN_MLDSA_DELEGATION = "kaspa.mldsa.delegation.v1"`;
  - `DOMAIN_MLDSA_DELEGATION_REVOKE = "kaspa.mldsa.delegation.revoke.v1"`.
- `fn delegation_message_hash(record: &DelegationRecordV1) -> [u8; 32]`:
  - сериализация всех полей, кроме `signature`;
  - `blake2b-256` **с ключом** `DOMAIN_MLDSA_DELEGATION` (keyed режим вместо конкатенации домена).
- Подпись мастером (канон для Iteration 4):
  - сообщение для подписи = `delegation_message_hash(record)` без дополнительных префиксов `tag || anchor` (домены уже учтены ключом хеша);
  - `sign_with_master(master_key, record)` валидирует длину подписи и записывает её в `signature`;
  - `verify_against_anchor(anchor, master_pubkey, record)` проверяет совпадение `record.anchor` и валидирует подпись тем же сообщением.
- Для CRDT:
  - сравнение по `(nonce, valid_from_daa, valid_until_daa)` с приоритетом `nonce`;
  - helper `fn select_active(records: &[DelegationRecordV1]) -> Option<&DelegationRecordV1>` — возвращает последнюю не `Revoked/Expired` по `nonce`.

### 1.3. Инварианты делегаций

- **Единый уровень безопасности:** для фиксированной пары `(anchor, account_id)` все `DelegationRecordV1` должны иметь одинаковый `level`; смешивать Level2/Level3/Level5 для одного anchor нельзя.
- **Монотонность `nonce`:** кошелёк никогда не создаёт запись с `nonce <= max_nonce` для данного `(anchor, account_id)`:
  - `DelegationStore::upsert` защищает это инвариантом;
  - CRDT‑merge в будущем (итерации 6+) опирается именно на `nonce`.
- **Монотонность статуса:** `status` может двигаться только в сторону «менее активных» состояний:
  - `Active → Revoked` или `Active → Expired`, но не обратно;
  - повторная активация оформляется как новый `DelegationRecordV1` с `nonce+1`.
- **DAA‑окно:** для любой записи:
  - `valid_from_daa <= valid_until_daa` (если `valid_until_daa.is_some()`), проверяется при создании;
  - кошелёк использует для UTXO только те делегации, где `utxo.block_daa_score` попадает в `[valid_from_daa; valid_until_daa]` (или без верхней границы).
- **Привязка к аккаунту:** `record.account_id` указывает именно на `StealthAccount`, и при линке/загрузке мы жёстко проверяем:
  - `(scan_pubkey, spend_pubkey)` в `DelegationRecordV1` совпадают с тем, что записано в `Payload` аккаунта;
  - тем самым исключаем ситуации, когда anchor делегирован на «другой» stealth с теми же ключами.

## 2. Связь делегаций со стелс‑аккаунтом и стореджем

### 2.1. Payload стелс‑аккаунта и миграция

Предпосылка итерации 3 (фиксируем здесь, чтобы не потерять контекст разработки):

- `wallet/core/src/account/variants/stealth.rs::Payload` расширяется до:
  - базовая часть (как сейчас):
    - `account_index: u64`,
    - `scan_pubkey: Vec<u8>`,
    - `spend_pubkey: Vec<u8>`,
    - `creation_daa_score: Option<u64>`,
  - новые поля:
    - `master_anchor: Option<[u8; 32]>` — `MasterAnchor` привязанного MLDSA‑мастера;
    - `delegation_id: Option<u64>` — локальный `DelegationId` активной делегации (если есть).
- `StorageHeader::STORAGE_VERSION` для `Payload` повышается с `0` до `1`,
  - `BorshDeserialize::deserialize_reader` обновляется по паттерну, уже используемому в других стореджах:
    - читаем `StorageHeader`, принимаем **обе** версии: `0` и `1`;
    - при `version == 0` десериализуем только старые поля и заполняем `master_anchor=None`, `delegation_id=None`;
    - при `version == 1` читаем полный набор полей, проверяя длины pubkey (как сейчас).

План для итерации 4:

- В `StealthAccount` (runtime‑структура) добавить:
  - `master_anchor: Option<[u8; 32]>`,
  - `active_delegation_id: Option<DelegationId>`.
- В `try_new` и `try_load`:
  - пробрасывать `master_anchor` и `delegation_id` из `Payload`;
  - если `delegation_id` есть, при инициализации подтягивать `DelegationRecord` из нового стораджа делегаций (см. ниже) и валидировать:
    - `record.anchor == master_anchor`;
    - `record.account_id == self.id()`;
    - `record.status == Active` и `daa` в `[valid_from; valid_until]` (если задан).

### 2.2. Хранение делегаций в `wallet/core/src/storage`

- Вводим хранилище `DelegationStore`:
  - реализовать либо как отдельный файл в `wallet/core/src/storage/local/` (например `delegations.rs`),
  - либо как разновидность `transaction::record`, но с другим `kind`.
- Формат на диске:
  - префикс `STORAGE_MAGIC = "DLGT"` + `STORAGE_VERSION = 0`;
  - коллекция `(DelegationId, DelegationRecordV1)` журналом;
  - индекс по `(anchor, account_id)` в памяти (DashMap).
- Операции:
  - `fn upsert(record: DelegationRecordV1) -> DelegationId`:
    - находит максимальный `nonce` для `(anchor, account_id)`, проверяет `record.nonce == prev_nonce+1`;
    - присваивает/перезаписывает локальный `DelegationId` (u64);
  - `fn by_id(id: DelegationId) -> Option<DelegationRecordV1>`;
  - `fn by_anchor(anchor: &[u8; 32]) -> Vec<(DelegationId, DelegationRecordV1)>`;
  - `fn active_for_account(anchor, account_id) -> Option<(DelegationId, DelegationRecordV1)>`.

### 2.3. API кошелька вокруг делегаций

В `wallet/core/src/wallet/mod.rs`:

- API верхнего уровня:
  - `async fn link_stealth_to_master(&self, stealth_id: AccountId, master_anchor: [u8;32], window_daa: u64, valid_for_daa: Option<u64>) -> Result<DelegationId>`;
  - `async fn list_delegations_for_master(&self, master_anchor: [u8; 32]) -> Result<Vec<DelegationRecordV1>>`;
  - `async fn revoke_delegation(&self, delegation_id: DelegationId) -> Result<()>`.
- Поток `link_stealth_to_master`:
  1. Проверить `WalletSettings::EnableMldsaMaster`; если флаг выключен — вернуть ошибку и не создавать делегацию.
  2. Найти `StealthAccount` по `stealth_id`, убедиться, что он привязан к `master_anchor` (из `Payload` итерации 3).
  3. Считать `scan_pubkey`/`spend_pubkey`, `account_id`, текущий `virtual_daa_score`.
  4. Собрать `DelegationRecordV1` без подписи, выставить `valid_from_daa = current_daa`, `valid_until_daa = current_daa + valid_for_daa` (если задано).
  5. Сформировать `delegation_message_hash`, передать в мастер‑аккаунт (итерация 3) или напрямую в `PrvKeyDataVariant::MlDsaMaster` для подписи.
  6. Сохранить делегацию в `DelegationStore`, обновить `StealthAccount::Payload.master_anchor`/`delegation_id`.

### 2.4. Миграция существующих кошельков и UX

- **Старые стелс‑аккаунты (до Phase 2):**
  - при первом запуске нового кошелька их `Payload` читается как v0 → `master_anchor=None`, `delegation_id=None`;
  - поведение полностью совпадает с текущим stealth‑MVP: никаких делегаций, TLV не формируется, `signature_script` остаётся 65 байт.
- **Подключение мастера к существующему stealth:**
  - пользователь создаёт `MldsaMasterAccount` (итерация 3), затем вызывает `link-stealth-to-master`;
  - `Payload` этого stealth‑аккаунта мигрирует до v1 и получает `master_anchor`/`delegation_id`;
  - новые UTXO и stealth‑change под этим аккаунтом получают метаданные делегации, а `StealthSigner` может включать TLV.
- **Сосуществование делегированных и «обычных» UTXO:**
  - кошелёк обязан уметь работать в смешанном режиме:
    - часть UTXO под стелс‑аккаунтом не имеет делегации (`delegation_id=None`) → подписываются по старому формату;
    - часть UTXO — уже с делегацией → для них можно (и по умолчанию нужно) включать TLV.
  - генератор транзакций не должен «ломаться», если входы без делегации и с делегацией смешаны в одной транзакции.
- **Откат/отключение master‑режима:**
  - удаление master‑аккаунта или временное отключение `EnableMldsaMaster` в настройках кошелька:
    - не меняет ончейн‑формат UTXO;
    - кошелёк может продолжать тратить старые UTXO без TLV (или с TLV, если делегации ещё валидны);
    - любые новые делегации в этом состоянии создавать нельзя (UI/CLI должен блокировать сценарий; нужно добавить явную проверку в кошелёк).

### 2.5. Связь с `MldsaMasterAccount` (Iter.3)

- Поле `delegations: Vec<DelegationId>` в `MldsaMasterAccountPayloadV1` (Iter.3) в Iteration 4 начинает использоваться как лёгкий индекс:
  - при успешном `DelegationStore::upsert` кошелёк:
    - получает `DelegationId`;
    - добавляет его в `delegations` соответствующего `MldsaMasterAccount` (если там его ещё нет);
    - сохраняет обновлённый payload master‑аккаунта.
- Каноничным источником данных по делегациям остаётся `DelegationStore`; `delegations` в master‑аккаунте — это удобный список ссылок для UX и фоновых задач (watcher истечения, отчёты).
- При ревокации делегации (смена `DelegationStatus` на `Revoked/Expired`) запись в `DelegationStore` создаётся с новым `nonce`, а в master‑payload можно:
  - либо оставить `DelegationId` в списке (читатели всегда смотрят в `DelegationStore::active_for_account` и не перепутают статус);
  - либо (опционально) поддерживать отдельное поле «активных» делегаций — это может быть реализовано позже, в Iteration 5/7.

## 3. EphemeralKeyData и сайнер: проверка делегации и TLV

### 3.1. Расширение EphemeralKeyData и миграция стораджа

Требования:
- у каждого эпhemeral‑ключа должна быть привязка к делегации (через anchor и `DelegationId`), чтобы:
  - проверять, что spend‑ключ получен из делегированной ветки;
  - записывать `delegation_id` в TLV при подписи.

План по storage‑совместимости:

- **Не меняем** формат `Encrypted<Vec<EphemeralKeyEntry>>` в `EphemeralKeyStore::save_to_storage` — он остаётся тем же контейнером, расшифровка идёт одним вызовом `Encrypted::decrypt::<Vec<EphemeralKeyEntry>>()`.
- Расширяем `EphemeralKeyEntry` новыми полями (в том же файле `ephemeral_keys.rs`):
  - `#[borsh(default)] pub master_anchor: Option<[u8; 32]>`,
  - `#[borsh(default)] pub delegation_id: Option<u64>`.
- Для надёжности миграции:
  - если авто‑деривация Borsh с `#[borsh(default)]` не покрывает кейс «старые записи без полей» (при реализации видно по тестам), заменить derive на ручной `BorshDeserialize` по паттерну:
    - читаем старые поля `outpoint`, `data`, `status` как сейчас;
    - пробуем дочитать `master_anchor`/`delegation_id`, а при `UnexpectedEof` заполняем их как `None`;
    - сериализация всегда пишет полный новый формат.
- В `EphemeralKeyData` **не кладём** делегацию (ключ остаётся «чистой» криптографией), метаданные делегации живут на уровне entry (`master_anchor` + `delegation_id`), что проще мигрировать и обнулять и хорошо стыкуется с планом Iteration 5 (там добавятся `valid_until_daa`, расширенный статус и очистка).

### 3.2. Заполнение делегации в EphemeralKeyData

- В `StealthAccount::try_claim_utxo_internal`:
  - после успешного `EphemeralKeyData::new_xonly(...)` и до `EphemeralKeyStore::store`:
    - если у аккаунта есть `master_anchor` и активная делегация `DelegationRecordV1`:
      - проверяем, что `(scan_pubkey, spend_pubkey)` совпадают с делегацией (защита от случайного anchor‑mismatch);
      - передаём в `EphemeralKeyStore::store` не только `daa_score`, но и `master_anchor`/`delegation_id`, чтобы store мог заполнить новые поля `EphemeralKeyEntry`;
    - если делегации нет — оставляем `master_anchor = None`, `delegation_id = None` (кошелёк трактует такие UTXO как «не делегированные»).
- В `StealthAccount::finalize_stealth_change`:
  - аналогично помечать `EphemeralKeyEntry` делегацией, если стелс‑аккаунт привязан к мастеру, чтобы стелс‑change сразу получал `delegation_id`.
- В `StealthUtxoHandler::handle_utxo_removed` изменений не требуется, но в дальнейшем (итерация 5) можно использовать `delegation_id` для детекта orphaned‑веток.

### 3.3. Генератор и StealthSigner: включение TLV и проверка делегаций

- В `wallet/core/src/tx/generator/settings.rs`:
  - добавить флаг `pub include_delegation_id: bool` (по умолчанию `false`);
  - конструкторы `try_new_with_*` заполняют его из параметра или `WalletSettings` (например `WalletSettings::IncludeDelegationIdInStealthSigs`, дефолт `true`).
- В `wallet/core/src/tx/generator/generator.rs::Inner`:
  - добавить поле `include_delegation_id: bool` и геттер `fn include_delegation_id(&self) -> bool`.
- В `PendingTransaction::try_new` / `PendingTransactionInner`:
  - добавлять флаг `include_delegation_id` или просто прокидывать доступ к `generator.include_delegation_id()`.
- В `StealthSigner`:
  - изменить сигнатуру `pub async fn sign(&self, tx: SignableTransaction, include_delegation_id: bool) -> Result<Signed>`;
  - в `PendingTransaction::try_sign_stealth` вызывать:
    - `let include = self.inner.generator.include_delegation_id();`
    - `let signed = signer.sign(signable_tx, include).await?;`.
- Внутри `StealthSigner::sign` для каждого stealth‑входа:
  1. Получить `EphemeralKeyData` и проверить:
     - `EphemeralKeyStore` на базе новых полей `EphemeralKeyEntry` должен уметь отдавать не только `EphemeralKeyData`, но и привязанный `delegation_id` (либо через отдельный API, либо через мапу outpoint → delegation);
     - логика соответствия `anchor`/`account_id` уже проверена при заполнении entry, здесь достаточно доверять `delegation_id`, если он есть.
  2. Если `include_delegation_id` и `key_data.delegation_id().is_some()`:
     - сформировать TLV префикс:
       - `tag = 0xA1`,
       - payload = `delegation_id` в LE (`u64`),
       - итог байтстрима: `prefix = [0xA1, <8 байт id>]` (9 байт, без length‑байта).
  3. Сигнатура:
     - как и сейчас: 64 байта Schnorr + 1 байт `SigHashType`.
  4. `signature_script`:
     - без TLV: `sig || hash_type` (как сейчас);
     - с TLV: `0xA1 || id_le_u64 || sig || hash_type`.

**Тонкий момент по совместимости:** `StealthSigner` сегодня знает только про `EphemeralKeyProvider::get_ephemeral_key(outpoint) -> EphemeralKeyData`. В реализации нужно будет либо:
- расширить провайдер до `get_ephemeral_entry(...)` (с делегацией) и обернуть старый метод, чтобы не сломать существующие тесты/моки,  
либо
- держать в `StealthSigner` дополнительную ссылку на карту `outpoint → delegation_id`, которую заполняет стелс‑аккаунт на этапе скана.  
План фиксирует требование: TLV строится **на основе привязки outpoint к DelegationId**, а не по каким‑то глобальным настройкам.

### 3.4. Поведение без делегации и при ротации делегаций

- **UTXO без делегации:**
  - `EphemeralKeyEntry.delegation_id == None` → `StealthSigner` всегда формирует «старый» `signature_script` длиной 65 байт;
  - это гарантирует полную обратную совместимость с уже существующими кошельками/узлами (при отключённом master‑флаге).
- **Ротация делегации (несколько DelegationRecord для одного аккаунта):**
  - `DelegationStore::active_for_account` возвращает только одну запись (`DelegationRecordV1` с максимальным `nonce` и активным статусом);
  - новые UTXO/stealth‑change помечаются именно этой делегацией;
  - старые UTXO, попавшие под более раннюю делегацию, продолжают ссылаться на свой `delegation_id` в `EphemeralKeyEntry` — TLV всегда отражает «ту» делегацию, под которую был получен UTXO.
- **Ревокация/истечение делегации:**
  - смена статуса (`Active → Revoked/Expired`) оформляется новой записью с `nonce+1`;
  - это **не** делает уже потраченные подписи недействительными, так как консенсус игнорирует TLV и проверяет только Schnorr;
  - кошелёк, увидев неактивную делегацию, перестаёт помечать новые UTXO как «делегированные», но всё, что уже лежит в `EphemeralKeyStore`, остаётся тратоспособным (это важно для recovery).

## 4. Изменения в консенсусе: поддержка TLV в execute_stealth_spend

### 4.1. Новый формат signature_script

- Разрешить следующие варианты **только после активации фазы** (используем уже имеющийся флаг `kip10_enabled` как переключатель Phase 2):
  - **старый** (до активации): `len == 65` → только `sig || sighash_type`;
  - **новый** (после активации): `len >= 65` и `len <= MAX_SCRIPT_ELEMENT_SIZE`:
    - хвостовые 65 байт трактуются как сейчас (сигнатура + sighash);
    - префикс `[0 .. len-65)` рассматривается как TLV‑поток.
- Для совместимости: если префикс не содержит TLV, консенсус **не обязан** его интерпретировать, но должен принять транзакцию.

### 4.2. Реализация в `TxScriptEngine::execute_stealth_spend`

Пошаговый план:

1. Вместо жёсткой проверки `if sig_script.len() != 65`:
   - проверять `if sig_script.len() < 65 { Err(TxScriptError::SigLength(sig_script.len())) }`.
2. Ввести `let sig_offset = sig_script.len() - 65;`:
   - `let tlv_bytes = &sig_script[..sig_offset];`
   - `let sig_bytes = &sig_script[sig_offset..sig_offset+64];`
   - `let hash_type_byte = sig_script[sig_offset+64];`.
3. TLV-префикс в Iteration 4 **полностью игнорируется** (кроме учёта длины): консенсус не парсит и не использует содержимое; разбор можно добавить в будущих итерациях.
4. Остальной код (парс `SigHashType`, `Signature`, проверка через `calc_schnorr_signature_hash`) оставить без изменений.
5. Тесты:
   - дополнить `crypto/txscript/tests/stealth_transactions.rs` кейсами:
     - `signature_script` длиной 65 (старый формат) → проходит;
     - `signature_script` длиной 74 (TLV A1 + id + sig + hash) → проходит;
     - `signature_script` с `len < 65` → `SigLength` как раньше;
     - TLV с неизвестным tag (`0xA2`) → транзакция всё равно валидна.

Важно: `get_sig_op_count` и `get_sig_op_count_upper_bound` уже шорткатят stealth‑входы по `script_public_key.version() == STEALTH_SCRIPT_VERSION`, поэтому увеличение `signature_script.len()` за счёт TLV **не влияет** на лимиты sigops и не требует отдельной миграции по KIP‑10.

Активация: новая логика `len >= 65` действует только при `kip10_enabled = true`. При `kip10_enabled = false` сохраняется строгое правило `len == 65`.

## 5. RPC и сервисы: anchor/delegation API

### 5.1. Модель RPC в `kaspa_rpc_core`

В `rpc/core/src/model/message.rs` добавить:

- Типы:
  - `RegisterMldsaAnchorRequest { anchor: [u8;32], metadata: Option<String> }`;
  - `RegisterMldsaAnchorResponse { accepted: bool }`;
  - `ListMldsaDelegationsRequest { anchor: [u8;32] }`;
  - `ListMldsaDelegationsResponse { delegations: Vec<RpcDelegationRecord> }`.
- `RpcDelegationRecord` — wire‑представление `DelegationRecordV1`:
  - те же поля, но подпись в `Vec<u8>` и `status` в виде `String`/enum.
- `GetServerInfoResponse`:
  - добавить/задокументировать `has_mldsa_master: bool` как отражение фактической поддержки (или явно отметить, что пока возвращается `false`/`NotImplemented` для мягкой миграции).

В `rpc/core/src/api/rpc.rs`:

- расширить trait `RpcApi`:
  - `async fn register_mldsa_anchor_call(&self, connection: Option<&DynRpcConnection>, request: RegisterMldsaAnchorRequest) -> RpcResult<RegisterMldsaAnchorResponse>;`
  - `async fn list_mldsa_delegations_call(&self, connection: Option<&DynRpcConnection>, request: ListMldsaDelegationsRequest) -> RpcResult<ListMldsaDelegationsResponse>;`
- Удобные шорткаты:
  - `async fn register_mldsa_anchor(&self, anchor: [u8;32]) -> RpcResult<bool>;`
  - `async fn list_mldsa_delegations(&self, anchor: [u8;32]) -> RpcResult<Vec<RpcDelegationRecord>>;`.

### 5.2. Реализация в `rpc/service/src/service.rs`

- В `RpcCoreService`:
  - для `register_mldsa_anchor_call` / `list_mldsa_delegations_call`:
    - текущий статус: `RpcError::NotImplemented`;
    - минимальная цель Iteration 4: либо вернуть заглушки (in‑memory anchor-set / пустой список) без консенсусной логики, либо явно задокументировать `NotImplemented` для мягкой миграции.
- Обновить mock‑реализацию `wallet/core/src/tests/rpc_core_mock.rs`:
  - возвращать `Err(RpcError::NotImplemented)` для новых методов → тесты кошелька не падают.

### 5.3. wRPC/gRPC и клиентские библиотеки

- После расширения `kaspa_rpc_core` и `rpc/service` новые методы нужно протащить через существующие транспорты:
  - в `rpc/grpc/*`:
    - добавить `RegisterMldsaAnchor{Request,Response}` и `ListMldsaDelegations{Request,Response}` в protobuf/IDL;
    - расширить сервисы и сгенерированные клиенты так же, как это делается для других wallet‑ориентированных методов;
  - в `rpc/wrpc/*` и `rpc/wrpc/macros/*`:
    - описать новые сообщения/методы и добавить соответствующие макросы/обработчики.
- На стороне Rust‑клиентов (`kaspa-wrpc-client`, gRPC‑клиенты) этой итерацией достаточно:
  - объявить типы/методы, прокидывающие параметры один в один из `kaspa_rpc_core`;
  - не навязывать никакой специфической логики делегаций (она остаётся в кошельке и в Kasplex‑части Iteration 9).

## 6. Wallet API / CLI / WASM

### 6.1. Wallet API (Rust)

В `wallet/core/src/api/traits.rs` и `wallet/core/src/api/message.rs`:

- Сообщения:
  - `DelegationCreateRequest { wallet_secret, master_anchor: String, stealth_account_id: AccountId, valid_for_daa: Option<u64> }`;
  - `DelegationCreateResponse { delegation_id: u64 }`;
  - `DelegationListRequest { master_anchor: String }`;
  - `DelegationListResponse { delegations: Vec<DelegationRecordV1> }`;
  - `DelegationRevokeRequest { wallet_secret, delegation_id: u64 }`;
  - `DelegationRevokeResponse {}`.
- Методы trait’а `WalletApi`:
  - `async fn delegation_create(&self, request: DelegationCreateRequest) -> Result<DelegationCreateResponse>;`
  - `async fn delegation_list(&self, request: DelegationListRequest) -> Result<DelegationListResponse>;`
  - `async fn delegation_revoke(&self, request: DelegationRevokeRequest) -> Result<DelegationRevokeResponse>;`.

### 6.2. CLI / SDK UX

- Фактические команды (Rust CLI):
  - `account delegation link <stealth-id> <master-anchor-hex> [valid-for-daa]`;
  - `account delegation list <master-anchor-hex>`;
  - `account delegation revoke <delegation-id>`;
  - отдельные `attach-stealth`, `detach-stealth` для привязки стелс к мастеру без создания делегации.
- В `wallet/core/src/wasm/api`:
  - JS‑фасады `wallet.delegationCreate(...)`, `wallet.delegationList(...)`, `wallet.delegationRevoke(...)`.
- UX‑ограничения:
  - создание делегации должно требовать подтверждения (особенно если используется онлайн‑мастер);
  - экспорт делегаций для air‑gap будет оформлен в итерации 6 (здесь только структура и локальное хранение).

## 7. Тесты и проверки

### 7.1. Unit / property тесты

- `wallet/core/src/account/delegation.rs`:
  - round‑trip Borsh/serde для `DelegationRecordV1`;
  - проверка CRDT‑логики выбора активной делегации;
  - доменная строка и хеширование (`delegation_message_hash`).
- `wallet/core/src/storage/ephemeral_keys.rs`:
  - миграция V0→V1 `EphemeralKeyEntry` (старые файлы читаются, новые поля `None`);
  - сохранение/загрузка с заполненными `master_anchor`/`delegation_id`.
- `wallet/core/src/tx/generator/stealth_signer.rs`:
  - sign без TLV (старый формат);
  - sign с TLV при `include_delegation_id=true` и наличии `delegation_id`.
- `crypto/txscript`:
  - `execute_stealth_spend` с TLV и без.

### 7.2. Интеграционные тесты

- Новый тест `testing/integration/mldsa_master.rs` (пока отсутствует — нужно добавить):
  1. Создать кошелёк, master, стелс‑аккаунт.
  2. Создать делегацию, отправить стелс‑tx с включённым TLV.
  3. Восстановить кошелёк по сид‑фразе, перечитать делегации и убедиться, что:
     - UTXO видны и spend‑ключи соответствуют делегированной ветке;
     - `signature_script` содержит ожидаемый TLV.
- Smoke‑тест RPC:
  - `register_mldsa_anchor` + `list_mldsa_delegations` не ломают существующие клиенты (`NotImplemented`/пустые структуры).
- Gating/флаги:
  - проверить, что при `kip10_enabled=false` stealth‑входы с `len != 65` отвергаются, а при `kip10_enabled=true` принимаются оба формата;
  - проверить, что `WalletSettings::EnableMldsaMaster=false` блокирует создание делегаций (`link_stealth_to_master`);
  - `GetServerInfoResponse.has_mldsa_master` отражает выбранную реализацию (правдиво или помечено как заглушка).

## 8. Чеклист Итерации 4

- [x] **Модель делегаций**: `DelegationRecordV1`, домены хеширования, CRDT‑логика выбора активной записи.
- [x] **Storage**: `DelegationStore` + версионирование `EphemeralKeyEntry` (V0/V1) с полями `master_anchor`/`delegation_id`.
- [x] **StealthAccount**: поля `master_anchor`, `active_delegation_id`, валидация делегаций при загрузке/линке.
- [x] **EphemeralKeyData**: обогащение делегацией при claim UTXO и при stealth‑change.
- [x] **StealthSigner + Generator**: флаг `include_delegation_id`, формирование TLV `0xA1 || delegation_id (u64 LE)` перед сигнатурой.
- [ ] **TxScript**: `execute_stealth_spend` с поддержкой переменной длины `signature_script` **и** привязкой к флагу активации (`kip10_enabled`), игнор TLV без парсинга.
- [ ] **RPC/Wallet API**: либо заглушки, либо минимальная реализация `register_mldsa_anchor`/`list_mldsa_delegations`; флаг `has_mldsa_master` должен отражать фактическую поддержку.
- [ ] **CLI / WASM**: команды создания/списка/ревокации делегаций — описание синхронизировано с фактическими командами; проверка `EnableMldsaMaster` при создании делегаций.
- [ ] **Тесты**: unit + integration по матрице из `Phase2_MLDSA_master_key.md`, включая отсутствующий `testing/integration/mldsa_master.rs`.


