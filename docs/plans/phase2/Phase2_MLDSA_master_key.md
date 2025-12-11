# Phase 2 — MLDSA Master Root (Master & Commander)

> Цель: ввести «корневой» MLDSA-аккаунт, который живёт офлайн, выдаёт подписи делегирования одноразовым стелс-ключам и становится единственным источником истины при восстановлении владения активами.
>
> В этом плане подробно расписаны этапы, файлы и проверки, необходимые для безопасного запуска MLDSA-root поверх уже реализованных стелс-адресов (Phase 1).
>
> Обозначения:  
> **Master** — MLDSA ключ (Dilithium/ML-DSA level 2) + его hash-anchor.  
> **Anchor** — `Hash(domain="mldsa-anchor", master_pubkey)` (храним в кошельке и/или ончейне).  
> **Delegation** — подпись мастером на сообщение «этот stealth branch валиден до X».  
> **Ephemeral** — Schnorr/stealth одноразовые ключи, которые уже реализованы в Phase 1.  
> **Wallet stack** — `wallet/{core,keys,native,wasm}` + CLI.

## 0. Текущее состояние (изученный код)

| Слой | Файлы | Что уже есть |
|------|-------|--------------|
| PQ криптопримитивы | `crypto/mldsa/{lib.rs,keypair.rs,sign.rs,verify.rs}` | ML-DSA уровни 2/3/5, генерация, подпись, верификация, тесты. |
| Стелс крипто | `crypto/stealth/{lib.rs,keys.rs,sender.rs,receiver.rs}` | Отдельные scan/spend ключи на secp256k1, view tags, сериализация ephemeral output (R ∥ tag ∥ Pdest). |
| TxScript / консенсус | `crypto/txscript/src/standard.rs`, `crypto/txscript/src/lib.rs`, `consensus/core/...` | `Version::Stealth`, `STEALTH_SCRIPT_VERSION=16`, Native SegWit проверка schnorr подписи по Pdest, `OpCheckSigMLDSA` и масса под MLDSA. |
| Wallet keys | `wallet/keys/{derivation, keypair_mldsa.rs}` | BIP39/BIP32 дерево, secp-derived stealth ветки, базовый wrapper над MLDSA (Random keypair). |
| Wallet core | `wallet/core/src/account/variants/stealth.rs`, `storage/ephemeral_keys.rs`, `tx/generator/...` | Полное создание/сканирование стелс-аккаунта, хранение одноразовых ключей, RPC fallback (`get_utxos_by_script_version`, view tags), биндинги в wasm/native. |
| CLI & API | `cli/src/modules/...`, `wallet/native`, `wallet/wasm` | Команды управления аккаунтами, но без PQ/master UX. |

**Вывод:** все строительные блоки для Schnorr-основанных стелс-адресов есть; MLDSA используется только для «обычных» адресов через `Version::PubKeyMLDSA`. Нет детерминированной деривации мастера из BIP39, нет хранения hash-anchor, нет протокола делегирования одноразовым ключам.

### 0.1. Дополнительные наблюдения из кода

- `kaspa_wallet_keys::derivation` уже содержит split receive/change для secp (`WalletDerivationManagerV0`), но нет ветки `AddressType` для PQ: нужно расширять `build_derivate_path` и `create_pubkey_manager` (см. `wallet/keys/src/derivation/gen0/hd.rs`).
- Stealth-аккаунт хранит только secp256k1 ключи (`StealthKeyDerivation` в `wallet/core/src/account/variants/stealth.rs`). Все persistent payload’ы (`StealthAccount::Payload`) — Borsh-структуры без места под мастер-якорь/делегацию.
- Transaction signer (`wallet/core/src/tx/generator/stealth_signer.rs`) берёт spending key из `EphemeralKeyData` и никак не проверяет происхождение — это и будет точкой валидации делегаций.
- RPC сегодня отдаёт `has_stealth_support`, `get_utxos_by_script_version` и `get_block_view_tags`, но нет API для регистрации anchor. Будем расширять `kaspa_rpc_core::{api, message}` и `rpc/service`.
- Kasplex L2 документация (`docs/KASPLEX_INTEGRATION_GUIDE.md`, `docs/KASPLEX_L2_COMPATIBILITY.md`) ожидает, что MLDSA ключи уже умеют детерминироваться и экспортироваться из кошелька → важно синхронизировать формат анкера/подписи между L1 и L2.

### 0.2. Быстрая сводка по Iteration 6 (Airgap UX)

- Форматы `MasterDelegationRequest/Response`, `calc_request_id` и домен Delegation заведены; CLI команды `wallet master sign-delegation` / `apply-delegation` покрывают оффлайн подпись и онлайн применение.
- wasm/native: биндинги и FFI summary-функции для JSON запросов/ответов готовы.
- Интеграционный тест `testing/integration/src/airgap_mldsa.rs` проверяет поток online → offline → online и наличие `delegation_id` в эфемерных ключах после apply.
- CI (`.github/workflows/mldsa-tests.yml`) запускает `cargo test -p kaspa-testing-integration airgap_mldsa` вместе с MLDSA unit/integration наборами.
- Гайд: `docs/guides/master_cold_storage.md` описывает шаги, JSON примеры и чеклист безопасности.

## 1. Целевая архитектура MLDSA-root

1. **Deterministic master generation.** Из одного BIP39 сид-а вычисляется MLDSA-ключ (FIPS-204 KDF + HKDF(SHA3) для domain separation). Ручной RNG не нужен при восстановлении.
2. **Anchor commitment.** В кошельке хранится `anchor = BLAKE2b("mldsa-anchor", master_pubkey)`; по желанию отправляем его в сеть (отдельный ScriptPublicKey/метаданные транзакции) для публичного доказательства.
3. **Delegation records.** Мастер подписывает структуру `Delegation { anchor, stealth_branch_pubkey, valid_from, valid_until, nonce }`. Подпись хранится в кошельке и/или публикуется при необходимости.
4. **Wallet layout.**  
   - `PrvKeyData` теперь содержит: BIP39 сид + MLDSA seed blob (зашифрованный).  
   - Новый `AccountKind`: `kaspa-mldsa-master`, который живёт офлайн (может не иметь RPC).  
   - Существующие `StealthAccount` получают ссылку на актуальную делегацию (anchor hash + подпись).
5. **Recovery.** При восстановлении из сид-а:  
   1. восстанавливаем MLDSA master;  
   2. проверяем локальные делегации;  
   3. переиздаём делегации (по желанию) и переинициализируем стелс-аккаунты.
6. **Rotation & revocation.** Мастер может подписать revoke/rotate сообщение. Кошелёк должен уметь:  
   - маркировать старые делегации недействительными;  
   - перепривязать новые stealth ветки;  
   - обновить change-адреса без реимпорта блокчейна.

### 1.1. Форматы данных и домены хеширования

| Артефакт | Формат | Комментарии |
|----------|--------|-------------|
| `MasterSeed` | 48 байт (`HKDF-Expand` из BIP39 seed, info=`"mldsa-master-seed"`) | zeroize + `serde(transparent)` для Borsh. |
| `MasterAnchor` | `BLAKE2b-256(DOMAIN="mldsa-anchor" ∥ master_pubkey)` | одна и та же функция для кошелька, RPC и эксплорера. |
| `DelegationRecord` | Borsh/TLV, версия 1, см. секцию итерации 4 | сигнатура MLDSA Level2 (~2420 байт). |
| `DelegationNonce` | `u64`, инкрементируется мастером, чтобы CRDT-слияние было однозначным. |
| RPC wire | JSON (existing schema) + base64 для подписи; внутри хранится Borsh payload. |

Доменные строки для хешей/подписей обязаны попасть в `crypto/mldsa/src/params.rs`, чтобы не размазывать литералы по кошельку.

## 2. Инкрементальный план внедрения

### Итерация 0 — Подготовка & UX фиксация ⏳
- [ ] Актуализировать требования в `docs/PRIVACY_STRATEGY.md` и добавить ссылки на этот план (PR).  
- [ ] Убедиться, что `kaspad` и `wallet/core` собраны в режиме `nightly` (debug assertions обязательны во время dev-периода).  
- [ ] Согласовать формат `anchor` и `delegation` (JSON/Borsh) с мобильными/CLI командами; задокументировать в `docs/API.md` (новый раздел).  

### Итерация 1 — Детерминированный MLDSA master ✅
**Цель:** возможность получить один и тот же master ключ на всех устройствах.  
**Статус: ВЫПОЛНЕНО**  
**Изменения и файлы:**
1. `crypto/mldsa/src/keypair.rs`  
   - [x] Добавить `fn derive_keypair(seed: &[u8], level: MlDsaLevel) -> Result<MlDsaKeypair>` (HKDF-SHA3-512, info=`"kaspa.mldsa.master"`).  
   - [x] Ввести `MasterSeed([u8; 48])` + `impl Zeroize`.  
   - [x] Перенести KAT-тесты на фиксированные seed (см. FIPS 204 A.3).  
2. `crypto/mldsa-ffi/`  
   - [x] Экспортировать `mldsa_derive_keypair` для Go/JS (Kasplex bridge уже тянет FFI).  
3. `wallet/keys/{derivation/mod.rs, keypair_mldsa.rs}`  
   - [x] Добавить `DerivationPurpose::MldsaMaster = 734`.  
   - [x] Метод `MlDsaKeypair::from_bip39_root_seed(bip39_seed, level)` → вызывает derive + считает anchor.  
   - [x] Сохранять anchor как `MasterAnchor([u8;32])`, предоставить `Display`/`serde` для CLI.  
4. `wallet/keys/tests/`  
   - [x] Property-тесты `derive(seed)==derive(seed)` + проверка, что изменение account index => другой ключ.  
   - [x] Negative tests: вывод разных уровней (L2/L3) не совпадает.  
5. Документация: `docs/IMPLEMENTATION_STATUS.md` → добавить пункт «Deterministic MLDSA root ✅» после завершения.  

### Итерация 2 — Хранение и шифрование master ✅
**Цель:** безопасно положить MLDSA seed/anchor в `PrvKeyData`.  
**Статус: ВЫПОЛНЕНО**  
**Изменения:**
1. `wallet/core/src/storage/keydata/data.rs` и `wallet/core/src/storage/keydata/mod.rs`  
   - [x] Новый `PrvKeyDataVariant::MlDsaMaster(MlDsaMasterPayload)` с полями `level`, `seed_cipher`, `anchor`.  
   - [x] `PrvKeyData::try_new_from_mnemonic` автоматически вызывает derive (ит.1) и добавляет запись.  
   - [x] Zeroize всех payload после использования (через `Zeroizing<_>`).  
   - [x] Метод `reencrypt_mldsa_master_seed` для корректной смены пароля кошелька.  
2. `wallet/core/src/storage/local/payload.rs`  
   - [x] Версия хранилища `STORAGE_VERSION = 1` (миграция: старые кошельки получают `MlDsaMaster` лениво при первом unlock).  
   - [x] Флаг `WalletSettings::EnableMldsaMaster` → позволяет отключить автоматическую генерацию.  
   - [x] Обратная совместимость: чтение v0 файлов без поля `encrypt_transactions`.  
3. FFI:  
   - [x] `wallet/native/src/types.rs`, `wallet/native/src/runtime.rs`: C-friendly структуры `MasterAnchorInfo`, `PrvKeyDataInfoFFI`.  
   - [x] `wallet/core/src/wasm/wallet/wallet.rs`: методы `masterAnchors()` и `exportMasterAnchor(request)`.  
4. CLI + bindings  
   - [x] `cli/src/modules/wallet.rs`: команды `wallet master list`, `wallet master export`, `wallet master verify-anchor`, `wallet master set`.  
   - [x] Авто-предупреждение и подтверждение `EXPORT` при экспорте seed.  
5. API / RPC / Events  
   - [x] `wallet/core/src/api/message.rs`: `MasterAnchorListRequest/Response`, `MasterSeedExportRequest/Response`.  
   - [x] `wallet/core/src/api/traits.rs`: методы `master_anchor_list_call`, `master_seed_export_call`.  
   - [x] `wallet/core/src/api/transport.rs`: клиент и сервер хендлеры для RPC.  
   - [x] `wallet/core/src/events.rs`: события `MasterAnchorCreated`, `MasterSeedExported`.  
   - [x] WASM: `declare!` макросы для JS-интерфейсов, unit-тесты конвертации.  
6. QA  
   - [x] Unit: сериализация `PrvKeyDataVariant::MlDsaMaster`, миграция из старых payload.  
   - [x] `cargo test -p kaspa-wallet-core storage::local::payload` — зелёные.  
   - [x] CI: `.github/workflows/mldsa-tests.yml` с полным покрытием.  

### Итерация 3 — Master Account и anchor metadata
**Цель:** представить master как отдельный account-kind и хранить anchor/историю операций.  
**Изменения:**
1. `wallet/core/src/account/kind.rs`, `wallet/core/src/account/factory/mod.rs`  
   - Константа `MLDSA_MASTER_ACCOUNT_KIND`, регистрация в фабрике.  
2. Новый модуль `wallet/core/src/account/variants/mldsa_master.rs`  
   - Данные: `anchor`, `level`, `created_at_daa`, `delegations: Vec<DelegationId>`, `status` (Active/Revoked/Rotated).  
   - Методы:  
     - `unlock_with_master_seed` (использует Iter.2 payload).  
     - `sign_message(domain, payload)` → универсальный helper для CLI.  
     - `rotate(level, new_seed_option)` — обновляет anchor + пишет ревокацию.  
3. `wallet/core/src/storage/account.rs` и `wallet/core/src/account/variants/stealth.rs::Payload`  
   - Увеличить версию, добавить поле `master_anchor: Option<[u8;32]>`, `delegation_id: Option<u64>`.  
   - Миграционный путь: `None` (старые stealth остаются валидны, пока не линканём мастер).  
4. `wallet/core/src/wallet/mod.rs`  
   - API: `create_account_mldsa_master`, `list_master_accounts`, `attach_stealth_to_master`, `get_master_by_anchor`.  
   - События: `Events::MasterAnchorCreated`, `Events::MasterRotated`.  
5. CLI / WASM  
   - `account create mldsa-master [<name>]` — создаёт master‑аккаунт, выбирая `PrvKeyData`, выводит `account_id`, `anchor`, `level`, `status`.  
   - `account list --kind mldsa-master` — фильтр списка аккаунтов по `AccountKind == MLDSA_MASTER_ACCOUNT_KIND`, показывает счётчик привязанных stealth.  
   - `account attach-stealth <stealth-id> <master-id>` — привязывает stealth‑аккаунт к мастеру (записывает `master_anchor`).  
   - `account detach-stealth <stealth-id>` — снимает привязку stealth‑аккаунта от мастера.  
   - `wallet master sign ...` / `wallet master rotate ...` — UX для подписи/ротации через `MldsaMasterAccount::sign_message` и `Wallet::rotate_master_account`.  
   - WASM `WalletApi`: `createMasterAccount`, `listMasterAccounts`, `attachStealthToMaster`, `detachStealthFromMaster` (+ аналогичные FFI‑биндинги).  
6. UX  
   - Wizard в CLI: при создании нового stealth аккаунта спрашивать «Привязать к мастеру <anchor>?».  
   - GUI (если есть) показывает QR с anchor + статус ревокации.  

### Итерация 4 — Делегации и связь со стелс-аккаунтами
**Цель:** мастер выдаёт доказательство, что конкретные stealth ветки авторизованы.  
**Действия:**
1. Структура `DelegationRecord` (новый модуль `wallet/core/src/account/delegation.rs`):  
   ```
   version: u8
   anchor: [u8;32]
   account_id: AccountId (stealth)
   spend_pubkey: XOnly
   scan_pubkey: XOnly
   valid_from_daa: u64
   valid_until_daa: u64 (optional)
   nonce: u64
   signature: MlDsaSignature
   ```
2. `wallet/core/src/account/variants/stealth.rs`  
   - Добавить поле `master_anchor: Option<[u8;32]>` и ссылку на `DelegationRecord`.  
   - При генерации change/receive адресов проверять, что делегация валидна; иначе требовать переподписать.  
   - Persist `DelegationRecord` в `AccountStorage` (расширить Payload).  
3. `wallet/core/src/tx/generator/stealth_signer.rs`  
   - В signature_script добавить TLV `0xA1 || delegation_id (u64 LE)` перед подписью (флаг `GeneratorSettings::include_delegation_id`).  
   - `EphemeralKeyData` дополняется полем `delegation_anchor`, проверяется перед подписями.  
4. `rpc/core` и `rpc/service`  
   - Протокол `register_mldsa_anchor` + `list_mldsa_delegations(anchor)` (опционально, можно оставить оффчейн).  
   - `wrpc`, `grpc` и `rpc/wrpc/macros` синхронно расширяются.  
5. CLI flow / SDK:  
   - `account link-stealth-to-master --stealth-id ... --master-id ... --valid-until ...`.  
   - `account list-delegations --master-id ...`, `account revoke-delegation --delegation-id ...`.  
6. Kasplex L2 зависимость:  
   - `docs/KASPLEX_INTEGRATION_GUIDE.md` обновить: bridge проверяет anchor через RPC метод из п.4.  

### Итерация 5 — Сканер, reorg, хранение ключей и anchor‑hint ([детали](iterations/Phase2_5iteration.md))
**Цель:** стелс‑кошелёк корректно восстанавливает и сопровождает стелс‑UTXO с учётом мастер‑делегаций, устойчив к реоргам и позволяет лёгким клиентам отбрасывать «чужие» якоря.  
- `wallet/core/src/utxo/stealth_handler.rs` / `wallet/core/src/account/variants/stealth.rs`:  
  - привязать каждый стелс‑UTXO к конкретной `DelegationRecord` (anchor + scan/spend pubkeys + DAA‑окно);  
  - при скане помечать выходы вне окна делегации как orphaned (через overlay‑карту `OrphanOverlayMap`, без изменений `UtxoContext`/`TransactionRecord`);  
  - добавить хук `StealthUtxoHandler::on_daa_score_changed` и реализовать его в `StealthAccount` для DAA‑чистки и отслеживания истечения делегаций.  
- `wallet/core/src/storage/ephemeral_keys.rs`:  
  - расширить `EphemeralKeyEntry` полями `created_daa_score`, `delegation_id`, `master_anchor`, `valid_until_daa` и статусами `Orphaned { OrphanReason }` / `Expired` (через `#[borsh(default)]` без смены формата контейнера);  
  - реализовать `cleanup_expired(current_daa_score)` и политику «мягкого удаления» ключей (не терять секрет до выхода за `valid_until_daa` + reorg‑маржа).  
- RPC `get_block_view_tags` / модель `RpcStealthOutputInfo`:  
  - добавить поле `anchor_hint: Option<String>` (первые байты `MasterAnchor`), обеспечить обратную совместимость сериализации (версия `2 → 3`);  
  - прокинуть `anchor_hint` через gRPC/wRPC/WASM.  
- Индексатор `indexes/processor`:  
  - добавить `StealthAnchorHintCache` (in‑memory кэш `(txid, index) → anchor_hint`) и обновлять его на основе UTXO diff и зарегистрированных делегаций;  
  - предоставить API, через которое RPC‑слой запрашивает hint при формировании `get_block_view_tags`.  
- `wallet/core/src/events.rs`:  
  - ввести события `MasterDelegationExpired`, `MasterDelegationRevoked`, `MasterAnchorMismatch` и использовать их при истечении/ревоке делегаций и anchor‑mismatch;  
  - обновить JS/TS биндинги и WASM‑слой.  
- UX/Generator:  
  - интегрировать overlay orphaned‑UTXO с генератором трат так, чтобы такие входы **никогда не попадали** в автоматические платежи без явного действия пользователя, но были доступны в отдельных ручных сценариях (consolidate/spend‑orphaned).  

### Итерация 6 — Оффлайн UX и аппаратные кошельки
- CLI: команда `master sign-delegation --input deleg.json --out sig.bin`, которая работает без RPC (использует только шифрованный payload).  
- `wallet/native` (desktop) + `wallet/wasm`: режим «air-gapped» — экспорт `delegation_request.json` (QR / USB), импорт ответа.  
- `wallet/core/src/message` добавить тип `MasterDelegationRequest` (Borsh + serde) для межплатформенного обмена.  
- Документация: `docs/guides/master_cold_storage.md` с пошаговым сценарием + чеклист хранения (HSM/бумага).  
- Добавить e2e-тест `testing/integration/airgap_mldsa.rs`, который проверяет serialize/deserialize request-response.  

### Итерация 7 — Тестирование и формальная верификация
1. **Unit tests:**  
   - `crypto/mldsa`: KAT (из NIST), deterministic derive roundtrip.  
   - `wallet/keys`: ensure anchor uniqueness, zeroization.  
   - `wallet/core/account/mldsa_master.rs`: lock/unlock flow, rotation, serialization.  
2. **Property tests:**  
   - `delegation`: подделка подписи → отклоняется.  
   - `stealth account`: при истёкшей делегации кошелёк не создаёт новые change адреса.  
3. **Integration tests (`testing/integration`)**  
   - Поднять 2 ноды + wallet-daemon:  
     1. Создать master, связать stealth, отправить tx, убедиться что restore через seed + anchor повторяет баланс.  
     2. Reorg > valid_until → кошелёк требует переподписать делегацию.  
4. **Fuzzing:**  
   - `wallet/core` harness, который рандомно реверсирует события unlock/lock/rotate.  
   - MLDSA signature corpus (размер 2.4 KB) → тест на переполнение/DoS в RPC.  

### Итерация 8 — Развёртывание и миграция
- `docs/MIGRATION_STRATEGY.md`: раздел «Сценарий обновления до MLDSA-root».  
- `consensus/params.rs`: флаг `enable_mldsa_master` с высотой активации (по умолчанию true в новой сети).  
- Release checklist (`docs/FINAL_CHECKLIST.md`): добавить пункты про master backups и CLI regression.  
- Коммуникация: подготовить `docs/PRIVACY_AND_QUANTUM_STRATEGY.md` changelog (что Phase 2 активирован).  

### Итерация 9 — Kasplex L2 / внешние интеграции
- `docs/KASPLEX_INTEGRATION_GUIDE.md` + `docs/KASPLEX_L2_COMPATIBILITY.md`: обновить примеры, чтобы релейер запрашивал anchor/делегацию через RPC.  
- `kasplex/evm-l2-relayer`: внедрить `mldsa_derive_keypair` из FFI и хранение anchor (отдельный PR, но описать зависимость).  
- `kasplex-syncer`: проверить, что MLDSA адреса корректно декодируются (payload 1312 байт).  
- Публиковать anchor через REST (если партнёры не сидят на Kaspa RPC).  

### Итерация 10 — Observability & Telemetry
- `wallet/core`: добавить `MasterMetrics`/`MasterMetricsSnapshot` и variant `MetricsUpdate::MasterMetrics`, чтобы экспортировать `wallet_master_*` счётчики (sign/rotate/delegations/airgap/healthcheck) через `Events::Metrics`, не меняя `metrics/core` и формат `GetMetricsResponse`.  
- `wallet/core` + `notify`: новое событие/уведомление `MasterDelegationExpiringSoon` и watcher `DelegationExpiryWatcher`, слушающий рост `DAA` и заранее предупреждающий об истечении делегаций.  
- Логи: тег `master_anchor=<hex8>` при всех операциях мастера, делегаций и airgap‑флоу, чтобы было проще искать инциденты в Elastic/Grafana Loki.  
- Докер-образ `docker/Dockerfile.kaspa-wallet`: включить `ENABLE_MLDSA_MASTER=1`, добавить healthcheck для airgap‑сервиса на базе `kaspa-wallet health --mode=airgap`.  
- Статус: реализованы master-метрики, watcher `DelegationExpiryWatcher`, событие `MasterDelegationExpiringSoon` (с `current_daa_score` и `warn_window_daa`), healthcheck и Docker/compose флаги; notify расширен новым `EventType`. Выкат отложен: гейтинг TLV по сетевому флагу, мост notify и доп. тесты (метрики/watcher) отлаживаются, не включаем сейчас.  

## 2.1. Кросс-компонентные зависимости

1. **Consensus ↔ Wallet:** флаг `enable_mldsa_master` должен быть включён перед выкладкой новых кошельков, иначе RPC не выдаст anchor-метаданные.  
2. **Wallet ↔ Kasplex:** relayer и syncer обязаны обновиться до версии, где `mldsa_ffi` экспортирует `derive_keypair`; планируем совместный релиз.  
3. **Wallet ↔ RPC Clients:** `kaspa-wrpc-client` и `kaspa-grpc` требуют новых protobuf/IDL для `register_mldsa_anchor`.  
4. **Docs/Comms:** `docs/PRIVACY_STRATEGY.md`, `docs/PRIVACY_AND_QUANTUM_STRATEGY.md`, `docs/FINAL_CHECKLIST.md` должны быть синхронизированы в том же PR, чтобы не было расхождений в roadmap.  
5. **CI/CD:** pipelines, которые собирают `wallet` и `kaspa-wasm`, обязаны передавать `--features mldsa-master` и прогонять airgap тесты.  

## 2.2. Пошаговый план по итерациям

### Итерация 0 — Подготовка & UX фиксация ⏳ ([детали](iterations/Phase2_0iteration.md))
- **Статус:** НЕ ЗАВЕРШЕНО  
- **Цель:** зафиксировать требования, окружение и UX до начала кодинга, чтобы следующие итерации не превратились в поиски форматов или разбирательство с инфраструктурой.
- **Тезис:** подготовить окружение/доки/флаги до начала разработки.
- **1. Инвентаризация исходников (добавить подпункт в разделе 0):**  
  - `crypto/mldsa/*` — уточнить текущие уровни FIPS‑204, наличие HKDF/детерминированной деривации и тестов (см. `src/{keypair.rs,sign.rs,params.rs}`).  
  - `wallet/keys/src/derivation/gen0/{mod.rs,hd.rs}` — зафиксировать, какие `DerivationPurpose` заняты, где добавится `MldsaMaster=734`, и какие helper’ы (`WalletDerivationManagerV0::build_derivate_path`) нужно расширить.  
  - `wallet/core/src/{account/variants/stealth.rs,tx/generator/stealth_signer.rs,storage/account.rs}` — описать, какие поля payload’а появятся (anchor, delegation_id) и где проверять делегации перед spend.  
  - `rpc/core/src/api.rs` и связанные `kaspa_rpc_core::message` — перечислить существующие методы для stealth/view tags, чтобы на их примере описать будущие `register_mldsa_anchor` и `list_mldsa_delegations`.  
  - `consensus/core/src/config/params.rs` + `consensus/src/params.rs` — обозначить места добавления `ForkedParam<bool>`/`enable_mldsa_master`, требования к активации для devnet/testnet/mainnet.  
  - `.github/workflows/{ci.yaml,deploy.yaml,mldsa-tests.yml}`, `check`, `Dockerfile.test`, `docker/Dockerfile.kaspa-wallet` — отметить, какие job’ы переводим на nightly и где нужен `RUSTFLAGS="-C debug-assertions"` во время разработки.  
  Все пункты описываются прямо в разделе 0, чтобы перед Iteration 1 был список ссылок на критичные файлы.
- **2. Документация и требования:**  
  - Обновить `[docs/plans/PRIVACY_STRATEGY.md](docs/plans/PRIVACY_STRATEGY.md)` и `[docs/PRIVACY_AND_QUANTUM_STRATEGY.md](docs/PRIVACY_AND_QUANTUM_STRATEGY.md)` — добавить ссылку на текущий план, уточнить роль MLDSA master (root of trust → делегации).  
  - В `[docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md)` занести строчку «Phase 2 (MLDSA master plan) — In progress, Iteration 0».  
  - Создать скелет `docs/api/MLDSA_MASTER.md` (или расширить общий `docs/API.md`): структура документа, что фиксируем (формат `anchor`, TLV делегации, RPC payloadы, схемы JSON/Borsh, ссылка на будущие типы `kaspa_rpc_core`).  
  - Согласовать ответственность за поддержание API-дока (wallet core ↔ Kasplex ↔ RPC).
- **3. Toolchain и smoke-тесты:**  
  - Добавить/обновить корневой `rust-toolchain.toml` → `channel = "nightly-2025-01-xx"` (точная дата фиксируется в этой итерации).  
  - Правки в `check` скрипт и `Dockerfile.test`: все `cargo` вызовы выполняются через `cargo +nightly …`, включён `RUSTFLAGS="-C debug-assertions"`, для wasm-целей добавить `rustup +nightly target add wasm32-unknown-unknown`.  
  - В `.github/workflows/{ci.yaml,deploy.yaml,mldsa-tests.yml}` прописать nighty-инсталл, чтобы Step «Install stable toolchain» заменился на «dtolnay/rust-toolchain@nightly» и прогонял `cargo +nightly`.  
  - Smoke-команды, которые должны зелено проходить до старта Iteration 1:  
    1. `cargo +nightly check --workspace --tests --benches`  
    2. `cargo +nightly test -p kaspa-wallet-core --no-default-features`  
    3. `cargo +nightly test -p kaspa-mldsa --release`  
    4. `cargo +nightly clippy --workspace --tests --benches -- -D warnings`
- **4. Флаги и конфиги:**  
  - Внести в план описание будущего флага `enable_mldsa_master`:  
    - `consensus/core/src/config/params.rs` — новый `ForkedParam<bool>` (например, `mldsa_master_enabled`) с активацией `ForkActivation::always()` для devnet и `ForkActivation::never()` до релиза в mainnet.  
    - `consensus/src/params.rs` — передать значение флага в дочерние структуры и экспортировать в `kaspa-consensus` (для RPC).  
    - `wallet/core/src/settings.rs` — новый ключ `WalletSettings::EnableMldsaMaster`, дефолт true, чтобы кошелёк мог отключаться в тестах.  
    - В docker/composed окружениях (`docker/Dockerfile.kaspa-wallet`, `docker-compose.test.yml`) прописать env `ENABLE_MLDSA_MASTER=1`, а в README — инструкцию для временного выключения (devnet troubleshooting).  
  - Зафиксировать временные DAA-высоты: devnet = сразу, testnet = +200k DAA, mainnet = TBD (добавить ссылку на обсуждение).
- **5. Выходные артефакты и трекинг:**  
  - Issue tracker: создать epic «Phase2 — MLDSA master» + подзадачи на каждую итерацию (ссылка на Notion/Jira).  
  - PR: единый «Iteration 0 prep» c изменениями в документации + toolchain.  
  - Матрица ответственности в этом файле: кто правит docs (команда strategy), кто обновляет CI (infra), кто владеет Kasplex интеграцией.  
  - Критерии готовности: docs обновлены и сослались на план, nightly включён в локальных и CI сборках, черновик `docs/api/MLDSA_MASTER.md` создан, enable-флаг задокументирован, smoke-команды зелёные.
- **Проверки:** утверждённый API-док + расписанная ответственность, nightly toolchain реально используется во всех сборках, roadmap согласован с Kasplex.  
- **Выходы:** PR/issue-трекер, список файлов и задач в разделе 0, отчёт о smoke-тестах.

### Итерация 1 — Детерминированный MLDSA master ✅ ([детали](iterations/Phase2_1iteration.md))
- **Статус:** ВЫПОЛНЕНО  
- **Шаги:**  
  1. [x] Добавить HKDF-деривацию и `MasterSeed` в `crypto/mldsa`.  
  2. [x] Пробросить новый API в `crypto/mldsa-ffi`.  
  3. [x] Обновить `wallet/keys` (derivation purpose + расчёт anchor, публичные методы).  
  4. [x] Сгенерировать KAT/prop-тесты (Rust + PQClean сравнение).  
- **Проверки:** `cargo test -p kaspa-mldsa` (52 теста), `cargo test -p kaspa-wallet-keys mldsa` (5 тестов) — зелёные.  
- **Выходы:** `crypto/mldsa` с детерминированной деривацией, `MasterAnchor` API.
- **Тезис:** единый MLDSA master из одного BIP39 seed на всех устройствах.

### Итерация 2 — Хранение и шифрование master ✅ ([детали](iterations/Phase2_2iteration.md))
- **Статус:** ВЫПОЛНЕНО  
- **Шаги:**  
  1. [x] Расширить `PrvKeyData` и миграции хранилища (`STORAGE_VERSION = 1`).  
  2. [x] Добавить FFI/wasm представления и CLI-команды управления anchor.  
  3. [x] Включить zeroize/обнуление для всех payload'ов, покрыть тестами.  
  4. [x] Реализовать `change_secret` с перешифрованием master seed.  
  5. [x] Добавить RPC transport handlers (клиент + сервер).  
  6. [x] Обновить документацию `docs/api/MLDSA_MASTER.md`.  
- **Проверки:** `cargo test -p kaspa-wallet-core storage::local::payload` — зелёные; миграция v0→v1 работает.  
- **Выходы:** Storage layer готов, CLI/WASM/FFI биндинги реализованы, события и API задокументированы.
- **Тезис:** безопасно хранить/мигрировать master seed/anchor, покрыть интерфейсы.

### Итерация 3 — Master Account и metadata ✅ ([детали](iterations/Phase2_3iteration.md))
- **Статус:** ВЫПОЛНЕНО 
- Подробности: Phase2_3iteration.md 
- **Шаги:**  
  1. [x] Реализовать `MldsaMasterAccount` (unlock, sign, rotate, хранение `master_pubkey`).  
  2. [x] Обновить `wallet/core/src/wallet` и UI/CLI для привязки stealth ↔ master.  
  3. [x] Настроить события/notify и сохранить anchor/ссылку на master в payload'ах stealth.  
- **Проверки:** unit-тесты аккаунта, CLI сценарий `account create mldsa-master`, attach/detach.  
- **Выходы:** новый account kind + обновлённые UX-гайды.
- **Тезис:** оформить master как отдельный аккаунт с метаданными/ротацией.

### Итерация 4 — Делегации, RPC и сигнатуры ([детали](iterations/Phase2_4iteration.md))
- **Шаги:**  
  1. Добавить `DelegationRecord`, хранение и сериализацию.  
  2. Внедрить TLV `delegation_id` в `StealthSigner` и `EphemeralKeyData`.  
  3. Расширить RPC (wrpc/grpc) методами регистрации/запроса anchor.  
  4. Обновить CLI/SDK поток `link-stealth-to-master`.  
- **Gate по консенсусу:** приём `signature_script.len() >= 65` для stealth-входов и игнорируемый TLV включается **только** при `kip10_enabled = true`; при `kip10_enabled = false` остаётся строгое `len == 65`. Это нужно учитывать в rollout devnet/testnet/mainnet.
- **Проверки:**  
  - `cargo test -p kaspa-wallet-core delegation::tests` — Borsh/serde, CRDT и подписи мастером.  
  - `cargo test -p kaspa-wallet-core ephemeral_key` — миграции `EphemeralKeyEntry` + сохранение делегаций.  
  - `cargo test -p kaspa-wallet-core stealth_signer::` и `cargo test -p kaspa-wallet-core test_generator_include_delegation_id_toggle` — TLV-префикс и смешанные входы.  
  - `cargo test -p kaspa-txscript stealth_transactions` — переменная длина `signature_script` и TLV-парсер (Phase 2 gate `kip10_enabled`).  
  - `cargo test -p kaspa-testing-integration mldsa_master::test_mldsa_master_delegation_flow -- --test-threads=1` — полный master → delegation → spend сценарий (перед запуском выставляем `KASPA_DISABLE_STEALTH_POLICY=1`, чтобы mempool разрешил легаси UTXO).  
  - `cargo test -p kaspa-testing-integration rpc_tests::sanity_test -- --test-threads=1` — smoke RPC на новых методах.  
- **Выходы:** синхронные PR в rusty-kaspa (L1) и Kasplex (L2), обновлённые protobuf/IDL.
- **Тезис:** формализовать делегации от master к stealth и провести их через RPC/CLI.

### Итерация 5 — Сканер, reorg, indexer ([детали](iterations/Phase2_5iteration.md))
- **Шаги:**  
  1. Расширить `StealthUtxoHandler` и `EphemeralKeyStore` дополнительными полями (`anchor`, `valid_until`).  
  2. Обновить RPC `get_block_view_tags`, добавить `anchor_hint`.  
  3. Настроить indexer/processor кэш для ускоренного сканирования.  
- **Проверки:** симуляция reorg > valid_until, проверка что UTXO помечаются и удаляются корректно.  
- **Выходы:** PR с изменениями UTXO handler + документация по новому RPC полю.
- **Тезис:** устойчивый скан/реорг с учётом master/anchor и подсказок для быстрого фильтра.

### Итерация 6 — Airgap UX ([детали](iterations/Phase2_6iteration.md))
- **Шаги:**  
  1. Реализовать `MasterDelegationRequest/Response` структуры, сериализацию (borsh + serde).  
  2. Добавить CLI и GUI потоки экспорт/импорт (QR/файл).  
  3. Покрыть wasm/native API, добавить примеры в `docs/guides/master_cold_storage.md`.  
- **Проверки:** интеграционный тест `testing/integration/airgap_mldsa.rs`, ручной walkthrough по гайду.  
- **Выходы:** гайд по cold storage, примеры CLI-команд, демо-видео (по желанию).
- **Тезис:** безопасный airgap-процесс экспорта/импорта делегаций без онлайн-рисков.

### Итерация 7 — Тестирование и формальная верификация ([детали](iterations/Phase2_7iteration.md))
- **Шаги:**  
  1. Расширить unit/property/fuzz suite (см. матрицу тестов).  
  2. Настроить `cargo fuzz` таргеты и интегрировать в CI (nightly).  
  3. Провести внешнюю ревизию (AI/эксперты) и зафиксировать findings.  
- **Проверки:** все тестовые таргеты зелёные, отчёт по fuzz run.  
- **Выходы:** тестовый отчёт + обновлённая `docs/TEST_COVERAGE_SUMMARY.md`.
- **Тезис:** усилить покрытие и провести независимую ревизию перед запуском.

### Итерация 8 — Развёртывание и миграция ([детали](iterations/Phase2_8iteration.md))
- **Шаги:**  
  1. Обновить документацию (`MIGRATION_STRATEGY`, `FINAL_CHECKLIST`, changelog).  
  2. Настроить `enable_mldsa_master` в консенсусных параметрах, прогнать devnet.  
  3. Подготовить release-процедуры (backup master, CLI regression).  
- **Проверки:** devnet upgrade rehearsal, список задач в checklist выполнен.  
- **Выходы:** релизная запись, devnet отчёт, инструкции для пользователей.
- **Тезис:** готовим миграцию/релиз с включённым master и чеклистами.

### Итерация 9 — Kasplex / внешние интеграции ([детали](iterations/Phase2_9iteration.md))
- **Статус:** Done — гайды обновлены, FFI контракт зафиксирован (`kaspa_mldsa_*`), REST/RPC описаны, сценарии deposit/withdraw/mixed задокументированы.  
- **Шаги:**  
  1. Внедрить новые RPC в relayer и syncer (Go).  
  2. Провести e2e тесты L1↔L2 с PQ мастером.  
  3. Обновить публичные гайды/SDK Kasplex.  
- **Проверки:** успешный мост Kaspa↔Kasplex с использованием anchor; regression на старых адресах.  
- **Артефакты:** `cargo test -p kaspa-mldsa-ffi --release` (pass); `nm -gU target/release/libkaspa_mldsa_ffi.dylib` показывает master_seed_len/derive/generate/sign/verify и size getters; `target/release/libkaspa_mldsa_ffi.{dylib,a}`.
- **Тезис:** согласованы anchor/delegations для внешних клиентов; FFI/RPC/REST готовы для интеграции Kasplex.

### Итерация 10 — Observability & Telemetry ([детали](iterations/Phase2_10iteration.md))
- **Шаги:**  
  1. Добавить метрики/логи в `metrics`, `notify`, `wallet`.  
  2. Настроить алерты (Grafana/Prometheus) на expiring delegations, anchor mismatch.  
  3. Обновить Dockerfile/helm chart с новыми флагами.  
- **Проверки:** dashboards отображают новые метрики, алерты срабатывают на тестовых событиях.  
- **Выходы:** наблюдаемость включена, healthchecks в Docker, runbook для NOC.
- **Тезис:** обеспечить наблюдаемость и алерты по master/делегациям для эксплуатации.

## 3. Матрица тестов

| Категория | Тесты | Где запускаем |
|-----------|-------|---------------|
| Unit | `crypto/mldsa` deterministic derive; `wallet/core/account/mldsa_master` serialization | `cargo test -p kaspa-mldsa`, `cargo test -p kaspa-wallet-core mldsa_master` |
| Property | `wallet/keys` HKDF collisions (`proptest`), `delegation` signature forgery | `cargo test --features proptest` |
| Integration | `testing/integration/mldsa_master.rs` (full flow) | `cargo test -p kaspa-testing mldsa_master` |
| Fuzz | `cargo fuzz run wallet-mldsa-delegation` (новая target) | nightly CI |
| Airgap | `testing/integration/airgap_mldsa.rs` (export/import) | `cargo test -p kaspa-testing airgap_mldsa` |
| Manual | Air-gap rehearsal, Kasplex bridge dry-run, incident-response tabletop | Release checklist |

## 4. Риски и меры

1. **Key material leakage (офлайн мастер подключают к онлайновому устройству).**  
   – Решение: строгий air-gap flow, CLI экспорт/импорт, zeroize, предупреждения в UI.
2. **Несогласованность делегаций между устройствами.**  
   – Решение: хранить делегации как CRDT (последняя подпись с наибольшим `nonce`). Добавить RPC `wallet sync-master`.  
3. **Reorg → истёкшая делегация.**  
   – Решение: `valid_from_daa` и `valid_until_daa` + проверка на уровне `StealthAccount::scan`.  
4. **DoS большими подписями.**  
   – Решение: лимит размера `DelegationRecord` в RPC, проверки в `consensus/core/src/model/tx/mod.rs`.  
5. **Сложность UX.**  
   – Решение: wizard в CLI/GUI, автоматический выбор мастера, подсказки в `cli help`.  
6. **Anchor mismatch / forked devices.**  
   – Решение: `delegation_nonce`, синхронизация через RPC + CRDT merge; предупреждения `MasterAnchorMismatch`.  
7. **FFI дрейф (Kasplex relayer).**  
   – Решение: `mldsa_ffi` версиять по SemVer, добавить CI, который собирает relayer с новой библиотекой.  
8. **Airgap компрометация.**  
   – Решение: криптографически подписывать `delegation_request` (вложенный hash), проверять checksum перед импортом.  

## 5. Definition of Done

- ✅ `cargo test` + property + integration suite зелёные.  
- ✅ Документация: этот файл + гайды обновлены.  
- ✅ CLI/SDK поддерживают экспорт/импорт анкера и офлайн-подпись.  
- ✅ Recovery rehearsal: восстановление кошелька из сид-а ↦ совпадает anchor, делегации переизданы.  
- ✅ Security review: независимый аудит подтвердил, что master не утекает в ончейн/сеть.  
- ✅ Telemetry/alerts: метрики и оповещения по anchor/делегациям в графане.  

После выполнения всех шагов Phase 2 считается завершённым, и можно переходить к конфиденциальным суммам (L2) без риска для текущих пользователей.

