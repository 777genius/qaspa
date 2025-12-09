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

## 12. Master account runtime (Iteration 3)

- Account kind `kaspa-mldsa-master` зарегистрирован в фабрике (`AccountKind::from_str("mldsa-master")`).
- Payload v1 (`MldsaMasterAccountPayloadV1`): anchor, pubkey, level, created_at_daa, status (`Active/Rotated/Revoked`), delegations (зарезервировано).
- Статусы и подпись:
  - `MldsaMasterAccount::unlock_with_master_seed(seed, level)` проверяет anchor и кеширует ключ.
  - `sign_message(domain, payload)` с domain separation (`anchor-export`, `delegation`, `custom:...`) и включением anchor в подписываемый префикс.
  - `rotate_master_account(wallet_secret, account_id, level?, new_master_seed?)` обновляет anchor/pubkey, хранит новый seed cipher и эмитит `MasterAccountRotated`.
- Wallet API / CLI / WASM:
  - `create_account_mldsa_master`, `list_master_accounts`, `get_master_by_anchor`.
  - `attach_stealth_to_master` / `detach_stealth_from_master` (stealth payload v1 содержит `master_anchor`, `delegation_id`).
  - CLI: `account create mldsa-master`, `account attach-stealth`, `account detach-stealth`; события транслируются через notify.

## 13. Test-векторы MasterDelegation (Iteration 6)

- Генерируются и проверяются в `message::tests::master_delegation_test_vectors` (`wallet/core/src/message.rs`). Должны совпадать бит‑в‑бит в Rust/wasm/native.
- `request_id`: `ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300`.
- `delegation_request` (borsh hex):
  `01cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab020200010000000102cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab0000000000000000000000000000000000000000000000002a000000000000002222222222222222222222222222222222222222222222222222222222222222333333333333333333333333333333333333333333333333333333333333333340e20100000000000148e8010000000000070000000000000000fbb41d6700000000ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300`
- `delegation_request` (JSON):
  ```json
  {
    "version": 1,
    "masterAnchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
    "masterLevel": 2,
    "networkId": "devnet",
    "delegations": [
      {
        "version": 1,
        "level": 2,
        "anchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
        "accountId": "0000000000000000000000000000000000000000000000002a00000000000000",
        "spendPubkey": "2222222222222222222222222222222222222222222222222222222222222222",
        "scanPubkey": "3333333333333333333333333333333333333333333333333333333333333333",
        "validFromDaa": 123456,
        "validUntilDaa": 125000,
        "nonce": 7,
        "status": "Active"
      }
    ],
    "createdAtUnixtime": 1730000123,
    "requestId": "ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300"
  }
  ```
- `delegation_response` (borsh hex):
  `01cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab02ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300010000000102cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab0000000000000000000000000000000000000000000000002a000000000000002222222222222222222222222222222222222222222222222222222222222222333333333333333333333333333333333333333333333333333333333333333340e20100000000000148e801000000000007000000000000000074090000379f50f583e4621d121565404ec423059ce1ab401d2a567608bfb5d5c82b338a404d9c460332d786b6b5af9f3f97287e72659c1806083024d34f397a14d0f78acbddff4348ab7a996a14dab0e9e826becec95516af209072d4973032e3cfc7fd791f5322695a52c674138429f78c22a07de7e200ad7a4bbc692577525f60c2be382cc317f75f60b2d219758daf94055671ec4353ff08ee7eaf42beb243d59d0907059b405773d49c0f5981ee32aed7617d866d27c7f2ef9069f481be1faa476e255e4dc3072655ad84171ed0fe4caf8bf37f7a93fa4f21ca36ebc3cf5beebdc4dc5aadc302adcf926a1027853b7d3d3c24c28ab750b3bb2631d66883528fcac56b23246f4350a8f22dc60e57b6e550a3fcba74f6df266498ea635f2b7fe3d13f4ab9b4710c3695ea06719201e33c2fc0b9a23aee287cb8d2250d9c7462252b6ad7fcbd05f93c4aaa34285d7e40eb17ff69fd2950db0f887f1e14edb7a95ddf6307e5b9baa8810fa17943ee7a4559cbd87b1f77ec78876f12f08091126de7c7c43f0447ef3391feef679e6fe89da9d1857dd88e109868c05a1567be260a37cdd277c27a8fa2f72d1260860233d5e507fbc84d88bf900fd9077bcb5f796c923ac2374d35486cbd72e4063bee4340101c6251a74b16b03077f6765f462c0236b6a142dc03f49e69e6e41f8f8161ea5d2fa6b7524f11b7be14208edccdb42d3684e4bf8e72fec6dc8865b3c3329b3ea5f4e659535675378bbc4f66c8e0f346c0cc71e75995923cc880855338af2af9856685c777d4be8973574bf2f9b75eb991f563bdd2910be9b8c2d42b665a4ef585a9cc00fc457454515d859f4e01ccce41b0ebedbe6f038ba2a6621b0a932c3b1ee2ff8a8b39f5b8267eb006646e9785af0a1557ffe419725b42020aca59ae09204dcc246fba0d70754a96eaf3e76d79598c5b91ccce1abd597cc6b2a7370236ee96f891865579292e01bd099b8a9a7fc3aa3b05d63aebb29879409cae07e37cb0ba4af0385c32362c0b2e43cabac6b69055193859af573c614c232adcb96d013861bfc2c5369290f672bcd0ed8ca9d2a9c05f1f5be7b1228e730fe3a5e8caddf105083189d033037d4c4911bb8812f1831b5ab2594c449135b98ac9fdcfa16dde57172fad7454ea3becc60f5e20efa6c27e9f353be76ddc7d6a88ebc36228e2bf464cc38f31f35322c6be0f8cc03ec9f6a269fbb640bc282220ab0d0176b4a2945a5fbf88c98d2640e8b92f163bb26a2e94ff8e44a8f188c68def02d11591db60e9c14acbba46db3be18367309f19786de6eb7e1f3730d89d40c06759a574b0804e9aedfffd9e64143189e9a81bd906379ff5c3034a3e30bf74b1147b99371be754e015a6120fe280403267f50b004e57e05ca498ec82eaa4d6860f4ac004c1abcad336e1912c5743e3a73aa62cea3093cfad5adf4da8e6b7689fad3f8ce42055da0316786d64ae6304ed9d1dc6421d744b667723e02258389fe4a467a8a199c6f03e3753a0b9f0559ee8ba55928b5cc9288235eb72a25f871e10655e8a3ba37278858ba4c51fce0ab50aa08b62d86d4944f009a40bb8dd1ffcb20fea3295839d8c11987ab99271371e9db0dd5db93aeb5e1358381530030a9ccc98518388d066c3c28997fd902f1aa8ae17bd625d78a31d026e4c41a36acb68c8b5264b629c77bbdb1d674adf5f0cdd7260febe8654de04f32de27a52f2c95083f7966221652cafbf0d73addb03b163cf4b7418971fa5b56f7fad690e0f2c3f0f34a8b9e2d3b8acf6212e74d9bab4ce7bece2d4e28d0a475bf2527673fcb5f02ff4db4ad2e8567cb743441f2f4b43996e2847d5f382aa59d505a57691d72637c4caf2aca16a23fbd57d17ef2b0bad0a3df3d62a1013d6fc7ed6150920a040e06517cf84279cec0046985208c68059e61ca3284e8c809331b457fa1e1fe70ef65b2eee50b13dddd802a343868426086ab3f923b9001a2e5f076c7f92f2aaa109380f5fd44c975374292ff2139baae6f3c2619089f7fae9bbd9e89b5c1f078da55cd95262447519156d9e493d231b2e373249968c1af15cfca38caeaed07c78f3d96a8bd800aedf42aa85ed1d9c7c9b0cee9f5c9c2b311e4d294276475eeed8e1a75bf6e5079a997728036714217c67b1d67bcf79157e139f271334bb5fdf435728b181e3276a7a9c4b9349811d5f3990918b7d368583a66660d277eaae37189228c2f10b39acb6c50f0b9eb925972c7a47b6010e06e0bfcaffe6c35187b21125f464cabe0927201e02f7e9e49fe313651abc9687357530f99a3148e19e405aefcd347d6fd506609122893628b964190f33e12b265f4d0c70ed0755bc9de95e02f314ea21c541c4c5678220ac45d62ca3df6817ecbe087e9f0d4abd5e8a826bb2f5c695f1c83fbb36463155b99257e96bf28c2e8ce2b6f6758ed0fafe91d434e9bc9f4e4e39e7e4f4e63613dd0f6d81ba1c794b18ab8d42cd66c3cbad866d09902c37dddb597b93d6d6ae9ef98fa969a9b148e704db1d3575ca10a339e771051f70ba5629fd47ccd580a0d830808bc218449d32b54cd8fec9f1bfd77bd41a8bd2f422ec15de5a86f586238409de5b152eee2ac7ca317c4230d287d174ab8dbc13f485f8883199e6a854973b36906950d15aa5be0cc15ba5fb70d6a3469dede55eb857115edc170e410c63e75defb54efd6c62403b7b5ba7fe95ae9cf84c6ce16bd3ac4a76f04d8b695b2965bfad62f063a3dda3f6bc37827103492aa32a02d8957ae76ad2212c03a962cfebc1ce740cac079eb119e637af66ea7be6539b58565946271423864178f3dceebee81f089d02a2a162da7f9dc7c1cae72040dacff217fe4c5e96285ea90a37aaac9e942c183b721ae3ee70fb49d8e73d167bf4f61db78cdba87ffcc5c36d5d480ae8d02c4d289ede6a493e7f9839293d66d386ebaea79e265c9339d895a6915c3e661dcd08ecddd76ebda8201059b44524e1a952e18c676080be3dba54a65f2090692cc5efff45b504fcee54afa69f8b38d51a8cf04350145521e49e77c49772ae05b5653bcb617e775efd06ed7882a85fb1d26fcb0e61b36e65886b85c8e9845a7621bbc136abb3c8067365de463e6b05bc4eda74903f8ba4fd1f45c93519892ffa84201c64cef5fa73c17b956f71205fcb35ff71fffd30d1cf0c96611894eea8d289d0acc66f42200b51c60f5b6b96250a9484643cc152399c41a7b978f5f8e997da5582d4e328115e50c7bcec53f51db289139f180a9ad882b2ff2de9c539d87a005d9a68c2582062c9d1eae7a906101518373947637c8ab8bdc1ced6dcdfe0eb303350576e6f717f8ad3e020454d555b647f8e94a3aeb3b6dbdcfa37404c4e597682838b8c9698999fbac9e1ef00000000000000000000000000000000131e2e40`
- `delegation_response` (JSON):
  ```json
  {
    "version": 1,
    "masterAnchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
    "masterLevel": 2,
    "requestId": "ee063eeea59f670059874ca39d001523c22581e43f0184c92b265f1832937300",
    "delegations": [
      {
        "version": 1,
        "level": 2,
        "anchor": "cb4b9f11e5d7663bc947ca831f9eb6b1c466bcbf5b818526b3e54c284731d6ab",
        "accountId": "0000000000000000000000000000000000000000000000002a00000000000000",
        "spendPubkey": "2222222222222222222222222222222222222222222222222222222222222222",
        "scanPubkey": "3333333333333333333333333333333333333333333333333333333333333333",
        "validFromDaa": 123456,
        "validUntilDaa": 125000,
        "nonce": 7,
        "status": "Active",
        "signature": "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"
      }
    ]
  }
  ```

