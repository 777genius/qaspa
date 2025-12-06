# Phase 2 — Stealth‑only fees & запрет смешивания stealth/legacy

> **Цель:** гарантировать, что **все пользовательские транзакции**, создаваемые нашим стеком (кошелёк + нода), используют **только стелс‑UTXO** в качестве входов (включая комиссию) и **никогда не смешивают** stealth‑входы с любыми legacy‑/публичными UTXO в одной транзакции.

---

## 0. Контекст и формулировка инварианта

### 0.1. Текущий статус

- Стелс‑адреса и скрипты уже реализованы:
  - `wallet/core/src/account/variants/stealth.rs` — `StealthAccount`, деривация ключей, сканирование, `StealthUtxoHandler`.
  - `wallet/core/src/utxo/stealth_handler.rs` — обработка stealth‑UTXO (claim, fallback‑скан, сохранение эфемерных ключей).
  - `wallet/core/src/tx/generator/generator.rs` — поддержка `Version::Stealth` в `Generator`, создание стелс‑выходов.
  - `wallet/core/src/tx/generator/stealth_change.rs` — генерация стелс‑сдачи, pre‑compute spending key.
  - `crypto/stealth/src/lib.rs`, `crypto/txscript/src/script_class.rs` — `STEALTH_SCRIPT_VERSION`, `ScriptClass::Stealth`.

- Стелс‑UTXO на стороне кошелька уже изолированы:
  - `StealthAccount` и `StealthUtxoHandler` работают **только** с выходами, у которых  
    `script_public_key.version() == STEALTH_SCRIPT_VERSION`.
  - Сканирование через `get_utxos_by_script_version` и fallback по `get_block_view_tags`
    целенаправленно ищет только стелс‑скрипты.

### 0.2. Целевой инвариант

**Желаемое свойство для новой сети с чистым стелс‑генезисом:**

1. **На уровне кошелька:**
   - Любая транзакция, которую строит `wallet-core`:
     - либо использует **только стелс‑UTXO** во входах (включая комиссию),
     - либо (в редких, строго контролируемых случаях) только legacy‑UTXO,
     - но *никогда* не содержит одновременно stealth‑ и legacy‑входы.

2. **На уровне ноды / mempool:**
   - При включённой политике:
     - mempool **отклоняет все транзакции с non‑stealth входами**;
     - mempool **отклоняет все транзакции с non‑stealth выходами** (кроме специальных системных кейсов, если будут нужны).
   - Даже кастомные кошельки не смогут протолкнуть в сеть смешанные tx.

3. **Модель угроз:**
   - Как только монета попала в стелс‑UTXO, её дальнейшее движение (включая комиссию)
     происходит только через стелс‑адреса.
   - Ончейн‑граф не даёт связать стелс‑входы с публичными адресами через одну транзакцию.
   - Любая связь возможна только через off‑chain каналы (биржи, KYC, логи, сетевые метаданные).

---

## 1. Область изменений и файлы

| Подсистема      | Файлы                                                                 | Изменения                                                                                         |
|-----------------|-----------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| Wallet core     | `wallet/core/src/tx/generator/pending.rs`                             | Детектор смешанных входов (stealth + legacy), инвариант `enforce_stealth_only_inputs`.           |
| Wallet core     | `wallet/core/src/tx/generator/generator.rs`                           | Вызов инварианта сразу после `PendingTransaction::try_new`.                                      |
| Wallet core     | `wallet/core/src/error.rs`                                            | Новый тип ошибки `MixedStealthAndLegacyInputsNotAllowed`.                                        |
| Wallet core     | `wallet/core/src/tx/generator/stealth_signer.rs`                      | (Опционально) строгий режим `StealthSigner`, защита от смешанных входов на слое подписи.         |
| Mempool         | `mining/src/mempool/config.rs`                                        | Флаги политики `stealth_only_inputs`, `stealth_only_outputs`.                                    |
| Mempool         | `mining/src/mempool/check_transaction_standard.rs`                    | Жёсткая проверка входов/выходов на стелс‑формат при активной политике.                           |
| Tests           | `wallet/core/src/tx/generator/pending.rs` (mod tests)                 | Юнит‑тесты детектора смешивания и инварианта.                                                     |
| Tests           | `mining/src/mempool/check_transaction_standard.rs` (mod tests)        | Юнит‑тесты на `stealth_only_inputs/outputs`.                                                      |
| Integration     | `testing/integration/src/stealth_flow.rs` или отдельный интег‑модуль  | Интеграционные сценарии: попытка смешивания → отказ кошелька и/или mempool.                      |
| Docs            | Текущий файл + краткий summary в `PRIVACY_AND_QUANTUM_STRATEGY.md`    | Документация дизайна и статуса реализации.                                                        |

---

## 2. Wallet‑core: запрет смешанных входов

### 2.1. Расширение `PendingTransaction` (детект смешанных входов)

**Файл:** `wallet/core/src/tx/generator/pending.rs`

Сейчас в структуре уже есть:

- `utxo_entries: AHashMap<UtxoEntryId, UtxoEntryReference>` — карта входов;
- методы для подписи (`try_sign`, `try_sign_with_stealth`);
- метод `has_stealth_inputs()` (по `STEALTH_SCRIPT_VERSION`).

**Задача:** добавить симметричный детектор non‑stealth входов и комбинированный чек.

#### 2.1.1. Методы `has_non_stealth_inputs()` и `has_mixed_stealth_and_legacy_inputs()`

Добавить в `impl PendingTransaction`:

```rust
impl PendingTransaction {
    /// Проверяет, есть ли в транзакции входы, отличные от стелс‑скриптов.
    pub fn has_non_stealth_inputs(&self) -> bool {
        use kaspa_txscript::STEALTH_SCRIPT_VERSION;

        let signable_tx = match self.inner.signable_tx.lock() {
            Ok(tx) => tx,
            Err(_) => return false,
        };

        signable_tx
            .entries
            .iter()
            .any(|entry| entry.as_ref().map(|e| e.script_public_key.version() != STEALTH_SCRIPT_VERSION).unwrap_or(false))
    }

    /// True, если одновременно присутствуют stealth‑ и non‑stealth‑входы.
    pub fn has_mixed_stealth_and_legacy_inputs(&self) -> bool {
        self.has_stealth_inputs() && self.has_non_stealth_inputs()
    }
}
```

#### 2.1.2. Инвариант `enforce_stealth_only_inputs`

Добавить:

```rust
impl PendingTransaction {
    /// Гарантирует, что либо все входы стелс, либо все входы legacy, но не смесь.
    pub fn enforce_stealth_only_inputs(&self) -> Result<()> {
        if self.has_mixed_stealth_and_legacy_inputs() {
            return Err(Error::MixedStealthAndLegacyInputsNotAllowed);
        }
        Ok(())
    }
}
```

- Этот инвариант **не запрещает** чисто legacy‑транзакции на уровне кошелька (этим займётся mempool).
- Но он гарантирует, что **одна и та же транзакция** не содержит stealth+legacy одновременно.

### 2.2. Новый тип ошибки в `wallet/core/src/error.rs`

В enum `Error` рядом с уже существующими stealth‑ошибками:

```rust
StealthChangeCreatorRequired,
StealthChangeBatchNotSupported,
```

добавить:

```rust
MixedStealthAndLegacyInputsNotAllowed,
```

и:

- обновить `Display`:
  - `"Mixed stealth and legacy inputs are not allowed in a single transaction"`;
- если нужно — прокинуть через WASM/FFI код (по тем же паттернам, что и другие ошибки кошелька).

### 2.3. Вызов инварианта в `Generator::generate_transaction`

**Файл:** `wallet/core/src/tx/generator/generator.rs`

Финальный путь (`DataKind::Final`):

```rust
let pending_tx = PendingTransaction::try_new(/* ... */)?;

// НОВОЕ:
pending_tx.enforce_stealth_only_inputs()?;

// Store pre-calculated stealth change key if present
if let Some(stealth_change) = pending_stealth_change {
    pending_tx.set_stealth_change(stealth_change);
}

Ok(Some(pending_tx))
```

Batch‑путь (`DataKind::Node` / `DataKind::Edge`):

```rust
let pending_tx = PendingTransaction::try_new(/* ... */)?;

// НОВОЕ:
pending_tx.enforce_stealth_only_inputs()?;

Ok(Some(pending_tx))
```

**Результат:**

- Любая транзакция, построенная через стандартный `Generator`:
  - либо имеет только stealth‑входы,
  - либо только legacy‑входы,
  - попытка смешать приведёт к немедленной ошибке на слое кошелька.

### 2.4. Политика по аккаунтам (UX/CLI уровень)

На уровне API/CLI/GUI:

- По умолчанию для пользователя создаётся **только `StealthAccount`** (и MLDSA master при включённой опции).
- Legacy‑аккаунты:
  - не показываются в UI как “обычный” вариант;
  - в CLI/SDK помечаются как advanced/legacy‑функциональность.

Это не кодовый инвариант, но важный UX‑уровень:

- Для 99% пользователей все их реальные платежи идут из стелс‑аккаунта → все входы и комиссии будут stealth‑only.

---

## 3. StealthSigner: строгий режим на слое подписи (страховка)

**Файл:** `wallet/core/src/tx/generator/stealth_signer.rs`

Сейчас логика такая:

- Для входа, где `script_version != STEALTH_SCRIPT_VERSION`:
  - `StealthSigner` пропускает его и ожидает, что обычный `Signer` подпишет legacy‑вход.
- Это поведение корректно, но:
  - если каким‑то образом сформировали смешанную транзакцию в обход `Generator`,
  - `StealthSigner` отработает “по‑тихому”, и ошибка проявится только позже или не проявится вовсе.

### 3.1. Добавить строгий режим

Идея: `StealthSigner` в strict‑режиме возвращает ошибку, если видит смесь входов (stealth + non‑stealth).

Изменения:

1. Расширить структуру:

   ```rust
   pub struct StealthSigner {
       key_provider: DynEphemeralKeyProvider,
       strict_mixed_inputs: bool,
   }

   impl StealthSigner {
       pub fn new(key_provider: DynEphemeralKeyProvider) -> Self {
           Self { key_provider, strict_mixed_inputs: true }
       }

       pub fn with_strict_mode(mut self, strict: bool) -> Self {
           self.strict_mixed_inputs = strict;
           self
       }
   }
   ```

2. Внутри `sign()`:

   - Ввести локальные флаги:

   ```rust
   let mut has_stealth_inputs = false;
   let mut has_non_stealth_inputs = false;
   ```

   - В цикле по входам:

   ```rust
   let script_version = utxo_entry.script_public_key.version();

   if script_version != STEALTH_SCRIPT_VERSION {
       has_non_stealth_inputs = true;
       // существующая логика: помечаем, что нужны дополнительные подписи обычным Signer’ом
       if tx.tx.inputs[idx].signature_script.is_empty() {
           additional_signatures_required = true;
       }
       continue;
   } else {
       has_stealth_inputs = true;
   }
   ```

   - В конце:

   ```rust
   if self.strict_mixed_inputs && has_stealth_inputs && has_non_stealth_inputs {
       return Err(Error::MixedStealthAndLegacyInputsNotAllowed);
   }
   ```

**Роль:**

- Дублирует инвариант из `PendingTransaction`, но уже на слое подписи.
- Защищает от будущих путей генерации/модификации `SignableTransaction`, которые могут обойти стандартный `Generator`.

---

## 4. Mempool / Node: политика “stealth‑only” для входов и выходов

Даже при корректном кошельке, кто‑то может попытаться:

- собрать транзакцию вручную (через RPC/CLI),
- смешать stealth и legacy‑входы/выходы,
- отправить её в сеть.

Чтобы сеть в целом не принимала такие транзакции, добавляем политику уровня mempool.

### 4.1. Расширение конфигурации mempool

**Файл:** `mining/src/mempool/config.rs`

В `struct Config` добавить поля:

```rust
pub stealth_only_inputs: bool,
pub stealth_only_outputs: bool,
```

и:

- В `Config::new` — параметры в конструктор и присвоение.
- В `Config::build_default`:
  - для **новой сети с чистым стелс‑генезисом**:

  ```rust
  stealth_only_inputs: true,
  stealth_only_outputs: true,
  ```

  - для сценариев “форк с историей Kaspa” (если нужен) — можно отключать через настройки.

### 4.2. Запрет non‑stealth выходов (outputs)

**Файл:** `mining/src/mempool/check_transaction_standard.rs`  
Функция `check_transaction_standard_in_isolation`.

Существующий фрагмент:

```rust
for (i, output) in transaction.tx.outputs.iter().enumerate() {
    if output.script_public_key.version() > MAX_SCRIPT_PUBLIC_KEY_VERSION {
        return Err(NonStandardError::RejectScriptPublicKeyVersion(transaction_id, i));
    }

    if ScriptClass::from_script(&output.script_public_key) == ScriptClass::NonStandard {
        return Err(NonStandardError::RejectOutputScriptClass(transaction_id, i));
    }

    if self.is_transaction_output_dust(output) {
        return Err(NonStandardError::RejectDust(transaction_id, i, output.value));
    }
}
```

**Добавить блок под проверкой `ScriptClass`:**

```rust
if self.config.stealth_only_outputs {
    match ScriptClass::from_script(&output.script_public_key) {
        ScriptClass::Stealth => {
            // ok
        }
        _ => {
            return Err(NonStandardError::RejectNonStealthOutput(transaction_id, i));
        }
    }
}
```

Дополнительно:

- В `mining/errors/src/mempool.rs`:
  - добавить `RejectNonStealthOutput(TransactionId, usize)` + человекочитаемый текст:
    - `"non-stealth outputs are not allowed under current mempool policy"`.

### 4.3. Запрет non‑stealth входов (inputs)

**Файл:** тот же, функция `check_transaction_standard_in_context`.

Существующий фрагмент:

```rust
for (i, input) in transaction.tx.inputs.iter().enumerate() {
    let entry = transaction.entries[i].as_ref().unwrap();
    match ScriptClass::from_script(&entry.script_public_key) {
        ScriptClass::NonStandard => { ... }
        ScriptClass::PubKey => {}
        ScriptClass::PubKeyECDSA => {}
        ScriptClass::PubKeyMLDSA => {}
        ScriptClass::Stealth => {} // Native SegWit
        ScriptClass::ScriptHash => { ... }
    }
    // проверка fee...
}
```

**Добавить в начале цикла:**

```rust
if self.config.stealth_only_inputs {
    match ScriptClass::from_script(&entry.script_public_key) {
        ScriptClass::Stealth => {
            // ok
        }
        _ => {
            return Err(NonStandardError::RejectNonStealthInput(transaction_id, i));
        }
    }
}
```

И также:

- В `mining/errors/src/mempool.rs`:
  - добавить `RejectNonStealthInput(TransactionId, usize)` с текстом:
    - `"non-stealth inputs are not allowed under current mempool policy"`.

**Эффект (при включённой политике):**

- Лю

