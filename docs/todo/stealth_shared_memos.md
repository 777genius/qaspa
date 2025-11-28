# Stealth Shared Memos / Local Notes Split

Цель — добавить второй тип заметок в кошельке:  
1) **Локальная** (как сейчас) — хранится только в `TransactionRecord.note`.  
2) **Шаримая** — шифруется от общего секрета stealth-выхода и передаётся в самой транзакции, чтобы получатель видел текст сразу после сканирования.

Документ фиксирует инженерный объём и контрольный список для внедрения.

---

## 1. Формат и криптография (kaspa_stealth + kaspa_txscript)
- [ ] Определить новый домен-хеш `StealthMemoKey`: `memo_key = Hash("StealthMemo", S)` где `S = r·PrivScan`.
- [ ] Добавить структуру `StealthMemoPayload { len (u8), bytes (<=32) }`.
- [ ] Расширить `EphemeralOutput` → хранить необязательный хвост `memo`, обновить `to_bytes()/from_slice`.  
  Требуется совместимость: если `len == 0`, поведение полностью совпадает с текущим `[R | tag | P_dest]`.
- [ ] В `pay_to_stealth()` и `extract_stealth_output()` разрешить скрипты длины `STEALTH_OUTPUT_SIZE + memo_len + 1`.
- [ ] `kaspa_txscript::ScriptClass::Stealth` — вернуть `TxScriptError`, если memo повреждён (len>32 либо выход обрезан).
- [ ] Тесты: `crypto/stealth/tests/property_tests.rs`, `crypto/txscript/tests/stealth_transactions.rs` — добавить кейсы с memo.

## 2. Отправка (wallet/core)
- [ ] Добавить `shared_memo: Option<Vec<u8>>` в `PendingTransaction` / `GeneratorSettings`.
- [ ] В `StealthChangeCreator::create_output()` (файл `wallet/core/src/tx/generator/stealth_change.rs`) передавать memo в `create_stealth_output_with_memo`.
- [ ] Минимальный AEAD: Pseudocode  
  ```rust
  let key = memo_key(shared_secret);
  let ciphertext = xor(key, memo); // либо XChaCha20Poly1305 с фикс чанк длиной 32
  ```
  Обозначить в коде, что пока длина ограничена 32 байтами.
- [ ] JS/WASM API: разрешить передавать memo в `transactions_send` (новый аргумент в `TransactionsSendArgs`).

## 3. Получение / сканирование
- [ ] `StealthUtxoHandler::try_claim_utxo` после `scan_output` читать memo хвост, считать `memo_key` и дешифровать.
- [ ] Сохранять результат в `UtxoContext.metadata.shared_memo` → он попадёт в `TransactionRecord` после взрослой синхронизации.
- [ ] При ошибке расшифровки (битый payload) не падать: лог + игнор конкретного memo, сам UTXO принимаем.

## 4. Хранение и API
- [ ] `TransactionRecord` / `TransactionRecordT` расширить полем `sharedNote: Option<String>` (WASM типы, serde).
- [ ] Новые методы сториджа: `store_transaction_shared_note` в `fsio.rs` и `indexdb.rs`.
- [ ] `TransactionsDataGetResponse` автоматически заполняет `shared_note` при чтении.
- [ ] Добавить явный вызов `transactions_replace_shared_note` (аналог для ручной правки, если пользователь захочет отредактировать текст локально).

## 5. UI/SDK
- [ ] Отобразить две области: «Моя заметка» (editable) и «Заметка отправителя» (read-only).
- [ ] В REST/CLI документации подчеркнуть лимит 32 байта и факт шифрования.

## 6. Тестирование
- [ ] Unit:  
  - `StealthSecretKey::memo_key_roundtrip` (encrypt/decrypt).  
  - `TransactionRecord` serde с новым полем.
- [ ] Integration: `testing/integration/src/stealth_flow.rs` — end-to-end: отправитель пишет memo, получатель видит расшифрованный текст, локальная заметка остаётся пустой.
- [ ] Regression: убедиться, что старые выходы (без memo) по-прежнему корректно сканируются и не ломают сериализацию.

## 7. Открытые вопросы
1. Нужно ли позволять memo >32 байт (придётся либо фрагментировать, либо переводить в OP_RETURN)? Пока оставляем лимит.
2. Стоит ли выводить memo в RPC (`get_block_view_tags` / `BlockAddedNotification`)? Технически возможно, но повышает риск утечки. Решение за продуктом.

По готовности каждого блока обновить `docs/plans/phase1/etap3/etap3_2.md` (раздел 11, «Известные ограничения и TODO»), сославшись на этот документ.

