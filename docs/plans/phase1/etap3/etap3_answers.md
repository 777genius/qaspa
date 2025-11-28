
---

## ФИНАЛЬНЫЕ РАЗВЕРНУТЫЕ ОТВЕТЫ (1-6)

---

### 1. Pre-calculation of Change Keys (Сдача) — КРИТИЧНО!

**Что я нашел в коде:**

В `consensus/core/src/sign.rs` строка 131 функция `sign_with_multiple_v2` использует **жестко закодированный формат P2PK**:
```rust
let script_pub_key_script = once(0x20).chain(schnorr_public_key.serialize().into_iter()).chain(once(0xac)).collect_vec();
map.insert(script_pub_key_script, schnorr_key);
```

Это означает: `[0x20 (OpData32)][32 bytes pubkey][0xac (OpCheckSig)]` = 34 байта.

**ПРОБЛЕМА:** Stealth ScriptPublicKey имеет формат `[33B R][1B tag][32B P_dest]` = 66 байт и **НЕ содержит опкодов**! Текущий `sign_with_multiple_v2` **НЕ НАЙДЕТ** ключ для Stealth UTXO и вернет `Signed::Partially`.

**РЕШЕНИЕ:**

Нам нужен **отдельный Signer для Stealth**, который:
1.  Не ищет ключ по формату скрипта.
2.  Использует `ephemeral_keys` (кеш вычисленных spending keys) для поиска ключа по `outpoint`.
3.  Формирует signature_script в формате `[64 bytes sig][1 byte sighash]` (без OpData65 prefix — это Native SegWit).

```rust
// Новый StealthSigner
pub struct StealthSigner {
    ephemeral_keys: Arc<RwLock<HashMap<TransactionOutpoint, EphemeralKeyData>>>,
}

impl SignerT for StealthSigner {
    fn try_sign(&self, mut mutable_tx: SignableTransaction, _addresses: &[Address]) -> Result<SignableTransaction> {
        let reused_values = SigHashReusedValuesUnsync::new();
        let keys = self.ephemeral_keys.read().unwrap();
        
        for i in 0..mutable_tx.tx.inputs.len() {
            let entry = mutable_tx.entries[i].as_ref().unwrap();
            
            // Проверяем, что это Stealth UTXO
            if entry.script_public_key.version() == STEALTH_SCRIPT_VERSION {
                let outpoint = &mutable_tx.tx.inputs[i].previous_outpoint;
                
                // Ищем ключ по outpoint, НЕ по скрипту!
                let ephemeral_data = keys.get(outpoint)
                    .ok_or(Error::EphemeralKeyNotFound(outpoint.clone()))?;
                
                // Schnorr подпись
                let sig_hash = calc_schnorr_signature_hash(&mutable_tx.as_verifiable(), i, SIG_HASH_ALL, &reused_values);
                let msg = secp256k1::Message::from_digest_slice(sig_hash.as_bytes())?;
                let keypair = secp256k1::Keypair::from_secret_key(SECP256K1, &ephemeral_data.spending_secret);
                let sig: [u8; 64] = *keypair.sign_schnorr(msg).as_ref();
                
                // Native SegWit формат: [64 sig][1 sighash] БЕЗ OpData65!
                mutable_tx.tx.inputs[i].signature_script = sig.into_iter().chain([SIG_HASH_ALL.to_u8()]).collect();
                mutable_tx.tx.inputs[i].sig_op_count = 1;
            }
        }
        
        Ok(mutable_tx)
    }
}
```

**Для сдачи (Change):** При создании транзакции, если change_address — Stealth, мы:
1.  Генерируем `EphemeralOutput` для change.
2.  **Сразу** вычисляем `spending_secret` (мы знаем свой `spend_secret`).
3.  Сохраняем в `ephemeral_keys` с ключом = будущий outpoint (txid:output_index).
4.  После подтверждения транзакции outpoint становится валидным.

---

### 2. Coin Selection и Смешивание — АРХИТЕКТУРНО БЕЗОПАСНО

**Что я нашел в коде:**

В `wallet/core/src/utxo/processor.rs` строка 44:
```rust
address_to_utxo_context_map: DashMap<Arc<Address>, UtxoContext>,
```

Каждый `Address` привязан к **одному** `UtxoContext`. А каждый Account имеет свой UtxoContext.

В `wallet/core/src/tx/generator/settings.rs` строка 22:
```rust
pub source_utxo_context: Option<UtxoContext>,
```

Generator получает UTXO только из указанного контекста.

**ПРОБЛЕМА:** Для Stealth мы **НЕ МОЖЕМ** использовать `address_to_utxo_context_map`, потому что у нас **НЕТ фиксированных адресов**! Каждый Stealth UTXO имеет уникальный `P_dest`, который не равен нашему публичному адресу.

**РЕШЕНИЕ:**

Для `StealthAccount` нужен **альтернативный механизм сканирования**:

1.  **НЕ регистрируем адреса** в `address_to_utxo_context_map` (их бесконечно много).
2.  Вместо этого, `StealthAccount.scan()` делает:
    ```rust
    // Получаем ВСЕ UTXO с версией Stealth
    let all_stealth_utxos = rpc.get_utxos_by_script_version(STEALTH_SCRIPT_VERSION).await?;
    
    // Фильтруем свои через ViewTag + ECDH
    for utxo in all_stealth_utxos {
        if self.scanner.is_mine(&utxo)? {
            self.utxo_context.insert(utxo).await?;
            self.ephemeral_keys.insert(outpoint, derived_key);
        }
    }
    ```

3.  **Для real-time уведомлений:** Подписываемся на `UtxosChanged` БЕЗ фильтра по адресам (или с фильтром по script_version, если RPC это поддерживает). Фильтрация происходит локально.

**Изоляция гарантирована:** `StealthAccount` видит только свои Stealth UTXO. `StandardAccount` видит только свои P2PK UTXO. Смешивание невозможно.

---

### 3. Birthday — ХРАНЕНИЕ И ВОССТАНОВЛЕНИЕ

**Что я нашел в коде:**

В `wallet/core/src/storage/metadata.rs`:
```rust
pub struct AccountMetadata {
    pub id: AccountId,
    pub indexes: Option<AddressDerivationMeta>,
}
```

`AccountMetadata` хранится **незашифрованно** в `WalletStorage.metadata`.

**РЕШЕНИЕ:**

```rust
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AccountMetadata {
    pub id: AccountId,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub indexes: Option<AddressDerivationMeta>,
    
    // НОВОЕ: Для Stealth аккаунтов
    #[serde(skip_serializing_if = "Option::is_none")]
    pub creation_daa_score: Option<u64>,
}
```

**При создании StealthAccount:**
```rust
let current_daa_score = self.rpc_api().get_server_info().await?.virtual_daa_score;
let metadata = AccountMetadata {
    id: account.id(),
    indexes: None,
    creation_daa_score: Some(current_daa_score),
};
self.store().save_metadata(&metadata).await?;
```

**При восстановлении:**
```rust
pub enum BirthdayHint {
    Today,      // current_daa - 86400 (1 день)
    ThisWeek,   // current_daa - 604800 (7 дней)
    ThisMonth,  // current_daa - 2592000 (30 дней)
    ThisYear,   // current_daa - 31536000 (365 дней)
    Genesis,    // 0
}

pub async fn restore_with_birthday(
    &self,
    hint: BirthdayHint,
) -> Result<()> {
    let current = self.rpc_api().get_server_info().await?.virtual_daa_score;
    let start_daa = match hint {
        BirthdayHint::Today => current.saturating_sub(86400),
        BirthdayHint::ThisWeek => current.saturating_sub(604800),
        BirthdayHint::ThisMonth => current.saturating_sub(2592000),
        BirthdayHint::ThisYear => current.saturating_sub(31536000),
        BirthdayHint::Genesis => 0,
    };
    
    // Добавляем запас 10%
    let start_daa = start_daa.saturating_sub(start_daa / 10);
    
    self.scan_from_daa_score(start_daa).await
}
```

---

### 4. Fee Calculation — ПРОВЕРКА И ИСПРАВЛЕНИЕ

**Что я нашел в коде:**

В `wallet/core/src/tx/mass.rs` строка 263-266:
```rust
pub(crate) fn calc_compute_mass_for_client_transaction_output(&self, output: &TransactionOutput) -> u64 {
    self.mass_per_script_pub_key_byte * (2 + output.script_public_key.script().len() as u64)
        + transaction_output_serialized_byte_size(output) * self.mass_per_tx_byte
}
```

**Хорошо!** Используется `script().len()`, не хардкод.

**ПРОБЛЕМА в Generator:**

В `wallet/core/src/tx/generator/generator.rs` строка 416-417:
```rust
let standard_change_output_mass = mass_calculator
    .calc_compute_mass_for_client_transaction_output(
        &TransactionOutput::new(0, pay_to_address_script(&change_address))
    );
```

`pay_to_address_script` для Stealth вызовет **panic** (мы это сделали в Фазе 2)!

**РЕШЕНИЕ:**

```rust
// В Generator::try_new()
let standard_change_output_mass = match change_address.version {
    Version::Stealth => {
        // Для Stealth: фиктивный выход 66 байт
        let dummy_script = ScriptPublicKey::new(
            STEALTH_SCRIPT_VERSION,
            SmallVec::from_slice(&[0u8; STEALTH_OUTPUT_SIZE])
        );
        mass_calculator.calc_compute_mass_for_client_transaction_output(
            &TransactionOutput::new(0, dummy_script)
        )
    }
    _ => {
        mass_calculator.calc_compute_mass_for_client_transaction_output(
            &TransactionOutput::new(0, pay_to_address_script(&change_address))
        )
    }
};
```

**Дополнительно:** В `is_transaction_output_dust` (строка 63):
```rust
if transaction_output.script_public_key.script().len() < 33 {
    return true;
}
```
Stealth (66 байт) пройдет. **ОК.**

---

### 5. Формат "Own Address" — ОДИН АДРЕС, МНОГО АККАУНТОВ

**Что я нашел в коде:**

В `wallet/core/src/account/variants/bip32.rs` строка 192-197:
```rust
fn receive_address(&self) -> Result<Address> {
    self.derivation.receive_address_manager().current_address()
}

fn change_address(&self) -> Result<Address> {
    self.derivation.change_address_manager().current_address()
}
```

BIP32 использует `AddressDerivationManager` для генерации множества адресов.

**Для Stealth:**

```rust
impl Account for StealthAccount {
    fn receive_address(&self) -> Result<Address> {
        // ВСЕГДА один и тот же адрес
        Ok(self.stealth_address.to_address(self.network_prefix()?))
    }
    
    fn change_address(&self) -> Result<Address> {
        // Сдача идет на тот же адрес (но с новым ephemeral key!)
        self.receive_address()
    }
    
    fn account_addresses(&self) -> Result<Vec<Address>> {
        // Только один адрес
        Ok(vec![self.receive_address()?])
    }
}
```

**Множественные аккаунты через `account_index`:**
```rust
// m/44'/111111'/0'/... → StealthAccount #0
// m/44'/111111'/1'/... → StealthAccount #1 (другой адрес)
```

---

### 6. Reorgs — УДАЛЕНИЕ EPHEMERAL KEYS

**Что я нашел в коде:**

В `wallet/core/src/utxo/context.rs` строка 355-391 метод `remove()`:
```rust
pub async fn remove(&self, utxos: Vec<UtxoEntryReference>) -> Result<Vec<UtxoEntryVariant>> {
    // ... удаляет из map, pending, stasis, mature
}
```

В строке 629-699 метод `handle_utxo_removed()`:
```rust
pub(crate) async fn handle_utxo_removed(&self, utxos: Vec<UtxoEntryReference>, ...) -> Result<()> {
    // ... обрабатывает удаление, генерирует Events::Reorg
}
```

В строке 666-697 генерируются события:
```rust
let record = TransactionRecord::new_reorg(self, txid, &utxos);
self.processor().notify(Events::Reorg { record }).await?;
```

**РЕШЕНИЕ:**

`StealthAccount` должен подписаться на `Events::Reorg` и удалять ключи:

```rust
impl StealthAccount {
    pub async fn handle_event(&self, event: &Events) -> Result<()> {
        match event {
            Events::Reorg { record } => {
                let mut keys = self.ephemeral_keys.write().await;
                
                for utxo in record.utxo_entries() {
                    let outpoint = TransactionOutpoint::new(
                        record.id(),
                        utxo.index() as u32
                    );
                    
                    if keys.remove(&outpoint).is_some() {
                        log::info!("Removed ephemeral key for reorged UTXO: {:?}", outpoint);
                    }
                }
                
                // Persist changes
                self.save_ephemeral_keys_to_storage().await?;
            }
            
            Events::Maturity { record } => {
                // Обновляем статус ключа на Confirmed
                if let Some(key) = self.ephemeral_keys.write().await.get_mut(&record.outpoint()) {
                    key.status = EphemeralKeyStatus::Confirmed;
                }
            }
            
            _ => {}
        }
        Ok(())
    }
}
```

**Важно:** В `Wallet.handle_event()` (строка 1097-1109) нужно добавить вызов `stealth_account.handle_event()` для всех Stealth аккаунтов.

---

## КРИТИЧЕСКИЕ НАХОДКИ (Резюме)

| # | Находка | Влияние | Решение |
|---|---------|---------|---------|
| 1 | `sign_with_multiple_v2` хардкодит P2PK формат | Stealth транзакции НЕ подпишутся | Создать `StealthSigner` с поиском по outpoint |
| 2 | `address_to_utxo_context_map` не работает для Stealth | Нет real-time уведомлений | Альтернативный механизм сканирования по script_version |
| 3 | `pay_to_address_script` паникует для Stealth | Generator упадет при расчете change mass | Добавить ветку для Stealth в Generator |
| 4 | Нет подписки на `Events::Reorg` для Stealth | Призрачные ключи после реорга | Добавить обработчик в StealthAccount |

Готов начать реализацию с учетом всех этих находок. Переключись в **Agent Mode**.