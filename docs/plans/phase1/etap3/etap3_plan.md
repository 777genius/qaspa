# Этап 3: Интеграция Stealth в Кошелёк (Актуализированный План)

## Обзор

Этап 3 интегрирует Stealth Addresses в `wallet/core/`. На основе детального анализа кода и ответов добавлены критичные доработки:

- Pre-calculation Change Keys (сдача без пересканирования)
- Архитектурная изоляция UTXO (без смешивания)
- Birthday для восстановления
- Корректный расчёт массы для Stealth
- Статус Pending/Confirmed для ephemeral keys
- Обработка Events::Reorg

---

## Часть A: StealthAccount Структура

### A1. Константы

**Файл:** [`wallet/core/src/account/variants/stealth.rs`](wallet/core/src/account/variants/stealth.rs) (НОВЫЙ)

```rust
pub const STEALTH_ACCOUNT_KIND: &str = "kaspa-stealth-standard";
pub const STEALTH_COIN_TYPE: u32 = 111111;
pub const STEALTH_SPEND_CHANGE: u32 = 0;  // m/.../account'/0'/...
pub const STEALTH_SCAN_CHANGE: u32 = 1;   // m/.../account'/1'/...
```

### A2. Структура StealthAccount

```rust
pub struct StealthAccount {
    inner: Arc<Inner>,
    prv_key_data_id: PrvKeyDataId,
    account_index: u64,
    
    // X-only pubkeys (32 bytes each)
    scan_pubkey: XOnlyPublicKey,
    spend_pubkey: XOnlyPublicKey,
    
    // Единственный публичный адрес (qs1.../qstest1...)
    stealth_address: kaspa_stealth::StealthAddress,
    
    // Кеш ephemeral keys с статусом
    ephemeral_keys: Arc<RwLock<HashMap<TransactionOutpoint, EphemeralKeyEntry>>>,
}
```

### A3. EphemeralKeyEntry со статусом

```rust
#[derive(Clone, Serialize, Deserialize)]
pub struct EphemeralKeyEntry {
    pub data: EphemeralKeyData,
    pub status: EphemeralKeyStatus,
}

#[derive(Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum EphemeralKeyStatus {
    Pending,    // Транзакция отправлена, UTXO ещё не подтверждён
    Confirmed,  // UTXO подтверждён в блокчейне
}

#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct EphemeralKeyData {
    pub spending_secret: SecretKey,    // PrivDest = PrivSpend + t
    pub blinding_factor: Scalar,       // t
    pub destination_pubkey: XOnlyPublicKey,  // P_dest
}
```

### A4. Payload для сериализации

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Payload {
    pub account_index: u64,
    pub scan_pubkey_bytes: [u8; 32],
    pub spend_pubkey_bytes: [u8; 32],
}

impl Storable for Payload {
    const STORAGE_MAGIC: u32 = 0x53544c54;  // "STLT"
    const STORAGE_VERSION: u32 = 0;
}
```

### A5. Factory Registration

**Файл:** [`wallet/core/src/account/variants/mod.rs`](wallet/core/src/account/variants/mod.rs)

```rust
pub mod stealth;
pub use stealth::{StealthAccount, STEALTH_ACCOUNT_KIND};
```

**Файл:** [`wallet/core/src/factory.rs`](wallet/core/src/factory.rs)

```rust
factories.insert(STEALTH_ACCOUNT_KIND.into(), Arc::new(stealth::Ctor {}));
```

---

## Часть B: Derivation

### B1. StealthKeyDerivation

**Файл:** [`wallet/core/src/derivation.rs`](wallet/core/src/derivation.rs)

```rust
pub struct StealthKeyDerivation {
    pub scan_secret: SecretKey,
    pub spend_secret: SecretKey,
}

impl StealthKeyDerivation {
    /// Деривирует Stealth ключи из master xprv
    /// SpendKey: m/44'/111111'/account'/0'/0
    /// ScanKey:  m/44'/111111'/account'/1'/0
    pub fn from_xprv(
        xprv: &ExtendedPrivateKey<SecretKey>,
        account_index: u64,
    ) -> Result<Self> {
        let spend_path: DerivationPath = format!(
            "m/44'/{}'/{}'/{}'/{}", 
            STEALTH_COIN_TYPE, account_index, STEALTH_SPEND_CHANGE, 0
        ).parse()?;
        
        let scan_path: DerivationPath = format!(
            "m/44'/{}'/{}'/{}'/{}", 
            STEALTH_COIN_TYPE, account_index, STEALTH_SCAN_CHANGE, 0
        ).parse()?;
        
        let spend_secret = *xprv.derive_path(&spend_path)?.private_key();
        let scan_secret = *xprv.derive_path(&scan_path)?.private_key();
        
        Ok(Self { scan_secret, spend_secret })
    }
    
    pub fn to_stealth_address(&self) -> kaspa_stealth::StealthAddress {
        kaspa_stealth::StealthSecretKey::new(
            self.scan_secret.clone(),
            self.spend_secret.clone(),
        ).to_address()
    }
    
    pub fn scan_pubkey(&self) -> XOnlyPublicKey {
        self.scan_secret.x_only_public_key(SECP256K1).0
    }
    
    pub fn spend_pubkey(&self) -> XOnlyPublicKey {
        self.spend_secret.x_only_public_key(SECP256K1).0
    }
}
```

---

## Часть C: AccountMetadata с Birthday

### C1. Расширение AccountMetadata

**Файл:** [`wallet/core/src/storage/metadata.rs`](wallet/core/src/storage/metadata.rs)

```rust
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AccountMetadata {
    pub id: AccountId,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub indexes: Option<AddressDerivationMeta>,
    
    // НОВОЕ: DAA Score на момент создания (для Birthday)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub creation_daa_score: Option<u64>,
}
```

**ВАЖНО:** Нужно увеличить `STORAGE_VERSION` и обработать миграцию.

### C2. Использование при создании аккаунта

```rust
impl StealthAccount {
    pub async fn try_new(wallet: &Arc<Wallet>, ...) -> Result<Self> {
        // Получаем текущий DAA score
        let current_daa_score = wallet.rpc_api()
            .get_server_info().await?
            .virtual_daa_score;
        
        // Сохраняем в metadata
        let metadata = AccountMetadata {
            id: account_id,
            indexes: None,  // Stealth не использует HD индексы
            creation_daa_score: Some(current_daa_score),
        };
        
        // ...
    }
}
```

### C3. Использование при восстановлении

```rust
pub async fn restore_stealth_account(
    wallet: &Arc<Wallet>,
    seed: &Mnemonic,
    wallet_secret: &Secret,
    birthday_hint: Option<BirthdayHint>,
) -> Result<Arc<StealthAccount>> {
    let current_daa = wallet.current_daa_score().ok_or(Error::NotConnected)?;
    
    let start_daa = match birthday_hint {
        Some(BirthdayHint::Week) => current_daa.saturating_sub(7 * 24 * 60 * 60),
        Some(BirthdayHint::Month) => current_daa.saturating_sub(30 * 24 * 60 * 60),
        Some(BirthdayHint::Year) => current_daa.saturating_sub(365 * 24 * 60 * 60),
        None => 0,  // С генезиса
    };
    
    account.scan_from_daa_score(start_daa).await?;
    Ok(account)
}

pub enum BirthdayHint {
    Week,
    Month,
    Year,
}
```

---

## Часть D: Сканирование Stealth UTXO

### D1. StealthScanner

**Файл:** [`wallet/core/src/utxo/stealth_scan.rs`](wallet/core/src/utxo/stealth_scan.rs) (НОВЫЙ)

```rust
pub struct StealthScanner<'a> {
    scan_secret: &'a SecretKey,
    spend_pubkey: &'a XOnlyPublicKey,
}

impl<'a> StealthScanner<'a> {
    pub fn new(scan_secret: &'a SecretKey, spend_pubkey: &'a XOnlyPublicKey) -> Self {
        Self { scan_secret, spend_pubkey }
    }
    
    /// Сканирует UTXO на принадлежность. Возвращает blinding_factor если наш.
    pub fn scan_utxo(&self, utxo: &UtxoEntry) -> Option<Scalar> {
        let spk = &utxo.script_public_key;
        
        if spk.version() != STEALTH_SCRIPT_VERSION {
            return None;
        }
        
        let output = extract_stealth_output(spk).ok()?;
        
        // Быстрая проверка view tag (O(1))
        if !check_view_tag(&output.ephemeral_pubkey, output.view_tag, self.scan_secret) {
            return None;
        }
        
        // Полная проверка ECDH
        let scan_result = scan_output(&output, self.scan_secret, self.spend_pubkey).ok()?;
        
        Some(scan_result.blinding_factor)
    }
}
```

### D2. Интеграция в Account::scan()

```rust
#[async_trait]
impl Account for StealthAccount {
    async fn scan(self: Arc<Self>, _window_size: Option<usize>, _extent: Option<u32>) -> Result<()> {
        self.utxo_context().clear().await?;
        
        let current_daa_score = self.wallet().current_daa_score().ok_or(Error::NotConnected)?;
        
        // Получаем spend_secret для вычисления spending keys
        let prv_key_data = self.prv_key_data(/* wallet_secret */).await?;
        let derivation = StealthKeyDerivation::from_xprv(
            &prv_key_data.get_xprv(None)?,
            self.account_index,
        )?;
        
        let scanner = StealthScanner::new(&derivation.scan_secret, &self.spend_pubkey);
        
        // Получаем все UTXO (пока без фильтрации по версии — это оптимизация)
        // TODO: RPC get_utxos_by_script_version() для оптимизации
        let all_utxos = self.wallet().rpc_api()
            .get_utxos_by_addresses(vec![/* stealth address? */]).await?;
        
        let mut keys = self.ephemeral_keys.write().await;
        
        for utxo in all_utxos {
            if let Some(blinding_factor) = scanner.scan_utxo(&utxo) {
                // Вычисляем spending key
                let spending_keypair = derive_spending_key(&derivation.spend_secret, &blinding_factor)?;
                
                let output = extract_stealth_output(&utxo.script_public_key)?;
                
                let entry = EphemeralKeyEntry {
                    data: EphemeralKeyData {
                        spending_secret: spending_keypair.secret_key().clone(),
                        blinding_factor,
                        destination_pubkey: output.destination_pubkey,
                    },
                    status: EphemeralKeyStatus::Confirmed,
                };
                
                keys.insert(utxo.outpoint.clone(), entry);
                
                let utxo_ref = UtxoEntryReference::from(utxo);
                self.utxo_context().insert(utxo_ref, current_daa_score).await?;
            }
        }
        
        self.utxo_context().update_balance().await?;
        Ok(())
    }
}
```

---

## Часть E: TX Generator для Stealth

### E1. Проблема с pay_to_address_script

**Файл:** [`wallet/core/src/tx/generator/generator.rs`](wallet/core/src/tx/generator/generator.rs)

**Строки 416-417:** `pay_to_address_script(&change_address)` вызывает **panic** для Stealth!

**Решение:** Проверка версии адреса:

```rust
// В Generator::try_new() строка ~416
let standard_change_output_mass = if change_address.version == Version::Stealth {
    // Для Stealth: фиктивный 66-байтный скрипт для расчёта массы
    let dummy_script = ScriptPublicKey::new(STEALTH_SCRIPT_VERSION, SmallVec::from_slice(&[0u8; 66]));
    mass_calculator.calc_compute_mass_for_client_transaction_output(
        &TransactionOutput::new(0, dummy_script)
    )
} else {
    mass_calculator.calc_compute_mass_for_client_transaction_output(
        &TransactionOutput::new(0, pay_to_address_script(&change_address))
    )
};
```

### E2. Pre-calculation Change Keys (КРИТИЧНО!)

**Проблема:** При создании change output на Stealth адрес генерируется уникальный R. Если не сохранить ключ СРАЗУ, придётся пересканировать блокчейн.

**Решение:** Функция для создания change с pre-calculated key:

```rust
// Новый файл или расширение generator.rs
impl Generator {
    /// Создаёт Stealth change output и возвращает ephemeral key для немедленного сохранения
    fn create_stealth_change_output(
        &self,
        amount: u64,
        stealth_address: &kaspa_stealth::StealthAddress,
        spend_secret: &SecretKey,  // Нужен для вычисления spending key
    ) -> Result<(TransactionOutput, EphemeralKeyEntry)> {
        // 1. Генерируем эфемерный секрет r
        let ephemeral_secret = SecretKey::new(&mut OsRng);
        
        // 2. Создаём EphemeralOutput
        let (ephemeral_output, _) = create_stealth_output(stealth_address, &mut OsRng)?;
        
        // 3. Вычисляем shared secret для blinding factor
        let shared_secret = compute_shared_secret_xonly(&ephemeral_secret, &stealth_address.scan_pubkey);
        let blinding_hash = StealthBlindingFactorHash::hash(shared_secret);
        let blinding_factor = Scalar::from_be_bytes(blinding_hash.as_bytes())?;
        
        // 4. PRE-CALCULATE spending key (мы знаем spend_secret!)
        let spending_keypair = derive_spending_key(spend_secret, &blinding_factor)?;
        
        // 5. Создаём ScriptPublicKey
        let script_public_key = pay_to_stealth(&ephemeral_output);
        
        // 6. Возвращаем output и ключ со статусом Pending
        let entry = EphemeralKeyEntry {
            data: EphemeralKeyData {
                spending_secret: spending_keypair.secret_key().clone(),
                blinding_factor,
                destination_pubkey: ephemeral_output.destination_pubkey,
            },
            status: EphemeralKeyStatus::Pending,  // Ещё не подтверждён!
        };
        
        Ok((TransactionOutput::new(amount, script_public_key), entry))
    }
}
```

### E3. Модификация создания Change Output

**Строки 1053 и 1130** в generator.rs нужно изменить:

```rust
// Было:
final_outputs.push(TransactionOutput::new(change_output_value, pay_to_address_script(&self.inner.change_address)));

// Стало:
let change_output = if self.inner.change_address.version == Version::Stealth {
    let (output, ephemeral_entry) = self.create_stealth_change_output(
        change_output_value,
        &stealth_address,
        &spend_secret,
    )?;
    
    // Сохраняем ключ СРАЗУ (до бродкаста!)
    // outpoint пока неизвестен — используем temporary ID
    self.pending_change_keys.push(ephemeral_entry);
    
    output
} else {
    TransactionOutput::new(change_output_value, pay_to_address_script(&self.inner.change_address))
};
final_outputs.push(change_output);
```

### E4. Финализация Change Keys после бродкаста

После успешного `submit_transaction`:

```rust
// В PendingTransaction::try_submit()
if let Some(stealth_account) = account.as_stealth_account() {
    // Получаем реальный outpoint
    let tx_id = submitted_tx_id;
    let change_index = /* индекс change output */;
    let outpoint = TransactionOutpoint::new(tx_id, change_index);
    
    // Обновляем ephemeral_keys с реальным outpoint
    let entry = self.pending_change_key.take().unwrap();
    stealth_account.ephemeral_keys.write().await
        .insert(outpoint, entry);  // status = Pending
    
    // После Events::Maturity статус меняется на Confirmed
}
```

---

## Часть F: Signer для Stealth

### F1. StealthSigner

**Файл:** [`wallet/core/src/tx/generator/signer.rs`](wallet/core/src/tx/generator/signer.rs)

```rust
pub struct StealthSigner {
    inner: Arc<StealthSignerInner>,
}

struct StealthSignerInner {
    account: Arc<StealthAccount>,
    keydata: PrvKeyData,
    payment_secret: Option<Secret>,
}

impl SignerT for StealthSigner {
    fn try_sign(&self, mutable_tx: SignableTransaction, _addresses: &[Address]) -> Result<SignableTransaction> {
        let entries = &mutable_tx.entries;
        
        for (idx, input) in mutable_tx.tx.inputs.iter_mut().enumerate() {
            let utxo = &entries[idx];
            
            if utxo.script_public_key.version() == STEALTH_SCRIPT_VERSION {
                // Получаем spending key из кеша
                let outpoint = &input.previous_outpoint;
                let ephemeral_keys = self.inner.account.ephemeral_keys.read().await;
                let entry = ephemeral_keys.get(outpoint)
                    .ok_or(Error::EphemeralKeyNotFound(outpoint.clone()))?;
                
                // Schnorr подпись
                let reused = SigHashReusedValuesUnsync::new();
                let sig_hash = calc_schnorr_signature_hash(
                    &mutable_tx.tx, idx, SIG_HASH_ALL, &reused
                );
                let msg = Message::from_digest_slice(sig_hash.as_bytes().as_slice())?;
                
                let keypair = Keypair::from_secret_key(SECP256K1, &entry.data.spending_secret);
                let sig = SECP256K1.sign_schnorr(&msg, &keypair);
                
                // signature_script = [64B sig][1B sighash_type]
                let mut sig_script = Vec::with_capacity(65);
                sig_script.extend_from_slice(&sig.serialize());
                sig_script.push(SIG_HASH_ALL.to_u8());
                
                input.signature_script = sig_script;
            }
        }
        
        Ok(mutable_tx)
    }
}
```

---

## Часть G: Обработка Events (Reorg/Maturity)

### G1. Обработка Events::Reorg

При реорганизации удаляем "призрачные" ephemeral keys:

```rust
impl StealthAccount {
    pub async fn handle_event(&self, event: &Events) -> Result<()> {
        match event {
            Events::Reorg { record } => {
                let mut keys = self.ephemeral_keys.write().await;
                
                for utxo in &record.utxo_entries {
                    let outpoint = utxo.outpoint();
                    if let Some(removed) = keys.remove(&outpoint) {
                        log::info!(
                            "Removed ephemeral key for reorged UTXO: {}:{}",
                            outpoint.transaction_id(), outpoint.index()
                        );
                    }
                }
                
                self.save_ephemeral_keys().await?;
            }
            
            Events::Maturity { record } => {
                // Меняем статус Pending -> Confirmed
                let mut keys = self.ephemeral_keys.write().await;
                
                for utxo in &record.utxo_entries {
                    let outpoint = utxo.outpoint();
                    if let Some(entry) = keys.get_mut(&outpoint) {
                        if entry.status == EphemeralKeyStatus::Pending {
                            entry.status = EphemeralKeyStatus::Confirmed;
                        }
                    }
                }
                
                self.save_ephemeral_keys().await?;
            }
            
            _ => {}
        }
        
        Ok(())
    }
}
```

### G2. Интеграция в UtxoProcessor

```rust
// В UtxoProcessor или Wallet event handler
async fn dispatch_event(&self, event: Box<Events>) {
    // Находим аккаунт по UtxoContextId
    if let Some(account) = self.find_account_by_event(&event) {
        if let Ok(stealth) = account.as_stealth_account() {
            stealth.handle_event(&event).await.ok();
        }
    }
    
    // Существующая логика...
}
```

---

## Часть H: API

### H1. Receive Address

```rust
impl Account for StealthAccount {
    fn receive_address(&self) -> Result<Address> {
        let prefix = match self.wallet().network_type()? {
            NetworkType::Mainnet => Prefix::StealthMainnet,
            _ => Prefix::StealthTestnet,
        };
        
        Ok(Address::new_stealth(
            prefix,
            &self.scan_pubkey.serialize(),
            &self.spend_pubkey.serialize(),
        ))
    }
    
    fn change_address(&self) -> Result<Address> {
        self.receive_address()  // Один адрес на аккаунт
    }
}
```

### H2. Создание аккаунта

```rust
impl Wallet {
    pub async fn create_stealth_account(
        &self,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        name: Option<String>,
    ) -> Result<Arc<StealthAccount>> {
        let prv_key_data = self.get_or_create_prv_key_data(wallet_secret)?;
        let account_index = self.next_account_index(STEALTH_ACCOUNT_KIND)?;
        
        let derivation = StealthKeyDerivation::from_xprv(
            &prv_key_data.get_xprv(payment_secret)?,
            account_index,
        )?;
        
        let account = StealthAccount::try_new(
            &self.inner,
            name,
            prv_key_data.id,
            account_index,
            derivation,
        ).await?;
        
        self.register_account(account.clone()).await?;
        Ok(account)
    }
}
```

---

## Порядок Реализации

1. **A1-A5:** StealthAccount структура и factory
2. **B1:** StealthKeyDerivation
3. **C1-C3:** AccountMetadata с birthday
4. **D1-D2:** StealthScanner и scan()
5. **E1-E4:** Generator модификации (КРИТИЧНО: pre-calc change keys)
6. **F1:** StealthSigner
7. **G1-G2:** Event handlers (Reorg/Maturity)
8. **H1-H2:** API методы
9. **Тесты:** unit и integration

---

## Ключевые Изменяемые Файлы

| Файл | Изменения |
|------|-----------|
| `wallet/core/src/account/variants/stealth.rs` | НОВЫЙ — вся логика StealthAccount |
| `wallet/core/src/account/variants/mod.rs` | Регистрация модуля |
| `wallet/core/src/factory.rs` | Регистрация factory |
| `wallet/core/src/derivation.rs` | StealthKeyDerivation |
| `wallet/core/src/storage/metadata.rs` | creation_daa_score |
| `wallet/core/src/tx/generator/generator.rs` | Stealth change, mass calc |
| `wallet/core/src/tx/generator/signer.rs` | StealthSigner |
| `wallet/core/src/utxo/stealth_scan.rs` | НОВЫЙ — StealthScanner |
| `wallet/core/src/utxo/mod.rs` | Экспорт stealth_scan |
| `wallet/core/Cargo.toml` | Зависимость kaspa-stealth |