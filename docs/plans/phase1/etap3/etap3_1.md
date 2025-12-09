Давайте детально изучим код для понимания Pre-calculation of Change Keys.

[15 tools called]

Теперь у меня полная картина. Составляю **максимально детальный план** для Pre-calculation of Change Keys:

---

# Детальный План: Pre-calculation of Change Keys

## 1. Проблема (детальный анализ)

### 1.1 Текущий код Generator (строки 1053 и 1130)

```rust
// generator.rs:1053
final_outputs.push(TransactionOutput::new(
    change_output_value, 
    pay_to_address_script(&self.inner.change_address)  // ← PANIC для Stealth!
));
```

### 1.2 Почему panic

В `crypto/txscript/src/standard.rs:67-76`:

```rust
pub fn pay_to_address_script(address: &Address) -> ScriptPublicKey {
    match address.version {
        Version::PubKey => pay_to_pub_key(address.payload.as_slice()),
        // ...
        Version::Stealth => panic!("Use pay_to_stealth()..."), // ← Наш panic из Этапа 2
    }
}
```

### 1.3 Почему нельзя просто заменить на `pay_to_stealth`

`pay_to_stealth()` требует `EphemeralOutput`, который содержит:
- `R` (ephemeral pubkey) — генерируется случайно
- `view_tag` — вычисляется из ECDH
- `P_dest` — требует `spend_pubkey`

**Критично:** Если мы сгенерируем R, но НЕ сохраним spending_key СРАЗУ, после broadcast транзакции нам придётся **пересканировать весь блокчейн** чтобы найти свой change!

### 1.4 Архитектурное ограничение

| Компонент | Имеет spend_secret? | Имеет change_address? |
|-----------|--------------------|-----------------------|
| Generator | ❌ НЕТ | ✅ ДА |
| Signer | ✅ ДА (через keydata) | ❌ НЕТ |
| Account | ✅ ДА (может получить) | ✅ ДА |

**Проблема:** Generator вызывается ДО Signer, но не имеет доступа к `spend_secret`.

---

## 2. Решение: StealthChangeCreator callback

### 2.1 Новый trait

**Файл:** `wallet/core/src/tx/generator/stealth_change.rs` (НОВЫЙ)

```rust
use kaspa_stealth::EphemeralOutput;
use kaspa_consensus_core::tx::TransactionOutput;
use secp256k1::{SecretKey, Scalar, XOnlyPublicKey};
use crate::result::Result;

/// Entry for a pre-calculated ephemeral key (before outpoint is known)
#[derive(Clone)]
pub struct PendingStealthChange {
    /// Index of the change output in the transaction
    pub output_index: usize,
    /// The ephemeral output data (R, tag, P_dest)
    pub ephemeral_output: EphemeralOutput,
    /// Pre-computed blinding factor
    pub blinding_factor: Scalar,
    /// Pre-computed spending secret key
    pub spending_secret: SecretKey,
}

/// Trait for creating stealth change outputs with pre-calculated keys.
/// 
/// This is called by Generator when change_address is a Stealth address.
/// The implementation has access to spend_secret and can pre-calculate
/// the spending key before the transaction is broadcast.
pub trait StealthChangeCreator: Send + Sync {
    /// Creates a stealth output for change.
    /// 
    /// Returns:
    /// - TransactionOutput to include in the transaction
    /// - PendingStealthChange with pre-calculated key data
    fn create_change_output(&self, amount: u64) -> Result<(TransactionOutput, PendingStealthChange)>;
}
```

### 2.2 Расширение GeneratorSettings

**Файл:** `wallet/core/src/tx/generator/settings.rs`

```rust
use crate::tx::generator::stealth_change::StealthChangeCreator;

pub struct GeneratorSettings {
    // ... existing fields ...
    
    /// Optional creator for stealth change outputs.
    /// Required when change_address.version == Version::Stealth.
    pub stealth_change_creator: Option<Arc<dyn StealthChangeCreator>>,
}
```

### 2.3 Реализация в StealthAccount

**Файл:** `wallet/core/src/account/variants/stealth.rs`

```rust
/// Implementation of StealthChangeCreator for StealthAccount
struct StealthChangeCreatorImpl {
    stealth_address: kaspa_stealth::StealthAddress,
    spend_secret: SecretKey,
}

impl StealthChangeCreator for StealthChangeCreatorImpl {
    fn create_change_output(&self, amount: u64) -> Result<(TransactionOutput, PendingStealthChange)> {
        use kaspa_stealth::{create_stealth_output, derive_spending_key, BlindingFactorHash};
        use kaspa_txscript::pay_to_stealth;
        use rand::rngs::OsRng;
        
        // 1. Generate ephemeral output
        let ephemeral_output = create_stealth_output(&self.stealth_address, &mut OsRng)?;
        
        // 2. Compute blinding factor (same as in sender.rs)
        let shared_secret = compute_shared_secret_from_address(...);
        let blinding_hash = BlindingFactorHash::hash(shared_secret);
        let blinding_factor = Scalar::from_be_bytes(blinding_hash.as_bytes())?;
        
        // 3. Pre-compute spending key
        let spending_secret = derive_spending_key(&self.spend_secret, &blinding_factor)?;
        
        // 4. Create ScriptPublicKey
        let script = pay_to_stealth(&ephemeral_output);
        let output = TransactionOutput::new(amount, script);
        
        Ok((output, PendingStealthChange {
            output_index: 0, // Will be set by Generator
            ephemeral_output,
            blinding_factor,
            spending_secret,
        }))
    }
}
```

### 2.4 Модификация Generator

**Файл:** `wallet/core/src/tx/generator/generator.rs`

#### 2.4.1 Добавить поле в Inner

```rust
struct Inner {
    // ... existing fields ...
    
    /// Pending stealth change keys (collected during generation)
    pending_stealth_changes: Mutex<Vec<(TransactionId, PendingStealthChange)>>,
}
```

#### 2.4.2 Изменить строку 416-417 (mass calculation)

```rust
// Было:
let standard_change_output_mass = mass_calculator
    .calc_compute_mass_for_client_transaction_output(
        &TransactionOutput::new(0, pay_to_address_script(&change_address))
    );

// Стало:
let standard_change_output_mass = if change_address.version == Version::Stealth {
    // Stealth output: [33B R][1B tag][32B P_dest] = 66 bytes
    let dummy_script = ScriptPublicKey::new(
        STEALTH_SCRIPT_VERSION, 
        SmallVec::from_slice(&[0u8; 66])
    );
    mass_calculator.calc_compute_mass_for_client_transaction_output(
        &TransactionOutput::new(0, dummy_script)
    )
} else {
    mass_calculator.calc_compute_mass_for_client_transaction_output(
        &TransactionOutput::new(0, pay_to_address_script(&change_address))
    )
};
```

#### 2.4.3 Изменить строку 1051-1057 (final transaction change)

```rust
let change_output_index = if change_output_value > 0 {
    let change_output_index = Some(final_outputs.len());
    
    let change_output = if self.inner.change_address.version == Version::Stealth {
        // Use stealth change creator
        let creator = self.inner.stealth_change_creator.as_ref()
            .ok_or(Error::StealthChangeCreatorRequired)?;
        
        let (mut output, mut pending) = creator.create_change_output(change_output_value)?;
        pending.output_index = final_outputs.len();
        
        // Store pending change (txid will be added after transaction is created)
        self.inner.pending_stealth_changes.lock().unwrap()
            .push((TransactionId::default(), pending)); // Placeholder txid
        
        output
    } else {
        TransactionOutput::new(change_output_value, pay_to_address_script(&self.inner.change_address))
    };
    
    final_outputs.push(change_output);
    change_output_index
} else {
    None
};

// ... create transaction ...

// After transaction is created, update pending changes with real txid
if change_output_index.is_some() && self.inner.change_address.version == Version::Stealth {
    let mut pending = self.inner.pending_stealth_changes.lock().unwrap();
    if let Some(last) = pending.last_mut() {
        last.0 = tx.id(); // Now we know the real txid
    }
}
```

#### 2.4.4 Аналогично для строки 1130 (batch transaction change)

```rust
let script_public_key = if self.inner.change_address.version == Version::Stealth {
    let creator = self.inner.stealth_change_creator.as_ref()
        .ok_or(Error::StealthChangeCreatorRequired)?;
    
    let (output, mut pending) = creator.create_change_output(output_value)?;
    pending.output_index = 0; // Only output in batch tx
    
    self.inner.pending_stealth_changes.lock().unwrap()
        .push((TransactionId::default(), pending));
    
    output.script_public_key
} else {
    pay_to_address_script(&self.inner.change_address)
};

// ... create transaction ...

// Update txid after creation
if self.inner.change_address.version == Version::Stealth {
    let mut pending = self.inner.pending_stealth_changes.lock().unwrap();
    if let Some(last) = pending.last_mut() {
        last.0 = tx.id();
    }
}
```

### 2.5 Расширение PendingTransaction

**Файл:** `wallet/core/src/tx/generator/pending.rs`

```rust
pub(crate) struct PendingTransactionInner {
    // ... existing fields ...
    
    /// Pre-calculated stealth change key (if change is to stealth address)
    pub(crate) stealth_change: Option<PendingStealthChange>,
}

impl PendingTransaction {
    /// Returns the pending stealth change data if present
    pub fn stealth_change(&self) -> Option<&PendingStealthChange> {
        self.inner.stealth_change.as_ref()
    }
    
    /// Consumes and returns the stealth change data
    pub fn take_stealth_change(&self) -> Option<PendingStealthChange> {
        // Use interior mutability pattern
        // ...
    }
}
```

### 2.6 Финализация после submit

**Файл:** `wallet/core/src/account/variants/stealth.rs`

```rust
impl StealthAccount {
    /// Called after transaction is successfully submitted
    pub async fn finalize_stealth_change(
        &self,
        tx_id: TransactionId,
        pending: PendingStealthChange,
    ) -> Result<()> {
        let outpoint = TransactionOutpoint::new(tx_id, pending.output_index as u32);
        
        let entry = EphemeralKeyEntry {
            data: EphemeralKeyData {
                spending_secret: pending.spending_secret,
                blinding_factor: pending.blinding_factor,
                destination_pubkey: pending.ephemeral_output.destination_pubkey,
            },
            status: EphemeralKeyStatus::Pending, // Not confirmed yet
        };
        
        self.ephemeral_keys.write().await.insert(outpoint, entry);
        self.save_ephemeral_keys().await?;
        
        Ok(())
    }
}
```

### 2.7 Интеграция в send()

**Файл:** `wallet/core/src/account/mod.rs` (или `stealth.rs`)

```rust
// В StealthAccount::send()
async fn send(
    self: Arc<Self>,
    destination: PaymentDestination,
    // ...
) -> Result<(GeneratorSummary, Vec<Hash>)> {
    let keydata = self.prv_key_data(wallet_secret).await?;
    
    // Create stealth change creator
    let derivation = StealthKeyDerivation::from_xprv(&keydata.get_xprv(payment_secret.as_ref())?, self.account_index)?;
    let change_creator = Arc::new(StealthChangeCreatorImpl {
        stealth_address: self.stealth_address.clone(),
        spend_secret: derivation.spend_secret.clone(),
    });
    
    // Create signer
    let signer = Arc::new(StealthSigner::new(self.clone(), keydata, payment_secret));
    
    // Create settings with stealth_change_creator
    let mut settings = GeneratorSettings::try_new_with_account(...)?;
    settings.stealth_change_creator = Some(change_creator);
    
    let generator = Generator::try_new(settings, Some(signer), Some(abortable))?;
    
    let mut stream = generator.stream();
    let mut ids = vec![];
    while let Some(transaction) = stream.try_next().await? {
        transaction.try_sign()?;
        
        // Before submit: save pending stealth change
        let pending_change = transaction.take_stealth_change();
        
        let id = transaction.try_submit(&self.wallet().rpc_api()).await?;
        
        // After submit: finalize with real txid
        if let Some(pending) = pending_change {
            self.finalize_stealth_change(id, pending).await?;
        }
        
        ids.push(id);
    }
    
    Ok((generator.summary(), ids))
}
```

---

## 3. Новые типы ошибок

**Файл:** `wallet/core/src/error.rs`

```rust
pub enum Error {
    // ... existing ...
    
    #[error("Stealth change creator is required for stealth change address")]
    StealthChangeCreatorRequired,
    
    #[error("Ephemeral key not found for outpoint {0}")]
    EphemeralKeyNotFound(TransactionOutpoint),
}
```

---

## 4. Необходимые изменения в kaspa-stealth

Нужно экспортировать функцию для вычисления shared secret и blinding factor из ephemeral secret:

**Файл:** `crypto/stealth/src/sender.rs`

```rust
/// Creates stealth output AND returns the blinding factor for pre-calculation.
/// 
/// This is needed when the sender is also the receiver (change output)
/// and wants to pre-calculate the spending key.
pub fn create_stealth_output_with_blinding<R: CryptoRngCore>(
    address: &StealthAddress,
    rng: &mut R,
) -> Result<(EphemeralOutput, Scalar)> {
    let ephemeral_secret = SecretKey::new(rng);
    let ephemeral_pubkey = ephemeral_secret.public_key(SECP256K1);
    
    let shared_secret = compute_shared_secret_xonly(&ephemeral_secret, &address.scan_pubkey);
    let view_tag = ViewTagHash::compute_tag(shared_secret);
    
    let blinding_hash = BlindingFactorHash::hash(shared_secret);
    let blinding_factor = Scalar::from_be_bytes(blinding_hash.as_bytes())?;
    
    let (destination_pubkey, _) = address.spend_pubkey
        .add_tweak(SECP256K1, &blinding_factor)?;
    
    let output = EphemeralOutput::new(ephemeral_pubkey, view_tag, destination_pubkey);
    
    Ok((output, blinding_factor))
}
```

---

## 5. Порядок реализации

| # | Задача | Файлы |
|---|--------|-------|
| 1 | Добавить `create_stealth_output_with_blinding` | `crypto/stealth/src/sender.rs` |
| 2 | Создать `stealth_change.rs` с trait и типами | `wallet/core/src/tx/generator/stealth_change.rs` |
| 3 | Добавить поле в GeneratorSettings | `wallet/core/src/tx/generator/settings.rs` |
| 4 | Добавить поле в Inner и PendingTransactionInner | `wallet/core/src/tx/generator/generator.rs`, `pending.rs` |
| 5 | Исправить mass calculation (строка 416) | `wallet/core/src/tx/generator/generator.rs` |
| 6 | Исправить change output creation (строки 1053, 1130) | `wallet/core/src/tx/generator/generator.rs` |
| 7 | Реализовать StealthChangeCreatorImpl | `wallet/core/src/account/variants/stealth.rs` |
| 8 | Интегрировать в StealthAccount::send() | `wallet/core/src/account/variants/stealth.rs` |
| 9 | Добавить типы ошибок | `wallet/core/src/error.rs` |
| 10 | Тесты | `wallet/core/tests/stealth_change.rs` |

---

## 6. Вопросы для уточнения

**Вопрос 1:** Где хранить `PendingStealthChange` в Generator — в `Inner` или в `Context`?

**Предлагаемый ответ:** В `Inner.pending_stealth_changes: Mutex<Vec<(TransactionId, PendingStealthChange)>>`, потому что:
- Это данные на уровне генератора, не на уровне итерации
- Могут быть multiple transactions в batch mode
- Mutex нужен для thread-safety

**Вопрос 2:** Использовать `Mutex<Option<>>` в PendingTransactionInner или паттерн take?

**Предлагаемый ответ:** Использовать `Option<PendingStealthChange>` без Mutex, с методом `take_stealth_change()` который использует `std::mem::take()` через внутреннюю мутабельность (`AtomicCell` или `RefCell`). Это проще и безопаснее.

---

Готов к реализации или есть вопросы по плану?