# Phase 2 — Iteration 7: Тестирование и формальная верификация MLDSA master

> Цель итерации: довести стек MLDSA master / делегаций до уровня «production‑grade» за счёт систематического покрытия unit/property/integration/fuzz тестами и формализации ключевых инвариантов. На выходе мы должны иметь воспроизводимую матрицу тестов, минимум регрессий при доработках и понятную историю для внешнего аудита.

**Текущий статус (промежуточно):**
- ✅ `crypto/mldsa/src/master.rs`: расширены known-answer тесты L2/L3/L5, zeroize, запрет all-zero seed, roundtrip JSON/Borsh.
- ✅ `wallet/keys`: unit + property тесты anchor/HKDF/master seed (feat `proptest`), zeroize.
- ✅ `wallet/core`: тесты хранения `MlDsaMasterPayload`, unit/property для делегаций, базовые тесты master account (создание/anchor/подпись).
- ✅ Интеграция: `test_mldsa_master_anchor_registration_rpc` (anchor регистрируется, RPC/`has_mldsa_master` видит его).
- ✅ Интеграция: восстановление/реорг master+delegation (`test_mldsa_master_recovery_flow`, `test_mldsa_master_reorg_and_expiry`) и дополнительные проверки MLDSA скриптов/VM.
- ✅ Интеграция: MLDSA delegated spend включает оффлайн VM‑валидацию сигнатуры/скрипта (без отправки в mempool).
- ✅ Airgap: подписка на события `MasterDelegationExpiringSoon` через multiplexer (устранены проблемы с `events()`).

**Осталось:**
- Fuzz‑таргеты `wallet/core/fuzz` и nightly интеграция.
- Расширить тесты делегаций/stealth property‑tests (п.4.2) и миграции.
- Обновить `docs/api/MLDSA_MASTER.md` и `docs/TEST_COVERAGE_SUMMARY.md` связкой инвариантов/тестов.
- ⚠️ Сценарии восстановления и reorg добавлены как каркасы (`#[ignore]`), требуют доработки (восстановление стелс-ветки, симуляция двух нод).

## 0. Контекст и границы итерации

- **Что уже готово (Iter.1–6, согласно Phase2_MLDSA_master_key.md):**
  - PQ‑примитивы MLDSA (`crypto/mldsa/*`), детерминированная деривация master‑ключа из BIP39 сид‑а (`MasterSeed`, `derive_keypair_from_master_seed`) и anchor (`MasterAnchor`) в `wallet/keys`.
  - Структуры хранения master‑seed/anchor в `PrvKeyDataVariant::MlDsaMaster` + миграции и RPC/CLI API вокруг них.
  - `MldsaMasterAccount` как отдельный `AccountKind` в `wallet/core`, хранящий anchor/metadata и умеющий `unlock / sign / rotate`.
  - Структуры делегаций и связь master ↔ stealth‑аккаунты (`DelegationRecord`, `master_anchor`, `delegation_id` в payload’ах стелс‑аккаунтов), базовые RPC методы и airgap‑флоу (Iter.4–6).
  - Статус Iter.4 в `docs/IMPLEMENTATION_STATUS.md` обновлён: делегации/TLV/RPC и e2e `mldsa_master` тесты в кодовой базе завершены и используются как основа для Iter.7.
- **Что делаем в Iteration 7:**
  - Строим чёткую **матрицу тестов** для всего стека Phase 2 (криптопримитивы, ключи, аккаунты, делегации, RPC, airgap) и реализуем недостающие тесты.
  - Добавляем **property‑тесты** (proptest) для криптографических инвариантов и протокола делегаций.
  - Создаём **интеграционные сценарии** с поднятыми нодами/daemon/wallet, проверяющие end‑to‑end восстановление и ротацию.
  - Вводим **fuzz‑таргеты** для парсинга делегаций и состояния кошелька, интегрируем их в nightly CI.
  - Формализуем ключевые **инварианты** (state‑machine master/делегаций) и фиксируем их в коде и документации.
- **Чего НЕ делаем в Iteration 7:**
  - Не меняем формат данных (DelegationRecord, anchor, TLV) и не расширяем протокол (это зона Iter.4–6).
  - Не трогаем бизнес‑логики кошелька вне MLDSA/master/stealth‑веток, кроме минимальных хуков для тестов.

**Критерий успеха:** все заявленные тестовые таргеты (unit/property/integration/fuzz/airgap) зелёные на CI; инварианты формализованы и задокументированы; появление регрессий по master/делегациям/stealth легко отслеживается по упавшим тестам.

## 1. Область изменений и файлы

> Важно: многие элементы Phase 2 (master‑аккаунт, делегации) на момент написания плана описаны в архитектуре, но частично отсутствуют в коде. Итерация 7 должна **расширять уже существующие модули и паттерны тестирования**, а не вводить параллельные решения.

| Подсистема | Файлы / директории | Тип работ |
|-----------|--------------------|----------|
| MLDSA крипто | `crypto/mldsa/{lib.rs,master.rs,sign.rs,verify.rs}`, `crypto/mldsa/benches/mldsa_bench.rs`, `crypto/mldsa/tests/*` | Усиление unit‑тестов, KAT по FIPS‑204, тесты детерминированной деривации master‑ключа и zeroization. |
| Wallet keys | `wallet/keys/src/keypair_mldsa.rs`, `wallet/keys/src/derivation/*`, расширение существующих тестов (при необходимости — отдельный `wallet/keys/tests/mldsa_master_*.rs`) | Unit + property тесты для `MasterAnchor`, `from_bip39_root_seed`, HKDF‑деривации, zeroization; использование уже существующих тестов `test_mldsa_keypair_*` как референса. |
| Storage master | `wallet/core/src/storage/keydata/data.rs`, существующие тесты из `docs/api/MLDSA_MASTER.md` (дополнить сценариями миграций/reencrypt/zeroize; отдельный файл опционален) | Дополнение существующих тестов payload’а (`MlDsaMasterPayload`) и `PrvKeyDataVariant` сценариями миграций, шифрования и обнуления. |
| Master account | `wallet/core/src/account/variants/mldsa_master.rs` (появится к Iter.3), `wallet/core/src/account/{kind.rs,mod.rs}`, `wallet/core/tests/account_mldsa_master.rs` | Жизненный цикл аккаунта (create/unlock/sign/rotate), инварианты anchor/status, согласованность с API из `wallet/core/src/wallet/mod.rs` и событиями из `wallet/core/src/events.rs`. |
| Делегации и stealth | `wallet/core/src/account/delegation.rs` (Iter.4), `wallet/core/src/account/variants/stealth.rs`, `wallet/core/src/tx/generator/stealth_signer.rs`, `wallet/core/src/utxo/stealth_handler.rs` | Unit + property‑тесты делегаций и поведения стелс‑аккаунта при истечении/ревокации; расширение уже существующих тестов (`delegation.rs::tests`, `stealth_signer::tests`, `StealthUtxoHandler`). |
| RPC / сервисы | `rpc/core/*`, `rpc/service/*`, `wallet/core/src/api/{message.rs,traits.rs,transport.rs}`, `wallet/core/src/events.rs`, `testing/integration/src/rpc_tests.rs` | Интеграционные тесты RPC методов вокруг anchor/делегаций и airgap‑флоу, проверка событий `MasterAnchorCreated`/`MasterSeedExported` и будущих master‑/delegation‑ивентов. |
| Интеграция нод/кошелька | `testing/integration/src/mldsa_master.rs` (новый файл), `testing/integration/src/stealth_flow.rs` | End‑to‑end сценарии master ↔ stealth ↔ делегации ↔ reorg; переиспользование инфраструктуры `StealthTestEnv`. |
| Fuzz | Новый fuzz‑крейТ для wallet‑core (по мотивам `crypto/stealth/fuzz` и `math/fuzz`) | Fuzz‑таргеты парсинга делегаций, последовательностей событий master/stealth и состояния кошелька. |
| Документация | `docs/plans/phase2/Phase2_MLDSA_master_key.md`, `docs/api/MLDSA_MASTER.md`, `docs/TEST_COVERAGE_SUMMARY.md` | Актуализация матрицы тестов, строгая увязка инвариантов из этого плана с описанием API и существующими тестами, отражёнными в `MLDSA_MASTER.md`. |

## 2. Unit‑тесты: крипто и ключевая математика

### 2.1. `crypto/mldsa` — KAT и детерминизм master

**Цель:** доказать соответствие реализации NIST FIPS‑204 и корректность деривации master‑ключа.

- **KAT‑наборы (known‑answer tests):**
  - Добавить модуль `crypto/mldsa/tests/kat.rs` с загрузкой официальных KAT в формате:
    - `testdata/fips204/level{2,3,5}/{seed,pk,sk,sig}.bin` или JSON с hex‑строками.
  - Тесты:
    - `kat_keygen_level{2,3,5}`: для каждого seed — сверяем `PublicKey/SecretKey` с эталонными значениями.
    - `kat_sign_verify_level{2,3,5}`: для каждого `(seed, msg)` — сигнатура совпадает с эталонной и успешно верифицируется.
- **Детерминированная деривация master:**
  - В `crypto/mldsa/src/master.rs` уже есть тесты `determinism_known_answer_level2`; расширить:
    - Добавить тесты для уровней 3 и 5.
    - Тесты на кросс‑уровневую независимость: одна и та же `MasterSeed` даёт **разные** ключи для L2/L3/L5.
  - Тесты границ:
    - `derive_keypair_from_seed_rejects_all_zero_seed` (проверка ошибок и сообщений).
    - `master_seed_serde_roundtrip` для JSON/Borsh.
- **Zeroization:**
  - Усилить существующий `zeroize_master_seed`:
    - Дополнительно проверить, что после `into_bytes()` и `drop` временные буферы тоже очищаются (через побочный эффект / Miri в CI‑профиле — опционально).

### 2.2. `wallet/keys` — MasterAnchor, BIP39→MasterSeed

**Цель:** зафиксировать инварианты якоря и деривации master‑seed из BIP39, не ломая уже существующие тесты `test_mldsa_keypair_*`.

- Новый тестовый модуль `wallet/keys/tests/mldsa_master_unit.rs` (имя условное, главное — `#[cfg(test)]`‑сборка внутри `wallet/keys`):
  - **Anchor‑инварианты:**
    - `anchor_deterministic_for_same_pubkey`: два вызова `MlDsaKeypair::from_bip39_root_seed` с одинаковыми `(seed, account_index, level)` дают одинаковый `MasterAnchor`.
    - `anchor_changes_on_pubkey_change`: изменение `account_index` или `level` → новый anchor.
    - `anchor_domain_separation`: проверить, что вычисление anchor использует корректный домен `b"mldsa-anchor"` (например, пересчитать BLAKE2b вручную в тесте, как в коде).
  - **BIP39→MasterSeed:**
    - `derive_master_seed_from_bip39_is_deterministic`: для фиксированного 64‑байтного root seed и индекса возвращает один и тот же `MasterSeed`.
    - `derive_master_seed_from_bip39_rejects_wrong_length`: ошибка при длине ≠ 64.
  - **Zeroization (тонкий момент):**
    - В `derive_master_seed_from_bip39` уже вызывается `okm.zeroize()` — тест должен убедиться, что:
      - нет утечек «сырого» okm в observable API (`Display/Debug` не реализованы для секретных типов);
      - для косвенной проверки можно использовать вспомогательный буфер и убедиться, что после zeroize он не влияет на результат `MasterSeed`.

### 2.3. Storage `PrvKeyDataVariant::MlDsaMaster`

**Цель:** доказать корректность сериализации и миграций master‑payload’а.

- Новый модуль `wallet/core/tests/keydata_mldsa_master.rs`:
  - `mldsa_master_payload_borsh_roundtrip`:
    - Создать искусственный `MlDsaMasterPayload` (fake anchor, уровне L2, зашифрованный seed), записать в Borsh, прочитать обратно и сравнить.
  - `prv_key_data_variant_roundtrip`:
    - Обернуть payload в `PrvKeyDataVariant::MlDsaMaster`, сериализовать/десериализовать, проверить `kind()`, `id()`, zeroization.
  - `reencrypt_seed_changes_ciphertext`:
    - Вызвать `reencrypt_seed` с двумя разными ключами и проверить, что шифротекст изменился, при этом расшифровка новым ключом успешна.

## 3. Unit‑тесты: аккаунт мастера, делегации и stealth‑логика

### 3.1. `MldsaMasterAccount` (`wallet/core/src/account/variants/mldsa_master.rs`)

**Цель:** покрыть жизненный цикл master‑аккаунта и его инварианты, согласовав их с уже существующей моделью `Account`/`Inner`.

- Новый модуль `wallet/core/tests/account_mldsa_master.rs` (или `#[cfg(test)] mod tests` внутри `mldsa_master.rs`, по паттерну `stealth_signer.rs`):
  - **Create / load:**
    - `create_master_account_from_existing_prv_key_data`:
      - Инициировать `PrvKeyDataVariant::MlDsaMaster`, создать `MldsaMasterAccount` через фабрику, проверить поля payload (anchor, level, status=Active).
    - `load_master_account_fails_on_anchor_mismatch`:
      - Подготовить payload с неконсистентным anchor, ожидать ошибку `MasterAnchorMismatch`.
  - **Unlock / lock (тонкий момент — кэш секрета):**
    - `unlock_with_master_seed_success`:
      - Разблокировать аккаунт, запросить подпись и проверить, что при повторном unlock состояние кэшируемого ключа согласованно.
    - `lock_clears_secret_material`:
      - Вызвать `lock`, убедиться, что повторный `sign_message` требует unlock.
  - **Rotate (тонкий момент — согласованность с PrvKeyDataStore):**
    - `rotate_changes_anchor_and_status`:
      - Вызывать `Wallet::rotate_master_account` (ротация реализована на уровне `Wallet`, сам `MldsaMasterAccount` ротацию не выполняет). Проверить изменение anchor, смену статуса и запись события.
    - `rotate_rejected_when_revoked`:
      - Принудительно перевести статус в `Revoked`, затем через `Wallet::rotate_master_account` ожидать ошибку/отказ.

### 3.2. Делегации и stealth‑аккаунты

**Предпосылка:** структура `DelegationRecord` уже реализована (Iter.4), а `StealthAccount::Payload` к Iter.4/5 расширен полями `master_anchor` и `delegation_id` (сейчас `Payload` содержит только ключи и `creation_daa_score`).

- Новый модуль `wallet/core/tests/delegation_unit.rs`:
  - `delegation_record_sign_verify_roundtrip`:
    - Сконструировать `DelegationRecord`, подписать мастером, проверить успешную верификацию.
  - `delegation_nonce_monotonic`:
    - Смоделировать несколько делегаций к одной ветке с возрастающим `nonce`; убедиться, что при merge выбирается запись с максимальным `nonce`.
  - `delegation_rejects_wrong_anchor`:
    - Заменить `anchor` в записи на случайный, ожидать управляемый провал проверки (ошибка, а не паника) и отсутствие побочных эффектов в состоянии кошелька.
- Модуль `wallet/core/tests/stealth_master_link.rs`:
  - `attach_stealth_to_master_sets_anchor_and_delegation_id_none`:
    - После привязки стелс‑аккаунта проверить поля в payload, убедиться, что `delegation_id` ещё не проставлен, а сериализация/десериализация остаётся совместимой с версией без master‑полей.
  - `stealth_account_rejects_spend_without_valid_delegation`:
    - Через `StealthSigner`/`EphemeralKeyData` попытаться подписать транзакцию без валидной делегации (или с истёкшей), ожидать ошибку:
      - тест должен учитывать уже существующие сценарии из `stealth_signer::tests` (отсутствие ключа, пропуск non‑stealth входов) и не конфликтовать с ними.

## 4. Property‑тесты (proptest)

### 4.1. HKDF и MasterAnchor

**Цель:** застраховаться от неожиданных коллизий и утечек структуры, используя уже принятую практику `proptest` (см. `crypto/stealth/tests/property_tests.rs`).

- Новый файл `wallet/keys/tests/mldsa_master_properties.rs`:
  - `prop_master_seed_deterministic`:
    - Для случайного root seed и account index — два вызова `derive_master_seed_from_bip39` возвращают одинаковый результат.
  - `prop_master_seed_unique_across_account_index`:
    - Для фиксированного root seed и разных `account_index` assert, что master‑seed/anchor отличаются.
  - `prop_anchor_unique_for_random_pubkeys`:
    - Для N случайных публичных ключей (используя `MlDsaKeypair::random`) проверить отсутствие коллизий anchor (для N~1000; статистический тест).

### 4.2. Делегации и stealth‑логика

**Цель:** формально зафиксировать семантику истечения/ревокации делегаций.

- Новый файл `wallet/core/tests/delegation_properties.rs`:
  - `prop_delegation_forgery_rejected`:
    - Для случайно сгенерированных полей `DelegationRecord` и случайного неподписанного payload убедиться, что любая «подделанная» подпись (рандомные байты) отклоняется.
  - `prop_delegation_expiration_enforced`:
    - Генерировать случайные окна `[valid_from_daa, valid_until_daa]` и DAA‑высоты; проверять, что проверка окна (через helper вида `is_valid_at` или имеющийся `delegation_window_ok`) даёт корректную булеву семантику.
  - `prop_stealth_change_not_created_without_valid_delegation`:
    - Для случайных параметров делегации проверять, что генератор change‑адреса (`StealthAccount` + `StealthSigner`) отказывается создавать новые адреса, если делегация истекла.

## 5. Интеграционные тесты (`testing/integration/src/mldsa_master.rs`)

### 5.1. Общий каркас

Используем существующую инфраструктуру `testing/integration` (см. `stealth_flow.rs`), чтобы не плодить альтернативные наборы утилит:

- Создаём `MldsaMasterTestEnv` по аналогии со `StealthTestEnv`:
  - Запуск simnet‑daemon через `Daemon::new_random_with_args` и `GrpcClient` в режиме multi‑listener.
  - Создание `Wallet` с resident‑store (`Wallet::resident_store()`), инициализация хранилища через `wallet_create`.
  - Привязка RPC к кошельку (`Rpc`, `RpcCtl`, `UtxoProcessor::bind_rpc`, `start()`), как уже сделано для stealth‑потока.
  - Утилиты для майнинга блоков, получения UTXO и ожидания DAA‑высот переиспользуются из `common::{daemon,utils}`.

### 5.2. Сценарий A: восстановление через сид + anchor

**Цель:** показать, что master/stealth/делегации полностью восстанавливаются из сид‑а и on‑chain данных, при этом события и RPC‑интерфейсы ведут себя так, как описано в `docs/api/MLDSA_MASTER.md`.

Шаги:

1. **Инициализация:**
   - Создать кошелёк с BIP39‑сидом и включённым `EnableMldsaMaster`.
   - Создать мастер‑аккаунт уровня 2, привязать к нему стелс‑аккаунт.
2. **Создание делегации:**
   - Через CLI/SDK или прямой вызов API создать делегацию для стелс‑ветки (валидную по DAA).
3. **Транзакция:**
   - Отправить несколько переводов на стелс‑адреса, убедиться в получении UTXO кошельком (как в `stealth_flow.rs`).
4. **Рестарт и восстановление:**
   - Закрыть кошелёк/daemon, пересоздать окружение.
   - Восстановить кошелёк из того же сид‑а; дождаться, пока кошелёк пересканирует цепь.
5. **Проверки:**
   - Anchor мастера совпадает с исходным.
   - Баланс стелс‑аккаунта совпадает (UTXO/tx‑история идентична).
   - Делегация помечена как актуальная, `delegation_id` в стелс‑payload заполнен.

### 5.3. Сценарий B: reorg и истечение делегации

**Цель:** убедиться, что reorg и DAA‑сдвиги корректно обрабатываются и не «разрешают» просроченные делегации, а существующая логика `StealthUtxoHandler`/`UtxoContext` не нарушается.

Шаги:

1. Поднять 2 ноды + кошелёк:
   - Node A — основная цепь, Node B — потенциальный источник reorg.
2. Создать делегацию с ограниченным `valid_until_daa`.
3. На Node A:
   - Отправить транзакции, которые попадают в диапазон валидности делегации.
4. На Node B:
   - Смоделировать более длинную цепочку с DAA‑высотой > `valid_until_daa`, но с reorg, который «откатывает» некоторые блоки.
5. После переключения на цепь B:
   - Проверить, что кошелёк:
     - Не создаёт новые change‑адреса без обновлённой делегации.
     - Помечает старую делегацию как истёкшую и эмитит событие `MasterDelegationExpired`.
     - Не теряет уже полученные средства (UTXO остаются spendable, если они были в окне валидности).

### 5.4. Кросс‑слойные инварианты: `crypto/txscript` ↔ wallet

**Цель:** любые изменения в MLDSA на уровне консенсуса/txscript (формат скриптов, sighash, VM) должны сразу проявляться в тестах wallet‑стека.

- **Что уже проверяет `crypto/txscript`:**
  - `crypto/txscript/tests/integration_mldsa.rs`:
    - end‑to‑end проверка: `pay_to_address_script` для `Version::PubKeyMLDSA`, построение `ScriptPublicKey`, расчёт sighash через `calc_schnorr_signature_hash`, подпись `kaspa_mldsa::sign`, исполнение `TxScriptEngine`.
    - негативные кейсы: повреждённая сигнатура и подпись от другого ключа.
  - `crypto/txscript/tests/e2e_comprehensive.rs`:
    - проверяет уровни 2/3/5, размеры ключей и сигнатур, mixed‑blocks (несколько MLDSA tx в блоке), оценку массы и security‑кейсы.
  - `crypto/txscript/src/{standard.rs,script_class.rs}`:
    - фиксируют формат MLDSA‑скрипта: 1312‑байтный pubkey, общая длина скрипта 1316, `OpPushData2`, LE‑длина `0x0520`, завершающий `OpCheckSigMLDSA`, а также классификацию `ScriptClass::PubKeyMLDSA`.
- **Что добавляем в интеграционные тесты wallet (Iter.7):**
  - **Согласованность скриптов:**
    - Для всех выходов, которые кошелёк создаёт на MLDSA‑адреса (версия `Version::PubKeyMLDSA`):
      - прогонять `ScriptClass::from_script` и ожидать `ScriptClass::PubKeyMLDSA`;
      - вызывать `extract_script_pub_key_address` и сравнивать результат с исходным `Address`, полученным из wallet‑API;
      - проверять, что длина и структура байтов скрипта (`OpPushData2`, LE‑длина `0x0520`, позиция `OpCheckSigMLDSA`) совпадают с ожиданиями из `standard.rs`.
  - **Повторная верификация через VM:**
    - В `mldsa_master`‑сценариях (A и B) для транзакций, которые кошелёк считает валидными и отправляет в сеть:
      - собирать для них `UtxoEntry` так же, как это делает `integration_mldsa.rs`;
      - запускать `TxScriptEngine::from_transaction_input(...).execute()` для каждого MLDSA‑input;
      - любое расхождение (wallet считает tx валидной, а VM — нет) считается критическим и должно ломать интеграционный тест.
  - **Размеры и масса:**
    - Для Level 2 на уровне wallet дополнительно:
      - проверять, что фактический размер сигнатуры и публичного ключа, попавших в ScriptPublicKey и input‑подпись, совпадает с параметрами, использованными в `e2e_comprehensive.rs` (PK=1312, Sig=2420);
      - оценивать массу tx по тому же приближённому правилу, что и `create_and_verify_mldsa_tx`, и убеждаться, что она остаётся в целевом диапазоне (не нарушая throughput целей).
  - **Связь с master‑аккаунтом:**
    - Для тестов, которые используют MLDSA‑master из wallet‑ключей (`kaspa_wallet_keys::MlDsaKeypair`):
      - проверять, что транзакции, подписанные через кошелёк, эквивалентны транзакциям, сконструированным вручную по паттерну `integration_mldsa.rs`:
        - по используемому sighash (`SigHashReusedValuesUnsync`, `SIG_HASH_ALL`);
        - по формату подписи (подписываем тот же digest, байт `SIG_HASH_ALL` в конце, длина сигнатуры).

## 6. Fuzz‑тестирование (`cargo fuzz`)

### 6.1. Структура fuzz‑крейта

- Создать новый крейт `wallet/core/fuzz` (по аналогии с `crypto/stealth/fuzz` и `math/fuzz`):
  - `Cargo.toml` с зависимостями на `wallet/core`, `wallet/keys`, `kaspa_mldsa`, `arbitrary`, `libfuzzer-sys`.
  - `fuzz_targets/`:
    - `wallet_mldsa_delegation.rs`
    - `wallet_mldsa_master_state.rs`

### 6.2. Fuzz‑таргеты

- **`wallet_mldsa_delegation.rs`:**
  - Вход: произвольный байтовый массив.
  - Попытаться распарсить как `DelegationRecord` (Borsh + serde), затем:
    - Вызвать валидацию полей (проверка окна делегации через helper `delegation_window_ok`/`is_valid_at`, длины, допустимые уровни).
    - Если подпись формально валидна по формату, прогнать `verify` и убедиться в отсутствии паник/UB.
- **`wallet_mldsa_master_state.rs`:**
  - Вход: последовательность случайных команд над упрощённой state‑machine мастера:
    - `Create`, `Unlock`, `Lock`, `Rotate`, `Revoke`, `AttachStealth`, `DetachStealth`.
  - Генерировать сценарии и проверять инварианты:
    - Нет пути из `Revoked` обратно в `Active`.
    - Anchor не меняется без `Rotate`.
    - Стелс‑аккаунт не может быть одновременно привязан к двум разным anchor.

### 6.3. Интеграция в CI

- Обновить `.github/workflows/mldsa-tests.yml`:
  - Добавить job `cargo fuzz run wallet-mldsa-delegation -- -max_total_time=600`.
  - Аналогично для `wallet-mldsa-master-state` (укороченный бюджет, например 300 сек).
- Дополнить `docs/TEST_COVERAGE_SUMMARY.md` разделом «MLDSA master fuzzing» с описанием таргетов и параметров.

## 7. Формализация инвариантов

**Цель:** чтобы любой новый разработчик мог понять, «что именно мы доказываем» тестами Iteration 7.

- В `docs/plans/phase2/Phase2_MLDSA_master_key.md` и `docs/api/MLDSA_MASTER.md` добавить/расширить раздел «Инварианты и проверки», включающий:
  - Инварианты master:
    - Один payload `MldsaMasterAccount` ↔ один `PrvKeyDataId`.
    - Anchor всегда совпадает с публичным ключом текущего master‑seed.
    - Переходы статусов: `Active → Rotated → Revoked`, без обратных дуг.
  - Инварианты делегаций:
    - Каждой стелс‑ветке соответствует максимум одна активная делегация с данным anchor и `nonce` (остальные либо устаревшие, либо отозваны).
    - Для любого spend по стелс‑аккаунту существует валидная по `valid_from/valid_until` делегация на момент DAA‑высоты транзакции.
  - Инварианты airgap:
    - Все `MasterDelegationRequest/Response` сериализуются/десериализуются без потери информации.
    - Любая модификация JSON/Borsh‑payload’а делегации приводит к провалу подписи.
- Связать каждый инвариант с конкретными тестами:
  - Таблица вида «Инвариант → unit‑тесты → property‑тесты → fuzz‑таргеты → интеграционные сценарии».

## 8. Критерии готовности Iteration 7

- Все новые unit/property/integration/fuzz‑тесты по MLDSA master/делегациям зелёные локально и на CI.
- Метрики покрытия (line/branch) по модулям `crypto/mldsa`, `wallet/keys::keypair_mldsa`, `wallet/core::account::mldsa_master`, `wallet/core::account::delegation` находятся на согласованном уровне (целевой порог фиксируется в `docs/TEST_COVERAGE_SUMMARY.md`).
- `Phase2_MLDSA_master_key.md` и `TEST_COVERAGE_SUMMARY.md` обновлены и ссылаются на Iteration 7 как на источник правды по тестам.
- Для QA/аудита доступен воспроизводимый список команд:
  - `cargo test -p kaspa-mldsa`
  - `cargo test -p kaspa-wallet-keys mldsa_master_* --features proptest`
  - `cargo test -p kaspa-wallet-core mldsa_master_*`
  - `cargo test -p kaspa-testing-integration mldsa_master`
  - `cargo fuzz run wallet-mldsa-delegation` / `wallet-mldsa-master-state` (nightly).

## 9. Порядок выполнения и организационные моменты

### 9.1. Рекомендуемая последовательность работ

1. **Крипто‑уровень (`crypto/mldsa`):**
   - Реализовать и стабилизировать KAT‑тесты и дополнительные unit‑тесты из раздела 2.1.
   - Подтвердить, что изменения не ломают `crypto/txscript` e2e‑тесты (они являются внешним потребителем API).
2. **Деривация и anchor в `wallet/keys`:**
   - Добавить unit/property‑тесты из разделов 2.2 и 4.1.
   - Сверить значения сидов/anchor’ов с примерами из `docs/api/MLDSA_MASTER.md` (одни и те же входы → те же значения).
3. **Хранилище master‑ключа (`wallet/core::storage::keydata`):**
   - Реализовать тесты из 2.3, прогнать их на:
     - новом хранилище;
     - существующем файле кошелька (до Phase 2) с миграцией.
4. **Master‑аккаунт (`wallet/core::account::mldsa_master`):**
   - После завершения Iteration 3 реализовать/дополнить master‑аккаунт и покрыть его тестами из 3.1.
   - Убедиться, что аккаунт корректно интегрирован в фабрику, события и wallet‑API.
5. **Делегации и stealth‑аккаунты:**
   - После завершения Iteration 4–5 реализовать unit/property‑тесты из 3.2 и 4.2.
   - Особо проверить миграцию стелс‑payload’а (старые кошельки без master‑полей читаются без потерь).
6. **Интеграционные тесты (`testing/integration`):**
   - Реализовать `mldsa_master.rs` по разделу 5 (сценарии A/B + проверки из 5.4).
   - Убедиться, что тест стабильно проходит локально и в CI (без флаки и чувствительности к таймингам).
7. **Fuzz‑тесты:**
   - Создать fuzz‑крейТ и таргеты из раздела 6.
   - Сначала гонять локально (малый `max_total_time`), затем включить в nightly‑джобы.
8. **Документация и связка инвариантов:**
   - Обновить `Phase2_MLDSA_master_key.md`, `docs/api/MLDSA_MASTER.md`, `docs/TEST_COVERAGE_SUMMARY.md` согласно разделам 7–8.
   - Добавить краткий пункт в `docs/IMPLEMENTATION_STATUS.md` о том, что Iteration 7 покрывает весь стек тестами.

### 9.2. Разделение ответственности (минимальный черновик)

- **Crypto/consensus:**
  - Поддержка `crypto/mldsa` и `crypto/txscript` тестов, согласование любых изменений форматов (ключи, подписи, скрипты).
- **Wallet‑core:**
  - Реализация всех unit/property/integration‑тестов кошелька, связанных с MLDSA master и делегациями.
- **Инфраструктура/CI:**
  - Настройка nightly‑workflow `mldsa-tests.yml`, контроль времени выполнения и стабильности.
- **QA/безопасность:**
  - Верификация того, что матрица инвариантов (раздел 7) реально покрыта тестами; ведение чек‑листа регрессий.

### 9.3. Требования к PR по Iteration 7

- Каждый PR, относящийся к этой итерации, должен:
  - Явно ссылаться на конкретные пункты текущего файла (например, «реализует 2.2 + 4.1»).
  - Включать в diff не только код, но и соответствующие тесты и, при необходимости, обновления docs.
- Запрещено мержить изменения, влияющие на MLDSA‑форматы (ключи, подписи, скрипты, TLV‑поля), если:
  - Не обновлены/не пройдены соответствующие KAT и e2e‑тесты в `crypto/mldsa` и `crypto/txscript`.
  - Не пройден интеграционный тест `testing/integration/src/mldsa_master.rs`.
  - Не выполнен хотя бы один недавний запуск fuzz‑таргетов `wallet_mldsa_delegation` и `wallet_mldsa_master_state` (либо не зафиксировано обоснование, почему fuzz временно отключён).

