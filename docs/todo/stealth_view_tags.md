# Stealth View Tags Roadmap

Цель: закрыть критичные пробелы для devnet-интеграции stealth аккаунтов — историческое сканирование и потоковую доставку view tags. План рассчитан на senior+ исполнение и описывает конкретные файлы, структуры и проверки.

---

## 1. RPC `get_block_view_tags` (исторический доступ) — ✅ выполнено

### 1.1. Скоуп и API
- **Назначение:** лёгкий клиент должен получить все stealth-outputs конкретного блока, не загружая целый блок/txlist.
- **Параметры запроса:** `block_hash` (или `block_blue_score` на будущее, но для MVP достаточно хеша).
- **Ответ:** массив `RpcStealthOutputInfo { transaction_id, output_index, view_tag, destination_pubkey }` + метаданные (хеш, daa_score).

### 1.2. Конкретные изменения
| Файл | Действие |
|------|----------|
| `rpc/core/src/model/message.rs` | Добавить `GetBlockViewTagsRequest/Response`, `RpcStealthOutputInfo`. Реализовать (де)сериализацию в стиле остальных RPC. |
| `rpc/core/src/api/rpc.rs` | Добавить методы `get_block_view_tags` / `_call`. Учитываем safe-mode ограничения (как `get_block`). |
| `rpc/service/src/service.rs` | Реализовать обработчик: 1) проверить `utxoindex`? **Нет**, достаточно консенсуса. 2) загрузить блок (`session.async_get_block`). 3) Для каждой tx/output, если `script_public_key.version() == STEALTH_SCRIPT_VERSION`, вызвать `kaspa_txscript::extract_stealth_output`. 4) Собрать `view_tag` и `destination_pubkey` (32 байта) + tx hash + index. 5) Вернуть `GetBlockViewTagsResponse`. |
| `rpc/grpc` + `rpc/wrpc` | Добавить новые методы (proto/stub). wRPC: обновить client/server + wasm bindings. |

### 1.3. Псевдокод ядра
```rust
fn extract_stealth_outputs(block: &Block) -> Vec<RpcStealthOutputInfo> {
    block.transactions.iter().flat_map(|tx| {
        tx.outputs.iter().enumerate().filter_map(move |(idx, out)| {
            if out.script_public_key.version() != STEALTH_SCRIPT_VERSION {
                return None;
            }
            let ephem = extract_stealth_output(out.script_public_key.script()).ok()?;
            Some(RpcStealthOutputInfo {
                transaction_id: tx.id(),
                output_index: idx as u32,
                view_tag: ephem.view_tag,
                destination_pubkey: ephem.destination_pubkey.serialize(),
            })
        })
    }).collect()
}
```

### 1.4. Тесты / валидация
1. **Unit:** `extract_stealth_outputs_from_block` покрыт тестами сериализации в `rpc/core`.
2. **Integration:** e2e сценарий в `testing/integration` подтверждает корректность ответа RPC.
3. **Backwards compatibility:** bump serializer version выполнен; старые клиенты игнорируют новое поле.

---

## 2. Потоковая передача view tags (`BlockAddedNotification`) — ✅ выполнено

### 2.1. Цель
Уменьшить latency для клиентов → как только блок появится, клиент (при желании) получает view tags без запроса к RPC. Следуем существующему паттерну `include_accepted_transaction_ids`.

### 2.2. Изменения по слоям
| Слой | Детали |
|------|--------|
| **RPC модель** | Расширить `NotifyBlockAddedRequest` флагом `include_stealth_outputs`. В `BlockAddedNotification` добавить `stealth_outputs: Option<Vec<RpcStealthOutputInfo>>` (используем ту же структуру, что и в п.1). |
| **Notify сервис (`rpc/service/src/service.rs`)** | При формировании `BlockAddedNotificationPayload` вычислять `stealth_outputs` ровно один раз (реюз функции из п.1). Если подписчик не запросил данные → ставить `None`. |
| **Kaspa notify crate** | В `BlockAddedSubscription` хранить флаг `include_stealth_outputs`. Модифицировать `Notification::apply_block_added_subscription`, чтобы он удалял поле для неподписанных клиентов (аналогично accepted tx ids). |
| **wRPC / gRPC** | Обновить схемы (`block_added` event), добавить поле и опциональный флаг в subscribe-команды. |
| **WASM bindings** | Экспортировать новое поле через `wasm_bindgen`. |

### 2.3. Алгоритм генерации
1. `request.include_stealth_outputs` парсится в `BlockAddedSubscription`.
2. При событии `block_added`:  
   a. Блок передаётся в helper `extract_stealth_outputs`.  
   b. Результат либо сохраняется в `Arc<Vec<_>>`, либо пропускается (если ни один подписчик не запросил).  
   c. Для каждого подписчика отправляется копия `BlockAddedNotification`, где `stealth_outputs = Some(data)` или `None`.  
3. Клиентская сторона проверяет поле и обновляет локальный кеш view tags.

### 2.4. Тесты
1. **Notify unit:** `BlockAddedSubscription` покрыт unit-тестами (в том числе `test_block_added_mutation` / `test_block_added_compounding`).
2. **Integration:** `testing/integration/src/stealth_flow.rs` содержит `test_block_added_stealth_outputs` и `test_block_added_without_stealth_outputs`.
3. **Perf:** `Arc<Vec<_>>` переиспользуется для всех подписчиков; повторный расчёт отсутствует.

---

## 3. TODO (отложено)
- **BIP-158 Compact Block Filters** — тяжёлый проект (Golomb-Rice, отдельный индекс). Отложить до тех пор, пока не станут узким местом сети. Включить в эту задачу, когда закончим devnet проверку и потоковые view tags.

> NB: После реализации пунктов 1–2 обязательно обновить `docs/plans/etap3/etap3_2.md` и чеклисты в разделе 10/11.***

