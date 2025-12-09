# Cold storage для MLDSA master: оффлайн делегирование стелс-веток

## 1. Концепция

- **Master** хранится оффлайн и подписывает делегации. Якoрь (`master_anchor`) = BLAKE2b-256(pubkey) с доменом `mldsa-anchor`.
- **Delegation** = подпись мастером на заголовок стелс-ветки (`DelegationRecordHeaderV1`): anchor, account_id, spend/scan pubkey, окно DAA, nonce, status.
- **Request/Response**: `delegation_request.json` (запрос без подписи) → оффлайн подпись → `delegation_response.json` (то же, но с подписями).
- **Checksum**: `request_id = BLAKE2b-256("mldsa-delegation-request" || borsh(body без request_id))`. Оффлайн сторона обязана пересчитать и сравнить.

## 2. Поток «первое делегирование» (online → offline → online)

1) **Online (сеть доступна)**
   - Подготовить делегационные заголовки (stealth-аккаунт уже привязан к мастеру).
   - Построить запрос:
     - API: `wallet.buildMasterDelegationRequest(...)` (WASM/FFI аналоги).
     - CLI: пока основной поток через API/SDK; CLI предназначен для оффлайн подписи и apply.
   - Сохранить `delegation_request.json` или показать QR.

   Пример запроса:
   ```json
   {
     "version": 1,
     "masterAnchor": "a1b2c3d4...",
     "masterLevel": 2,
     "networkId": "simnet",
     "createdAtUnixtime": 1730000000,
     "delegations": [
       {
         "version": 1,
         "anchor": "a1b2c3d4...",
         "accountId": "stealth:abcd1234",
         "spendPubkey": "001122...",
         "scanPubkey": "334455...",
         "validFromDaa": 1000000,
         "validUntilDaa": 1100000,
         "nonce": 1,
         "status": "active"
       }
     ],
     "requestId": "cafebabe..."
   }
   ```

2) **Offline (airgap, без RPC)**
   - Импортировать `delegation_request.json`.
   - Проверить `request_id`, `network_id`, `master_anchor` на экране устройства.
   - Подписать:
     - CLI: `wallet master sign-delegation --input deleg.json --out deleg_signed.json`
     - API: `wallet.signMasterDelegationRequest(...)`
   - Вывод: `delegation_response.json` с подписями.

   Пример ответа:
   ```json
   {
     "version": 1,
     "masterAnchor": "a1b2c3d4...",
     "masterLevel": 2,
     "requestId": "cafebabe...",
     "delegations": [
       {
         "version": 1,
         "anchor": "a1b2c3d4...",
         "accountId": "stealth:abcd1234",
         "spendPubkey": "001122...",
         "scanPubkey": "334455...",
         "validFromDaa": 1000000,
         "validUntilDaa": 1100000,
         "nonce": 1,
         "status": "active",
         "signature": "base64_mldsa_sig"
       }
     ]
   }
   ```

3) **Online (применение)**
   - CLI: `wallet master apply-delegation --request deleg.json --response deleg_signed.json`
   - API: `wallet.applyMasterDelegationResponse(...)`
   - Проверки: совпадение `request_id`, `master_anchor/level`, валидность подписи, окно DAA, monotonic nonce. При успехе делегации пишутся в `DelegationStore`, stealth получает `delegation_id`.

## 3. Ротация и отзыв

- Ротация = новая делегация с большим `nonce`; старая может иметь статус revoke/expired.
- Отзыв: подпись с `status = revoked { revoked_daa }`, `nonce = prev_nonce + 1`; применив, кошелёк убирает активную делегацию из stealth.
- UX: всегда показывать окно DAA и якорь, требовать явного подтверждения. Для тестнет ↔ mainnet использовать флаг `--force-network-mismatch` только осознанно.

## 4. Checklist и риск-модель

- **Валидация файлов:** пересчитать `request_id`; отклонять любые несовпадения полей. Проверять `network_id` и `master_anchor`.
- **Хранение:** файлы не раскрывают сид, но показывают структуру делегаций — держать отдельно от сид-а, избегать публикации.
- **Подпись:** держать мастер на оффлайн устройстве; не писать seed на диск; использовать Zeroizing (уже сделано в core).
- **Повторы:** `request_id` — идентификатор сессии; повторный импорт допустим, если содержимое совпадает, иначе ошибка конфликта.
- **Размеры:** крупные batch-и (>32 делегаций) могут не влезать в один QR; делите на части или используйте файл/USB.
- **Native FFI:** для аппаратных/desktop‑браузеров доступны функции `kaspa_wallet_mldsa_delegation_request_summary`, `kaspa_wallet_mldsa_delegation_response_summary`, `kaspa_wallet_mldsa_delegation_sign[_ex]`, `kaspa_wallet_mldsa_delegation_apply[_ex]` (JSON in/out); версии с `_ex` принимают флаг `force_network_mismatch`.

## 5. Быстрые команды (CLI)

- Подпись оффлайн:  
  `wallet master sign-delegation --input deleg.json --out deleg_signed.json`
- Применение онлайн:  
  `wallet master apply-delegation --request deleg.json --response deleg_signed.json`
- Справка:  
  `wallet master help`

