# MLDSA Master Seed & Anchor API

Документ фиксирует формат мастер-ключа, алгоритмы деривации и публичные API после реализации **Iteration 1**.

## 1. Детерминированный мастер seed

- Источник: `crypto/mldsa/src/master.rs`.
- Формат seed: 48 байт (`MASTER_SEED_LEN`).
- HKDF: `HKDF-SHA3-512`, info = `b"kaspa.mldsa.master"`.
- Функции:
  - `MasterSeed::from_slice(&[u8])` — валидация и zeroize.
  - `derive_keypair_from_seed(seed: &[u8], level: MlDsaLevel)` — детерминированная генерация MLDSA ключа.
  - `derive_keypair_from_master_seed(master_seed: &MasterSeed, level: MlDsaLevel)`.
- KAT: `master::tests::determinism_known_answer_level2` — фиксированные `seed` → SHA3-256(pk|sk) `652f...` / `9a2b...`.

## 2. BIP39 → MLDSA

- Реализация в `wallet/keys/src/keypair_mldsa.rs`.
- Константы:
  - `BIP39_ROOT_SEED_LEN = 64`.
  - Salt: `b"kaspa.bip39->mldsa"`.
  - Info: `b"kaspa.account" || account_index.to_be_bytes()`.
- API:
  - `MlDsaKeypair::from_bip39_root_seed(root_seed: &[u8], account_index: u32, level: MlDsaLevel) -> Result<(MlDsaKeypair, MasterAnchor)>`.
  - `MlDsaKeypair::from_master_seed(master_seed: &MasterSeed, level: MlDsaLevel) -> Result<(MlDsaKeypair, MasterAnchor)>`.
  - `MlDsaKeypair::anchor()` — возвращает `MasterAnchor`.
- Тест: `test_from_bip39_root_seed_deterministic` → anchor `0a816d89...a3f5`.

## 3. Master Anchor

- Тип: `MasterAnchor([u8; 32])`, derive `Serialize/Deserialize`.
- Расчёт: `BLAKE2b-256("mldsa-anchor" || master_pubkey_bytes)`.
- Представление: hex (Debug/Display).

## 4. FFI

- Файл: `crypto/mldsa-ffi/src/lib.rs`, заголовок `crypto/mldsa-ffi/mldsa.h`.
- Новые функции:
  - `size_t kaspa_mldsa_master_seed_len(void)` — возвращает 48.
  - `bool kaspa_mldsa_derive_keypair(const uint8_t* seed, size_t seed_len, uint8_t level, uint8_t* pk_out, size_t pk_len, uint8_t* sk_out, size_t sk_len)`.
- Поведение:
  - Требуется seed длиной 48 байт.
  - Поддерживает уровни 2/3/5.
  - Проверяет размеры буферов и возвращает `false` при ошибках.
- Тесты:
  - `tests::test_derive_keypair_deterministic` — idempotency.
  - Обновлён `example.go`: функции `MasterSeedLen()`, `DeriveKeypair`.

## 5. План используемого API

- `kaspa_mldsa`:
  - `MasterSeed`, `derive_keypair_from_seed`, `derive_keypair_from_master_seed`, `MASTER_SEED_LEN`.
- `kaspa-wallet-keys`:
  - `MlDsaKeypair::from_bip39_root_seed`.
  - `MlDsaKeypair::from_master_seed`.
  - `MasterAnchor`.
- FFI (`mldsa.h`):
  - `kaspa_mldsa_master_seed_len`.
  - `kaspa_mldsa_derive_keypair`.

## 6. Использование в wallet/core (preview)

- Для привязки MLDSA master к аккаунту необходимо:
  1. Получить BIP39 seed (64 байта) из mnemonic.
  2. Вызвать `MlDsaKeypair::from_bip39_root_seed(...)`.
  3. Сохранить `MasterAnchor` и seed (в зашифрованном `PrvKeyData`).
  4. Через FFI доступен тот же функционал для Go/JS (Kasplex relayer).

## 7. Риски и проверки

- Любое расхождение в root seed длине → явная ошибка (return `Error::custom` / `false`).
- HKDF/anchor домены зафиксированы константами, нельзя менять без миграции.
- Все API zeroize внутренние буферы через `MasterSeed`.

## 8. Secure storage & settings (Iteration 2)

- **Формат**: `PrvKeyDataVariant::MlDsaMaster { level: u8, anchor: [u8;32], seed_cipher: Vec<u8> }` из `wallet/core/src/storage/keydata/data.rs`.
- **Шифрование**: `seed_cipher` — результат `encrypt_xchacha20poly1305(master_seed, wallet_secret)`; расшифровка доступна только после ввода пароля (`MlDsaMasterPayload::decrypt_seed`).
- **Zeroize**: `MlDsaMasterPayload`, `PrvKeyDataVariant` и `PrvKeyDataPayload` реализуют `Zeroize`/`ZeroizeOnDrop`, поэтому anchor/seed обнуляются при выгрузке из памяти.
- **Settings**: `WalletSettings::EnableMldsaMaster` (по умолчанию `true`, файл `wallet/core/src/settings.rs`). Флаг позволяет отключить авто‑деривацию для тестовых окружений; CLI добавил команды `wallet master enable/disable`.
- **Storage version**: `wallet/core/src/storage/local/payload.rs` переведён на `STORAGE_VERSION = 1`. При открытии старого кошелька master создаётся лениво после первого `unlock`.

## 9. Wallet API, события и CLI

- **API сообщения** (`wallet/core/src/api/message.rs`):
  - `MasterAnchorListRequest/Response` → возвращает `Vec<MasterAnchorInfo>` (`id`, `anchor`, `level`, `isEncrypted`).
  - `MasterSeedExportRequest/Response` → требует `walletSecret`, `masterId`, `confirmation` (строка `EXPORT`), выдаёт `seedHex`.
- **События** (`wallet/core/src/events.rs`):
  - `Events::MasterAnchorCreated { info }` — эмитится после успешной деривации и сохранения мастера.
  - `Events::MasterSeedExported { master_id, anchor }` — фиксирует каждый экспорт seed.
  - Оба события проброшены в `EventKind`.
- **WASM bindings** (`wallet/core/src/wasm/api/message.rs`, `.../wallet/wallet.rs`):
  - `wallet.masterAnchors()` → возвращает `IMasterAnchorListResponse` без дополнительных аргументов (тот же payload, что печатает CLI `wallet master list`).
  - `wallet.exportMasterAnchor({ walletSecret, masterId, confirmation: "EXPORT" })` → возвращает `IMasterSeedExportResponse { seedHex }` и эмитит `Events::MasterSeedExported`.
  - TypeScript интерфейсы `IMasterAnchorInfo`, `IMasterAnchorListResponse`, `IMasterSeedExportRequest/Response` описаны в `wallet/core/src/wasm/api/message.rs`.
- **CLI UX** (`cli/src/modules/wallet.rs`):
  - `wallet master list` — печатает таблицу `{id, anchor, level, cipher}` и предупреждает, если флаг выключен.
  - `wallet master export <id> [--format plain|json|qr]` — требует пароль + ручное подтверждение `EXPORT`; `--format qr` генерирует ASCII QR (через `qrcode`).
  - `wallet master verify-anchor <hex>` — сверяет локальные записи по anchor.
  - `wallet master enable/disable` — переключают `WalletSettings::EnableMldsaMaster`.

## 10. Native / WASM bindings

- **Native crate** (`wallet/native`):
  - Добавлен `lib.rs` + модули `types.rs`, `runtime.rs`.
  - C‑совместимая структура `KaspaMasterAnchorInfo` (`id`, `anchor`, `level`, `is_encrypted`, `has_anchor`).
  - Экспортирована функция `kaspa_wallet_master_anchor_list(json_ptr, json_len, out_ptr, out_len, written)` — парсит JSON (`MasterAnchorListResponse`) и заполняет массив структур.
- **WASM**:
  - JS API использует прямые методы `wallet.masterAnchors()` и `wallet.exportMasterAnchor(...)` (см. раздел 9). Объекты запроса/ответа соответствуют `IMaster*` интерфейсам.

## 11. Testing

- **Unit tests**: `wallet/core/src/storage/keydata/data.rs` содержит `test_mldsa_master_payload_encrypt_decrypt` и `test_mldsa_master_payload_borsh_roundtrip`.
- **JS bridge tests**: `wallet/core/src/wasm/api/message.rs` проверяет roundtrip `master_anchor_list_response_js_roundtrip` и `master_seed_export_js_bridge`, гарантируя, что wasm-интерфейсы совпадают с CLI-потоками.
- **How to run**:
  ```bash
  cargo test -p kaspa-wallet-core storage::keydata::tests
  cargo test -p kaspa-wallet-core --features wasm32-sdk master_anchor_list_call
  ```
- **CI**: `cargo check -p kaspa-wallet` гарантирует, что новый native crate и CLI собираются вместе.

