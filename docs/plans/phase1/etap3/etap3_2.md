# ФИНАЛЬНЫЙ ДЕТАЛЬНЫЙ ПЛАН: Этап 3 — Интеграция Stealth Addresses в Wallet

## СТАТУС РЕАЛИЗАЦИИ

| Фаза | Описание | Статус |
|------|----------|--------|
| **Фаза 1** | Инфраструктура | ✅ DONE |
| 1.1 | stealth_handler.rs | ✅ |
| 1.2 | ephemeral_keys.rs | ✅ |
| 1.3 | has_stealth_support в RPC | ✅ |
| 1.4 | Новые типы ошибок | ✅ |
| **Фаза 2** | UtxoProcessor | ✅ DONE |
| 2.1 | StealthHandlerStore в Inner | ✅ |
| 2.2 | register/unregister handlers | ✅ |
| 2.3 | handle_utxo_changed для stealth | ✅ |
| 2.4 | cleanup() для stealth | ✅ |
| **Фаза 3** | StealthSigner | ✅ DONE |
| 3.1 | stealth_signer.rs | ✅ |
| 3.2 | try_sign_stealth в PendingTransaction | ✅ |
| **Фаза 4** | StealthAccount | ✅ DONE |
| 4.1 | stealth.rs (constants, Payload, Keys) | ✅ |
| 4.2 | StealthAccount struct + try_new/try_load | ✅ |
| 4.3 | unlock/lock session | ✅ |
| 4.4 | Account trait implementation | ✅ |
| 4.5 | StealthUtxoHandler implementation | ✅ |
| 4.6 | StealthChangeCreatorImpl | ✅ |
| 4.7 | Factory registration | ✅ |
| **Фаза 5** | RPC расширения | ✅ DONE (Stealth scope) |
| **Фаза 6** | Интеграция send() | ✅ DONE |
| 6.1 | StealthAccount::send() override | ✅ |
| 6.2 | Wallet::create_stealth_account() | ✅ |
| 6.3 | unlock в open_impl() | ✅ |
| 6.4 | AccountCreateArgs::Stealth | ✅ |
| 6.5 | as_stealth_account в Account trait | ✅ |
| **Фаза 7** | Тестирование | ✅ DONE (базовые тесты) |
| 7.1 | test_stealth_key_derivation | ✅ |
| 7.2 | test_payload_serialization | ✅ |

---

## 🎯 ДЕТАЛЬНЫЙ ПЛАН ЗАВЕРШЕНИЯ (Фазы 4-7)

### Фаза 4: StealthAccount (КРИТИЧНО)

**Файл:** `wallet/core/src/account/variants/stealth.rs` (НОВЫЙ)

#### 4.1 Создание файла и базовые импорты

```rust
// wallet/core/src/account/variants/stealth.rs

use crate::account::{Account, Inner};
use crate::derivation::AddressDerivationManagerTrait;
use crate::imports::*;
use crate::storage::account::{AccountSettings, AccountStorable};
use crate::storage::ephemeral_keys::{EphemeralKeyData, EphemeralKeyStore};
use crate::storage::{AccountMetadata, PrvKeyDataId, Storable, StorageHeader};
use crate::tx::generator::stealth_change::{
    DynStealthChangeCreator, PendingStealthChange, StealthChangeCreator, StealthChangeCreatorImpl,
};
use crate::tx::generator::stealth_signer::StealthSigner;
use crate::utxo::stealth_handler::StealthUtxoHandler;
use crate::utxo::UtxoContext;
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_bip32::{ChildNumber, DerivationPath, ExtendedPrivateKey};
use kaspa_consensus_core::network::NetworkId;
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_rpc_core::RpcUtxosByAddressesEntry;
use kaspa_stealth::{check_view_tag, derive_spending_key, scan_output, StealthAddress};
use kaspa_txscript::extract_stealth_output;
use kaspa_txscript::STEALTH_SCRIPT_VERSION;
use secp256k1::{PublicKey, SecretKey, SECP256K1};
use std::sync::Arc;
use tokio::sync::RwLock;
use zeroize::Zeroize;
```

**Уверенность: 95%** — Импорты основаны на существующих account variants.

---

#### 4.2 Константы

```rust
pub const STEALTH_ACCOUNT_KIND: &str = "kaspa-stealth";
pub const STEALTH_COIN_TYPE: u32 = 111111;
pub const STEALTH_SPEND_CHANGE: u32 = 0; // m/44'/111111'/account'/0'/0
pub const STEALTH_SCAN_CHANGE: u32 = 1;  // m/44'/111111'/account'/1'/0
```

**Уверенность: 98%** — Константы соответствуют плану из etap3_answers.md.

---

#### 4.3 Payload (сериализуемые данные для хранения)

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Payload {
    pub account_index: u64,
    pub scan_pubkey: Vec<u8>,   // 32 bytes x-only (XOnlyPublicKey)
    pub spend_pubkey: Vec<u8>,  // 32 bytes x-only (XOnlyPublicKey)
    pub creation_daa_score: Option<u64>,
}

impl Payload {
    pub fn new(
        account_index: u64,
        scan_pubkey: XOnlyPublicKey,
        spend_pubkey: XOnlyPublicKey,
        creation_daa_score: Option<u64>,
    ) -> Self {
        Self {
            account_index,
            scan_pubkey: scan_pubkey.serialize().to_vec(), // 32 bytes
            spend_pubkey: spend_pubkey.serialize().to_vec(), // 32 bytes
            creation_daa_score,
        }
    }
}

impl Storable for Payload {
    const STORAGE_MAGIC: u32 = 0x53544C48; // "STLH"
    const STORAGE_VERSION: u32 = 0;
}

impl AccountStorable for Payload {}
```

**Уверенность: 95%** — Следует паттерну из `bip32.rs`. `XOnlyPublicKey::serialize()` возвращает `[u8; 32]`.

---

#### 4.4 UnlockedStealthKeys (в памяти только когда разблокировано)

```rust
pub struct UnlockedStealthKeys {
    pub scan_secret: SecretKey,
    pub spend_secret: SecretKey,
}

impl Drop for UnlockedStealthKeys {
    fn drop(&mut self) {
        // secp256k1::SecretKey имеет метод non_secure_erase()
        // сгенерированный макросом impl_non_secure_erase!
        // Он корректно перезаписывает внутренний [u8; 32] без unsafe
        self.scan_secret.non_secure_erase();
        self.spend_secret.non_secure_erase();
    }
}
```

**Уверенность: 95%** — `SecretKey::non_secure_erase()` уже есть в secp256k1 (см. `impl_non_secure_erase!` макрос). Безопасно, без unsafe, корректно обнуляет память.

---

#### 4.5 StealthKeyDerivation (деривация из xprv)

```rust
use secp256k1::{PublicKey, SecretKey, XOnlyPublicKey, SECP256K1};

pub struct StealthKeyDerivation {
    pub scan_secret: SecretKey,
    pub spend_secret: SecretKey,
    pub scan_pubkey: XOnlyPublicKey,   // X-only для stealth (32 bytes)
    pub spend_pubkey: XOnlyPublicKey,  // X-only для stealth (32 bytes)
}

impl StealthKeyDerivation {
    /// Derives: m/44'/111111'/account'/0'/0 (spend), m/44'/111111'/account'/1'/0 (scan)
    pub fn from_xprv(
        xprv: &ExtendedPrivateKey<secp256k1::SecretKey>,
        account_index: u64,
    ) -> Result<Self> {
        // Spend path: m/44'/111111'/account'/0'/0
        let spend_path = DerivationPath::new(vec![
            ChildNumber::new(44, true)?,
            ChildNumber::new(STEALTH_COIN_TYPE, true)?,
            ChildNumber::new(account_index as u32, true)?,
            ChildNumber::new(STEALTH_SPEND_CHANGE, true)?,
            ChildNumber::new(0, false)?,
        ]);
        let spend_xprv = xprv.derive_path(&spend_path)?;
        let spend_secret = *spend_xprv.private_key(); // returns &SecretKey, копируем
        let spend_pubkey_full = PublicKey::from_secret_key(SECP256K1, &spend_secret);
        let (spend_pubkey, _parity) = spend_pubkey_full.x_only_public_key();

        // Scan path: m/44'/111111'/account'/1'/0
        let scan_path = DerivationPath::new(vec![
            ChildNumber::new(44, true)?,
            ChildNumber::new(STEALTH_COIN_TYPE, true)?,
            ChildNumber::new(account_index as u32, true)?,
            ChildNumber::new(STEALTH_SCAN_CHANGE, true)?,
            ChildNumber::new(0, false)?,
        ]);
        let scan_xprv = xprv.derive_path(&scan_path)?;
        let scan_secret = *scan_xprv.private_key();
        let scan_pubkey_full = PublicKey::from_secret_key(SECP256K1, &scan_secret);
        let (scan_pubkey, _parity) = scan_pubkey_full.x_only_public_key();

        Ok(Self { scan_secret, spend_secret, scan_pubkey, spend_pubkey })
    }
}
```

**Уверенность: 95%** — `ExtendedPrivateKey::private_key()` возвращает `&SecretKey`. Паттерн идентичен `wallet/core/src/account/mod.rs` (методы `derive_private_key`). Используем `XOnlyPublicKey` для 32-байтового формата.

---

#### 4.6 StealthAccount struct

```rust
pub struct StealthAccount {
    inner: Arc<Inner>,
    prv_key_data_id: PrvKeyDataId,
    account_index: u64,
    scan_pubkey: XOnlyPublicKey,   // 32 bytes x-only
    spend_pubkey: XOnlyPublicKey,  // 32 bytes x-only
    stealth_address: StealthAddress,
    unlocked_keys: Arc<RwLock<Option<UnlockedStealthKeys>>>,
    ephemeral_keys: Arc<EphemeralKeyStore>,
    creation_daa_score: Option<u64>,
}
```

**Уверенность: 95%** — Структура соответствует архитектуре. `XOnlyPublicKey` для 32-байтовых ключей (как требует `Version::Stealth`).

---

#### 4.7 try_new() и try_load()

**try_new()** — создание нового аккаунта:
```rust
impl StealthAccount {
    pub async fn try_new(
        wallet: &Arc<Wallet>,
        name: Option<String>,
        prv_key_data_id: PrvKeyDataId,
        account_index: u64,
        scan_pubkey: XOnlyPublicKey,
        spend_pubkey: XOnlyPublicKey,
        creation_daa_score: Option<u64>,
    ) -> Result<Self> {
        let stealth_address = StealthAddress::new(scan_pubkey, spend_pubkey);
        let storable = Payload::new(account_index, scan_pubkey, spend_pubkey, creation_daa_score);
        let settings = AccountSettings { name, ..Default::default() };
        
        // Генерация ID аналогично bip32.rs
        let (id, storage_key) = make_account_hashes(from_stealth(&prv_key_data_id, &storable));
        let inner = Arc::new(Inner::new(wallet, id, storage_key, settings));
        let ephemeral_keys = Arc::new(EphemeralKeyStore::new(id));

        Ok(Self {
            inner,
            prv_key_data_id,
            account_index,
            scan_pubkey,
            spend_pubkey,
            stealth_address,
            unlocked_keys: Arc::new(RwLock::new(None)),
            ephemeral_keys,
            creation_daa_score,
        })
    }
}
```

**try_load()** — загрузка из storage:
```rust
pub async fn try_load(
    wallet: &Arc<Wallet>,
    storage: &AccountStorage,
    _meta: Option<Arc<AccountMetadata>>,
) -> Result<Self> {
    let payload = Payload::try_load(storage)?;
    let prv_key_data_id: PrvKeyDataId = storage.prv_key_data_ids.clone().try_into()?;
    let inner = Arc::new(Inner::from_storage(wallet, storage));

    // XOnlyPublicKey::from_slice требует 32 байта
    let scan_pubkey = XOnlyPublicKey::from_slice(&payload.scan_pubkey)?;
    let spend_pubkey = XOnlyPublicKey::from_slice(&payload.spend_pubkey)?;
    let stealth_address = StealthAddress::new(scan_pubkey, spend_pubkey);

    let ephemeral_keys = Arc::new(EphemeralKeyStore::new(*inner.id()));

    // КРИТИЧНО: Загружаем ephemeral keys здесь НЕ нужно!
    // Они загружаются при unlock() когда есть wallet_secret

    Ok(Self {
        inner,
        prv_key_data_id,
        account_index: payload.account_index,
        scan_pubkey,
        spend_pubkey,
        stealth_address,
        unlocked_keys: Arc::new(RwLock::new(None)),
        ephemeral_keys,
        creation_daa_score: payload.creation_daa_score,
    })
}
```

**Уверенность: 95%** — `from_stealth()` нужно создать в `deterministic.rs` по аналогии с `from_bip32()`.

---

#### 4.8 unlock() / lock()

```rust
pub async fn unlock(&self, wallet_secret: &Secret, payment_secret: Option<&Secret>) -> Result<()> {
    // 1. Получить prv_key_data
    let prv_key_data = self.prv_key_data(wallet_secret.clone()).await?;
    let payload = prv_key_data.payload.decrypt(payment_secret)?;
    let xprv = payload.get_xprv(payment_secret)?;

    // 2. Деривировать ключи
    let derivation = StealthKeyDerivation::from_xprv(&xprv, self.account_index)?;

    // 3. Сохранить в unlocked_keys
    let mut keys = self.unlocked_keys.write().await;
    *keys = Some(UnlockedStealthKeys {
        scan_secret: derivation.scan_secret,
        spend_secret: derivation.spend_secret,
    });

    // 4. Загрузить ephemeral_keys
    let wallet_folder = self.wallet().store().location()?;
    let network_id = self.wallet().network_id()?;
    self.ephemeral_keys.load_from_storage(&wallet_folder, network_id, wallet_secret).await?;

    Ok(())
}

pub async fn lock(&self) {
    let mut keys = self.unlocked_keys.write().await;
    if let Some(ref mut k) = *keys {
        k.zeroize();
    }
    *keys = None;
    // ephemeral_keys остаются в памяти для подписания
}

pub async fn is_unlocked(&self) -> bool {
    self.unlocked_keys.read().await.is_some()
}
```

**Уверенность: 80%** — Нужно проверить API `prv_key_data.payload.decrypt()` и `get_xprv()`.

---

#### 4.9 Account trait implementation (частичный)

```rust
#[async_trait]
impl Account for StealthAccount {
    fn inner(&self) -> &Arc<Inner> { &self.inner }
    fn account_kind(&self) -> AccountKind { STEALTH_ACCOUNT_KIND.into() }
    fn prv_key_data_id(&self) -> Result<&PrvKeyDataId> { Ok(&self.prv_key_data_id) }
    fn as_dyn_arc(self: Arc<Self>) -> Arc<dyn Account> { self }
    fn sig_op_count(&self) -> u8 { 1 }
    fn minimum_signatures(&self) -> u16 { 1 }

    fn receive_address(&self) -> Result<Address> {
        // Version::Stealth требует РОВНО 64 байта: [32 scan][32 spend] (x-only)
        // Address::new() паникует если payload != 64 на mainnet/testnet!
        let prefix = self.wallet().address_prefix()?
            .to_stealth()
            .ok_or(Error::InvalidNetworkPrefix)?;
        
        let mut payload = [0u8; 64];
        payload[..32].copy_from_slice(&self.scan_pubkey.serialize()); // XOnlyPublicKey = 32 bytes
        payload[32..].copy_from_slice(&self.spend_pubkey.serialize());
        Ok(Address::new(prefix, Version::Stealth, &payload))
    }

    fn change_address(&self) -> Result<Address> {
        self.receive_address() // Сдача идёт на тот же stealth address
    }

    fn to_storage(&self) -> Result<AccountStorage> {
        let storable = Payload::new(
            self.account_index,
            self.scan_pubkey,
            self.spend_pubkey,
            self.creation_daa_score,
        );
        AccountStorage::try_new(
            STEALTH_ACCOUNT_KIND.into(),
            self.id(),
            self.storage_key(),
            self.prv_key_data_id.into(),
            self.context().settings.clone(),
            storable,
        )
    }

    fn metadata(&self) -> Result<Option<AccountMetadata>> {
        Ok(None) // Stealth не использует address derivation indexes
    }

    fn descriptor(&self) -> Result<AccountDescriptor> {
        Ok(AccountDescriptor::new(
            STEALTH_ACCOUNT_KIND.into(),
            *self.id(),
            self.name(),
            self.balance(),
            self.prv_key_data_id.into(),
            self.receive_address().ok(),
            self.change_address().ok(),
            None,
        )
        .with_property(AccountDescriptorProperty::AccountIndex, self.account_index.into()))
    }
}
```

**Уверенность: 85%** — Нужно проверить `AccountStorage::try_new()` API.

---

#### 4.10 StealthUtxoHandler implementation

```rust
#[async_trait]
impl StealthUtxoHandler for StealthAccount {
    async fn try_claim_utxo(&self, utxo: &RpcUtxosByAddressesEntry) -> Option<UtxoContext> {
        if !self.is_unlocked().await {
            return None;
        }

        let script = &utxo.utxo_entry.script_public_key;
        if script.version() != STEALTH_SCRIPT_VERSION {
            return None;
        }

        // 1. Parse ephemeral output
        let ephemeral_output = extract_stealth_output(script).ok()?;

        // 2. Get unlocked keys
        let keys = self.unlocked_keys.read().await;
        let keys_ref = keys.as_ref()?;

        // 3. Fast check: View Tag (мгновенный фильтр - отсекает 255/256 UTXO)
        // Порядок: (ephemeral_pubkey, tag, scan_secret)
        if !check_view_tag(&ephemeral_output.ephemeral_pubkey, ephemeral_output.view_tag, &keys_ref.scan_secret) {
            return None;
        }

        // 4. Full ECDH check
        // Порядок аргументов: scan_output(output, scan_secret, spend_pubkey)
        let scan_result = scan_output(&ephemeral_output, &keys_ref.scan_secret, &self.spend_pubkey).ok()?;

        // 5. Derive spending key
        let spending_secret = derive_spending_key(&keys_ref.spend_secret, &scan_result.blinding_factor).ok()?;

        // 6. Store in ephemeral_keys
        let outpoint = TransactionOutpoint::new(utxo.outpoint.transaction_id, utxo.outpoint.index);
        let key_data = EphemeralKeyData::new(
            spending_secret.secret_bytes(),
            scan_result.blinding_factor.to_be_bytes(),
            scan_result.destination_pubkey.serialize(),
        );

        let daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);
        self.ephemeral_keys.store(outpoint, key_data, daa_score).await.ok()?;

        Some(self.utxo_context().clone())
    }

    fn utxo_context(&self) -> &UtxoContext {
        &self.inner.utxo_context
    }

    fn account_id(&self) -> &AccountId {
        self.id()
    }

    fn has_outpoint(&self, outpoint: &TransactionOutpoint) -> bool {
        self.ephemeral_keys.contains(outpoint)
    }

    async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()> {
        self.ephemeral_keys.remove(outpoint).await
    }

    fn ephemeral_key_store(&self) -> Option<Arc<EphemeralKeyStore>> {
        Some(self.ephemeral_keys.clone())
    }
}
```

**Уверенность: 95%** — ключи временного хранения пишутся в `EphemeralKeyStore` сразу в `try_claim_utxo()`, а их сохранение на диск выполняется там, где доступен `wallet_secret` (`finalize_stealth_change` и `send()`).

---

#### 4.11 Factory registration

**Файл:** `wallet/core/src/account/variants/mod.rs`
```rust
pub mod stealth;
pub use stealth::STEALTH_ACCOUNT_KIND;
```

**Файл:** `wallet/core/src/factory.rs`
```rust
// В функции factories():
(STEALTH_ACCOUNT_KIND.into(), Arc::new(stealth::Ctor {})),
```

**Файл:** `wallet/core/src/account/variants/stealth.rs`
```rust
pub struct Ctor {}

#[async_trait]
impl Factory for Ctor {
    fn name(&self) -> String { "stealth".to_string() }
    fn description(&self) -> String { "Qaspa Stealth Address Account".to_string() }

    async fn try_load(
        &self,
        wallet: &Arc<Wallet>,
        storage: &AccountStorage,
        meta: Option<Arc<AccountMetadata>>,
    ) -> Result<Arc<dyn Account>> {
        Ok(Arc::new(StealthAccount::try_load(wallet, storage, meta).await?))
    }
}
```

**Уверенность: 95%**

---

### Фаза 5: RPC расширения (ГОТОВО)

#### 5.1 StealthUtxosChangedScope и RPC подписки

Сейчас реализовано полное прохождение уведомлений по скрипт-версии:

- `rpc/core/src/model/message.rs` — добавлены `NotifyStealthUtxosChangedRequest/Response` и `StealthUtxosChangedNotification`.
- `notify/src/events.rs`, `notify/src/scope.rs`, `notify/src/subscription/single.rs` — новый `StealthUtxosChangedScope` и соответствующая подписка.
- `rpc/service/src/service.rs` — `start_notify()`/`stop_notify()` умеют принимать scope и ограничивают только blanket‑подписки в safe‑mode.
- `wallet/core/src/utxo/processor.rs` — при регистрации первого handler'а вызывается `register_stealth_notifications()`, при последнем — `unregister_stealth_notifications()`.

#### 5.2 (опционально) GetUtxosByScriptVersion

RPC поток закрывает realtime‑часть, но ускоренное восстановление всё ещё можно улучшить отдельным методом `get_utxos_by_script_version`. Это остаётся в бэклоге — MVP работает с fallback‑сканированием, как и ранее.

---

### Фаза 6: Интеграция send()

#### 6.1 StealthAccount::send()

```rust
impl StealthAccount {
    pub async fn send(
        self: Arc<Self>,
        destination: PaymentDestination,
        fee_rate: Option<f64>,
        priority_fee_sompi: Fees,
        payload: Option<Vec<u8>>,
        wallet_secret: Secret,
        payment_secret: Option<Secret>,
        abortable: &Abortable,
        notifier: Option<GenerationNotifier>,
    ) -> Result<(GeneratorSummary, Vec<TransactionId>)> {
        // 1. Unlock если не разблокирован
        if !self.is_unlocked().await {
            self.unlock(&wallet_secret, payment_secret.as_ref()).await?;
        }

        // 2. Создать StealthChangeCreator
        let change_creator = self.create_change_creator().await?;

        // 3. Создать Signer + StealthSigner
        let keydata = self.prv_key_data(wallet_secret.clone()).await?;
        let signer = Arc::new(Signer::new(self.clone().as_dyn_arc(), keydata, payment_secret.clone()));
        let stealth_signer = StealthSigner::new(self.ephemeral_keys.clone());

        // 4. Настроить Generator
        let mut settings = GeneratorSettings::try_new_with_account(
            self.clone().as_dyn_arc(),
            destination,
            fee_rate,
            priority_fee_sompi,
            payload,
        )?;
        settings.stealth_change_creator = Some(change_creator);

        let generator = Generator::try_new(settings, Some(signer), Some(abortable))?;

        // 5. Обработать транзакции
        let mut stream = generator.stream();
        let mut ids = vec![];

        while let Some(transaction) = stream.try_next().await? {
            // 5a. Подписать обычные входы
            transaction.try_sign()?;

            // 5b. При необходимости подписать stealth входы
            if transaction.has_stealth_inputs() {
                transaction.try_sign_stealth(&stealth_signer).await?;
            }

            // 5c. Получить pending stealth change ПЕРЕД submit
            let pending_change = transaction.take_stealth_change();

            // 5d. Отправить
            let tx_id = transaction.try_submit(&self.wallet().rpc_api()).await?;

            // 5e. Финализировать stealth change
            if let Some(pending) = pending_change {
                self.finalize_stealth_change(tx_id, &pending, &wallet_secret).await?;
            }

            ids.push(tx_id);

            if let Some(ref notifier) = notifier {
                notifier(&transaction);
            }

            yield_executor().await;
        }

        Ok((generator.summary(), ids))
    }

    /// Создаёт StealthChangeCreator для Generator
    async fn create_change_creator(&self) -> Result<DynStealthChangeCreator> {
        let keys = self.unlocked_keys.read().await;
        let keys_ref = keys.as_ref().ok_or(Error::AccountLocked)?;

        Ok(Arc::new(StealthChangeCreatorImpl::new(
            self.stealth_address.clone(),
            keys_ref.spend_secret.clone(),
        )))
    }

    /// Сохраняет pre-calculated spending key после submit
    async fn finalize_stealth_change(
        &self,
        tx_id: TransactionId,
        pending: &PendingStealthChange,
        wallet_secret: &Secret,
    ) -> Result<()> {
        let outpoint = TransactionOutpoint::new(tx_id, pending.output_index as u32);

        let key_data = EphemeralKeyData::new_xonly(
            pending.spending_secret.secret_bytes(),
            pending.blinding_factor.to_be_bytes(),
            pending.destination_pubkey.serialize(),
        );

        let daa_score = self.wallet().utxo_processor().current_daa_score().unwrap_or(0);
        self.ephemeral_keys.store(outpoint.clone(), key_data, daa_score).await?;
        self.wallet().utxo_processor().register_stealth_outpoint(outpoint, *self.id());

        if let Ok(StorageDescriptor::Internal(wallet_folder)) = self.wallet().store().location() {
            if let Ok(network_id) = self.wallet().network_id() {
                let _ = self
                    .ephemeral_keys
                    .save_to_storage(&wallet_folder, network_id, wallet_secret)
                    .await;
            }
        }

        Ok(())
    }
}
```

**Уверенность: 95%** — разделение `try_sign()` и `try_sign_stealth()` уже реализовано в `pending.rs`; код выше повторяет производственный путь.

---

#### 6.2 Wallet::create_stealth_account()

```rust
// wallet/core/src/wallet/mod.rs (или api.rs)

impl Wallet {
    pub async fn create_stealth_account(
        self: &Arc<Wallet>,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        prv_key_data_id: PrvKeyDataId,
        account_name: Option<String>,
    ) -> Result<Arc<dyn Account>> {
        let account_store = self.inner.store.clone().as_account_store()?;

        // 1. Загрузить prv_key_data
        let prv_key_data = self.inner.store
            .as_prv_key_data_store()?
            .load_key_data(wallet_secret, &prv_key_data_id)
            .await?
            .ok_or_else(|| Error::PrivateKeyNotFound(prv_key_data_id))?;

        // 2. Определить account_index (следующий свободный)
        let accounts = account_store.clone()
            .iter(Some(prv_key_data_id))
            .await?
            .collect::<Vec<_>>()
            .await;
        let account_index = accounts.into_iter()
            .filter(|a| a.as_ref().ok()
                .and_then(|(a, _)| (a.kind == STEALTH_ACCOUNT_KIND).then_some(true))
                .unwrap_or(false))
            .count() as u64;

        // 3. Деривировать ключи
        let xprv = prv_key_data.payload.decrypt(payment_secret)?.get_xprv(payment_secret)?;
        let derivation = StealthKeyDerivation::from_xprv(&xprv, account_index)?;

        // 4. Получить текущий DAA score
        let creation_daa_score = self.utxo_processor().current_daa_score();

        // 5. Создать account
        let account: Arc<dyn Account> = Arc::new(StealthAccount::try_new(
            self,
            account_name,
            prv_key_data_id,
            account_index,
            derivation.scan_pubkey,
            derivation.spend_pubkey,
            creation_daa_score,
        ).await?);

        // 6. Сохранить
        if account_store.load_single(account.id()).await?.is_some() {
            return Err(Error::AccountAlreadyExists(*account.id()));
        }
        account_store.store_single(&account.to_storage()?, None).await?;
        self.inner.store.commit(wallet_secret).await?;

        Ok(account)
    }
}
```

**Уверенность: 85%** — Следует паттерну из `create_account_bip32()`.

---

### Фаза 7: Тестирование

#### 7.1 Unit тесты (первые)

```rust
// wallet/core/src/account/variants/stealth.rs (внизу)

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stealth_key_derivation() {
        use kaspa_bip32::Mnemonic;
        
        let mnemonic = Mnemonic::random(rand::rngs::OsRng, Default::default());
        let seed = mnemonic.to_seed("");
        let xprv = ExtendedPrivateKey::<SecretKey>::new(seed).unwrap();

        let derivation = StealthKeyDerivation::from_xprv(&xprv, 0).unwrap();

        // Проверяем что ключи валидны
        assert_eq!(derivation.scan_pubkey.serialize().len(), 33);
        assert_eq!(derivation.spend_pubkey.serialize().len(), 33);

        // Проверяем детерминистичность
        let derivation2 = StealthKeyDerivation::from_xprv(&xprv, 0).unwrap();
        assert_eq!(derivation.scan_pubkey, derivation2.scan_pubkey);
        assert_eq!(derivation.spend_pubkey, derivation2.spend_pubkey);

        // Разные account_index = разные ключи
        let derivation3 = StealthKeyDerivation::from_xprv(&xprv, 1).unwrap();
        assert_ne!(derivation.scan_pubkey, derivation3.scan_pubkey);
    }
}
```

**Уверенность: 90%**

---

## 📊 СВОДКА УВЕРЕННОСТИ ПО ШАГАМ (ОБНОВЛЕНО)

| Шаг | Описание | Уверенность | Комментарий |
|-----|----------|-------------|-------------|
| 4.1 | Импорты | 95% | Стандартные |
| 4.2 | Константы | 98% | Из плана |
| 4.3 | Payload | 95% | `XOnlyPublicKey::serialize()` = 32 bytes ✅ |
| 4.4 | UnlockedStealthKeys | **95%** | `SecretKey::non_secure_erase()` без unsafe ✅ |
| 4.5 | StealthKeyDerivation | **95%** | API kaspa_bip32 подтверждён ✅ |
| 4.6 | StealthAccount struct | 95% | `XOnlyPublicKey` для 32-байт ключей ✅ |
| 4.7 | try_new/try_load | 95% | Нужна `from_stealth()` |
| 4.8 | unlock/lock | 90% | API PrvKeyData как в bip32.rs |
| 4.9 | Account trait | **95%** | `prefix.to_stealth()` + 64 bytes payload ✅ |
| 4.10 | StealthUtxoHandler | **95%** | API подтверждён: `scan_output(output, scan, spend)` ✅ |
| 4.11 | Factory | 95% | Стандартно |
| 5.1 | RPC | 70% | Опционально для MVP |
| 6.1 | send() | 95% | `try_sign()` + `try_sign_stealth()` уже реализованы ✅ |
| 6.2 | create_stealth_account | 90% | По паттерну bip32 |
| 7.1 | Unit tests | 90% | Ок |

---

## ✅ Ключевые вопросы

### Вопрос 1: Персистентность `EphemeralKeyData`

- Ключи сразу попадают в `EphemeralKeyStore` (in-memory) внутри `try_claim_utxo()`.
- Запись на диск происходит только там, где есть `wallet_secret` (`StealthAccount::send()` / `finalize_stealth_change`), поэтому `UtxoProcessor` больше не оперирует секретами.
- Следующий шаг — интеграционный тест восстановления (проверка `load_from_storage()` после `unlock()`).

### Вопрос 2: `from_stealth()` в `deterministic.rs`

```rust
pub fn from_stealth<const N: usize>(prv_key_data_id: &PrvKeyDataId, data: &stealth::Payload) -> [Hash; N] {
    let hashable = DeterministicHashData {
        account_kind: &stealth::STEALTH_ACCOUNT_KIND.into(),
        prv_key_data_ids: &Some([*prv_key_data_id]),
        ecdsa: Some(false),
        account_index: Some(data.account_index),
        secp256k1_public_key: None,
        data: Some(data.scan_pubkey.clone()),
    };
    make_hashes(hashable)
}
```

Функция уже в кодовой базе; новые аккаунты используют её при генерации `AccountId`.

```rust
use crate::account::stealth; // Добавить импорт

/// Create deterministic hashes from stealth account data.
pub fn from_stealth<const N: usize>(prv_key_data_id: &PrvKeyDataId, data: &stealth::Payload) -> [Hash; N] {
    let hashable = DeterministicHashData {
        account_kind: &stealth::STEALTH_ACCOUNT_KIND.into(),
        prv_key_data_ids: &Some([*prv_key_data_id]),
        ecdsa: Some(false), // Stealth использует Schnorr, не ECDSA
        account_index: Some(data.account_index),
        secp256k1_public_key: None,
        data: Some(borsh::to_vec(&data.scan_pubkey).unwrap()), // Уникальный идентификатор
    };
    make_hashes(hashable)
}
```

**Уверенность: 95%** — Следует паттерну из `from_bip32()`.

---

### Решение вопроса 3: Когда сохранять `EphemeralKeyData`?

| Сценарий | Механизм | Статус |
|----------|----------|--------|
| После получения UTXO | `try_claim_utxo()` кладёт ключ в `EphemeralKeyStore` (RAM) | ✅ |
| После успешной отправки TX | `StealthAccount::send()` + `finalize_stealth_change()` — запись в `EphemeralKeyStore` и вызов `save_to_storage()` с `wallet_secret` | ✅ |
| Восстановление | `unlock()` вызывает `EphemeralKeyStore::load_from_storage()` | ✅ |

**Вывод:** трейту `StealthUtxoHandler` не нужно знать о `wallet_secret`; вся персистентность сконцентрирована в `StealthAccount`.

---

## 📋 ПОРЯДОК РЕАЛИЗАЦИИ (рекомендуемый)

### Этап A: Базовая структура (1-2 дня)

1. **Создать `stealth.rs`** с константами, Payload, UnlockedStealthKeys
2. **Добавить `from_stealth()`** в `deterministic.rs`
3. **Добавить BorshSerialize/Deserialize** для Payload
4. **Зарегистрировать** в `variants/mod.rs` и `factory.rs`
5. **Компиляция** — убедиться что базовая структура компилируется

### Этап B: StealthKeyDerivation (0.5 дня)

1. **Реализовать** `StealthKeyDerivation::from_xprv()`
2. **Unit test** для деривации
3. **Проверить** совместимость с kaspa_bip32

### Этап C: StealthAccount struct (1 день)

1. **Реализовать** `try_new()`, `try_load()`
2. **Реализовать** `unlock()`, `lock()`, `is_unlocked()`
3. **Unit test** для unlock/lock цикла

### Этап D: Account trait (1 день)

1. **Реализовать** все методы Account trait
2. **Особое внимание** на `receive_address()`, `to_storage()`
3. **Тесты** для сериализации/десериализации

### Этап E: StealthUtxoHandler (1 день)

1. **Реализовать** `try_claim_utxo()` с ViewTag + ECDH
2. **Реализовать** остальные методы trait
3. **Интеграционный тест** с mock UTXO

### Этап F: send() и интеграция (1-2 дня)

1. **Реализовать** `StealthAccount::send()`
2. **Реализовать** `create_stealth_account()` в Wallet
3. **End-to-end test** send/receive

### Этап G: Тестирование (1 день)

1. **Unit tests** для всех компонентов
2. **Integration tests** для полного flow
3. **Ручное тестирование** на testnet

---

## 📊 ИТОГОВАЯ ОЦЕНКА

| Компонент | Уверенность | Риски |
|-----------|-------------|-------|
| Payload/Storage | 95% | `XOnlyPublicKey` 32 bytes ✅ |
| StealthKeyDerivation | 95% | API подтверждён ✅ |
| unlock/lock | 95% | `non_secure_erase()` без unsafe ✅ |
| Account trait | 95% | `prefix.to_stealth()` + 64 bytes ✅ |
| StealthUtxoHandler | 95% | `scan_output(output, scan, spend)` ✅ |
| send() flow | 95% | `try_sign()` + `try_sign_stealth()` готовы ✅ |
| **Общая** | **~95%** | **Готов к реализации!** |

---

## 🔥 КРИТИЧЕСКИЙ PATH

```
from_stealth() → Payload → StealthAccount → Account trait → StealthUtxoHandler → send()
```

Если любой из этих компонентов не работает — всё останавливается.

**Рекомендация:** Начать с минимального `StealthAccount` который:
1. Компилируется
2. Регистрируется в Factory
3. Может быть создан через `create_stealth_account()`
4. Возвращает корректный `receive_address()`

Затем добавлять функциональность итеративно.

---

## Оглавление

1. [Обзор и Зависимости](#1-обзор-и-зависимости)
2. [Часть A: StealthAccount](#2-часть-a-stealthaccount)
3. [Часть B: Расширение UtxoProcessor](#3-часть-b-расширение-utxoprocessor)
4. [Часть C: StealthSigner](#4-часть-c-stealthsigner)
5. [Часть D: Хранилище EphemeralKeys](#5-часть-d-хранилище-ephemeralkeys)
6. [Часть E: RPC Расширения](#6-часть-e-rpc-расширения)
7. [Часть F: Интеграция send() и финализация](#7-часть-f-интеграция-send-и-финализация)
8. [Часть G: Тестирование](#8-часть-g-тестирование)
9. [Порядок реализации](#9-порядок-реализации)

---

## 1. Обзор и Зависимости

### 1.1 Что уже сделано (Этап 3.1)

✅ `StealthChangeCreator` trait и `PendingStealthChange`
✅ Модификация `Generator` для stealth change outputs
✅ Mass calculation для stealth outputs
✅ `create_stealth_output_with_blinding()` в kaspa-stealth
✅ Базовые тесты

### 1.2 Что нужно сделать

```
┌─────────────────────────────────────────────────────────────────┐
│                     АРХИТЕКТУРА ЭТАПА 3                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐     ┌─────────────────┐                   │
│  │ StealthAccount  │────▶│  UtxoProcessor  │                   │
│  │   (Часть A)     │     │   (Часть B)     │                   │
│  └────────┬────────┘     └────────┬────────┘                   │
│           │                       │                             │
│           ▼                       ▼                             │
│  ┌─────────────────┐     ┌─────────────────┐                   │
│  │ StealthSigner   │     │ StealthHandler  │                   │
│  │   (Часть C)     │     │   (Часть B)     │                   │
│  └────────┬────────┘     └────────┬────────┘                   │
│           │                       │                             │
│           ▼                       ▼                             │
│  ┌─────────────────┐     ┌─────────────────┐                   │
│  │ EphemeralKeys   │◀───▶│  RPC Extension  │                   │
│  │   (Часть D)     │     │   (Часть E)     │                   │
│  └─────────────────┘     └─────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Зависимости между частями

```
Часть E (RPC) ──┐
                ├──▶ Часть B (UtxoProcessor) ──┐
Часть D (Storage)──┘                           │
                                               ├──▶ Часть A (StealthAccount)
Часть C (Signer) ─────────────────────────────┘
                                               │
                                               ▼
                                    Часть F (Integration)
                                               │
                                               ▼
                                    Часть G (Tests)
```

---

## 2. Часть A: StealthAccount

### 2.1 Константы и типы

**Файл:** `wallet/core/src/account/variants/stealth.rs` (НОВЫЙ)

```rust
//! Stealth Address Account Implementation
//!
//! Provides privacy-preserving transactions using ECDH-based stealth addresses.

use crate::account::{Account, Inner};
use crate::derivation::AddressDerivationManagerTrait;
use crate::imports::*;
use crate::storage::account::{AccountSettings, AccountStorable};
use crate::storage::{AccountMetadata, Storable};
use crate::tx::generator::stealth_change::{PendingStealthChange, StealthChangeCreator};
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_bip32::{ChildNumber, DerivationPath, ExtendedPrivateKey, SecretKey};
use kaspa_stealth::{StealthAddress, StealthSecretKey};
use secp256k1::Scalar;
use std::sync::Arc;
use tokio::sync::RwLock;
use zeroize::Zeroize;

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

/// Account kind identifier for stealth accounts
pub const STEALTH_ACCOUNT_KIND: &str = "qaspa-stealth";

/// BIP-44 coin type for stealth derivation (custom)
pub const STEALTH_COIN_TYPE: u32 = 111111;

/// Derivation path change index for spend key: m/44'/111111'/account'/0'/0
pub const STEALTH_SPEND_CHANGE: u32 = 0;

/// Derivation path change index for scan key: m/44'/111111'/account'/1'/0
pub const STEALTH_SCAN_CHANGE: u32 = 1;

/// Script version for stealth outputs (from consensus)
pub const STEALTH_SCRIPT_VERSION: u16 = 16;
```

### 2.2 Payload для хранения

```rust
// ============================================================================
// STORAGE PAYLOAD
// ============================================================================

/// Serializable payload stored in AccountStorage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Payload {
    /// Account index in HD derivation
    pub account_index: u64,
    
    /// Compressed scan public key (33 bytes)
    pub scan_pubkey: [u8; 33],
    
    /// Compressed spend public key (33 bytes)  
    pub spend_pubkey: [u8; 33],
    
    /// DAA score when account was created (for faster restoration)
    pub creation_daa_score: Option<u64>,
}

impl Payload {
    pub fn new(
        account_index: u64,
        scan_pubkey: secp256k1::PublicKey,
        spend_pubkey: secp256k1::PublicKey,
        creation_daa_score: Option<u64>,
    ) -> Self {
        Self {
            account_index,
            scan_pubkey: scan_pubkey.serialize(),
            spend_pubkey: spend_pubkey.serialize(),
            creation_daa_score,
        }
    }
    
    pub fn try_load(storage: &AccountStorage) -> Result<Self> {
        Ok(Self::try_from_slice(storage.serialized.as_slice())?)
    }
    
    pub fn scan_pubkey(&self) -> Result<secp256k1::PublicKey> {
        Ok(secp256k1::PublicKey::from_slice(&self.scan_pubkey)?)
    }
    
    pub fn spend_pubkey(&self) -> Result<secp256k1::PublicKey> {
        Ok(secp256k1::PublicKey::from_slice(&self.spend_pubkey)?)
    }
}

impl Storable for Payload {
    const STORAGE_MAGIC: u32 = 0x53544C48; // "STLH"
    const STORAGE_VERSION: u32 = 0;
}

impl AccountStorable for Payload {}

impl BorshSerialize for Payload {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        StorageHeader::new(Self::STORAGE_MAGIC, Self::STORAGE_VERSION).serialize(writer)?;
        BorshSerialize::serialize(&self.account_index, writer)?;
        BorshSerialize::serialize(&self.scan_pubkey.to_vec(), writer)?;
        BorshSerialize::serialize(&self.spend_pubkey.to_vec(), writer)?;
        BorshSerialize::serialize(&self.creation_daa_score, writer)?;
        Ok(())
    }
}

impl BorshDeserialize for Payload {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> IoResult<Self> {
        let StorageHeader { version: _, .. } = StorageHeader::deserialize_reader(reader)?
            .try_magic(Self::STORAGE_MAGIC)?
            .try_version(Self::STORAGE_VERSION)?;
        
        let account_index = BorshDeserialize::deserialize_reader(reader)?;
        let scan_pubkey_vec: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
        let spend_pubkey_vec: Vec<u8> = BorshDeserialize::deserialize_reader(reader)?;
        let creation_daa_score = BorshDeserialize::deserialize_reader(reader)?;
        
        let scan_pubkey: [u8; 33] = scan_pubkey_vec.try_into()
            .map_err(|_| IoError::new(IoErrorKind::InvalidData, "invalid scan_pubkey length"))?;
        let spend_pubkey: [u8; 33] = spend_pubkey_vec.try_into()
            .map_err(|_| IoError::new(IoErrorKind::InvalidData, "invalid spend_pubkey length"))?;
        
        Ok(Self { account_index, scan_pubkey, spend_pubkey, creation_daa_score })
    }
}
```

### 2.3 Unlocked Keys структура

```rust
// ============================================================================
// UNLOCK SESSION
// ============================================================================

/// Decrypted stealth keys held in memory during unlocked session.
/// These are zeroized when the account is locked.
pub struct UnlockedStealthKeys {
    /// Private key for scanning incoming transactions
    pub scan_secret: secp256k1::SecretKey,
    /// Private key for spending
    pub spend_secret: secp256k1::SecretKey,
}

impl Zeroize for UnlockedStealthKeys {
    fn zeroize(&mut self) {
        // SecretKey doesn't implement Zeroize directly, but we can
        // overwrite the memory by creating new keys
        let zero_bytes = [0u8; 32];
        // Note: In production, use proper secure memory handling
        unsafe {
            let scan_ptr = &self.scan_secret as *const _ as *mut [u8; 32];
            let spend_ptr = &self.spend_secret as *const _ as *mut [u8; 32];
            std::ptr::write_volatile(scan_ptr, zero_bytes);
            std::ptr::write_volatile(spend_ptr, zero_bytes);
        }
    }
}

impl Drop for UnlockedStealthKeys {
    fn drop(&mut self) {
        self.zeroize();
    }
}
```

### 2.4 Key Derivation

```rust
// ============================================================================
// KEY DERIVATION
// ============================================================================

/// Derives stealth keys from extended private key
pub struct StealthKeyDerivation {
    pub scan_secret: secp256k1::SecretKey,
    pub spend_secret: secp256k1::SecretKey,
    pub scan_pubkey: secp256k1::PublicKey,
    pub spend_pubkey: secp256k1::PublicKey,
}

impl StealthKeyDerivation {
    /// Derives stealth keys from xprv using BIP-44 paths:
    /// - Spend: m/44'/111111'/account'/0'/0
    /// - Scan:  m/44'/111111'/account'/1'/0
    pub fn from_xprv(
        xprv: &ExtendedPrivateKey<secp256k1::SecretKey>,
        account_index: u64,
    ) -> Result<Self> {
        // Derive spend key: m/44'/111111'/account'/0'/0
        let spend_path = DerivationPath::new(vec![
            ChildNumber::new(44, true)?,
            ChildNumber::new(STEALTH_COIN_TYPE, true)?,
            ChildNumber::new(account_index as u32, true)?,
            ChildNumber::new(STEALTH_SPEND_CHANGE, true)?,
            ChildNumber::new(0, false)?,
        ]);
        let spend_xprv = xprv.derive_path(&spend_path)?;
        let spend_secret = *spend_xprv.private_key();
        let spend_pubkey = secp256k1::PublicKey::from_secret_key(secp256k1::SECP256K1, &spend_secret);
        
        // Derive scan key: m/44'/111111'/account'/1'/0
        let scan_path = DerivationPath::new(vec![
            ChildNumber::new(44, true)?,
            ChildNumber::new(STEALTH_COIN_TYPE, true)?,
            ChildNumber::new(account_index as u32, true)?,
            ChildNumber::new(STEALTH_SCAN_CHANGE, true)?,
            ChildNumber::new(0, false)?,
        ]);
        let scan_xprv = xprv.derive_path(&scan_path)?;
        let scan_secret = *scan_xprv.private_key();
        let scan_pubkey = secp256k1::PublicKey::from_secret_key(secp256k1::SECP256K1, &scan_secret);
        
        Ok(Self {
            scan_secret,
            spend_secret,
            scan_pubkey,
            spend_pubkey,
        })
    }
    
    /// Creates a StealthAddress from the derived public keys
    pub fn to_stealth_address(&self) -> StealthAddress {
        StealthAddress::new(self.scan_pubkey, self.spend_pubkey)
    }
    
    /// Creates unlocked keys structure
    pub fn to_unlocked_keys(&self) -> UnlockedStealthKeys {
        UnlockedStealthKeys {
            scan_secret: self.scan_secret.clone(),
            spend_secret: self.spend_secret.clone(),
        }
    }
}
```

### 2.5 Factory

```rust
// ============================================================================
// FACTORY
// ============================================================================

pub struct Ctor {}

#[async_trait]
impl Factory for Ctor {
    fn name(&self) -> String {
        "stealth".to_string()
    }
    
    fn description(&self) -> String {
        "Qaspa Stealth Address Account".to_string()
    }
    
    async fn try_load(
        &self,
        wallet: &Arc<Wallet>,
        storage: &AccountStorage,
        meta: Option<Arc<AccountMetadata>>,
    ) -> Result<Arc<dyn Account>> {
        Ok(Arc::new(StealthAccount::try_load(wallet, storage, meta).await?))
    }
}
```

### 2.6 StealthAccount структура

```rust
// ============================================================================
// STEALTH ACCOUNT
// ============================================================================

pub struct StealthAccount {
    inner: Arc<Inner>,
    prv_key_data_id: PrvKeyDataId,
    account_index: u64,
    
    /// Public key for scanning incoming transactions
    scan_pubkey: secp256k1::PublicKey,
    
    /// Public key for spending
    spend_pubkey: secp256k1::PublicKey,
    
    /// Stealth address for receiving funds
    stealth_address: StealthAddress,
    
    /// Unlocked keys (populated after unlock())
    unlocked_keys: Arc<RwLock<Option<UnlockedStealthKeys>>>,
    
    /// Ephemeral key store for spending received UTXOs
    ephemeral_keys: Arc<EphemeralKeyStore>,
    
    /// DAA score when account was created
    creation_daa_score: Option<u64>,
}

impl StealthAccount {
    // ========================================================================
    // CONSTRUCTION
    // ========================================================================
    
    /// Creates a new stealth account
    pub async fn try_new(
        wallet: &Arc<Wallet>,
        name: Option<String>,
        prv_key_data_id: PrvKeyDataId,
        account_index: u64,
        scan_pubkey: secp256k1::PublicKey,
        spend_pubkey: secp256k1::PublicKey,
        creation_daa_score: Option<u64>,
    ) -> Result<Self> {
        let stealth_address = StealthAddress::new(scan_pubkey, spend_pubkey);
        
        let storable = Payload::new(
            account_index,
            scan_pubkey,
            spend_pubkey,
            creation_daa_score,
        );
        
        let settings = AccountSettings { name, ..Default::default() };
        let (id, storage_key) = make_account_hashes(from_stealth(&prv_key_data_id, &storable));
        let inner = Arc::new(Inner::new(wallet, id, storage_key, settings));
        
        let ephemeral_keys = Arc::new(EphemeralKeyStore::new(id));
        
        Ok(Self {
            inner,
            prv_key_data_id,
            account_index,
            scan_pubkey,
            spend_pubkey,
            stealth_address,
            unlocked_keys: Arc::new(RwLock::new(None)),
            ephemeral_keys,
            creation_daa_score,
        })
    }
    
    /// Loads an existing stealth account from storage
    pub async fn try_load(
        wallet: &Arc<Wallet>,
        storage: &AccountStorage,
        _meta: Option<Arc<AccountMetadata>>,
    ) -> Result<Self> {
        let payload = Payload::try_load(storage)?;
        let prv_key_data_id: PrvKeyDataId = storage.prv_key_data_ids.clone().try_into()?;
        let inner = Arc::new(Inner::from_storage(wallet, storage));
        
        let scan_pubkey = payload.scan_pubkey()?;
        let spend_pubkey = payload.spend_pubkey()?;
        let stealth_address = StealthAddress::new(scan_pubkey, spend_pubkey);
        
        let ephemeral_keys = Arc::new(EphemeralKeyStore::new(*inner.id()));
        
        // Load ephemeral keys from storage
        ephemeral_keys.load_from_storage(wallet).await?;
        
        Ok(Self {
            inner,
            prv_key_data_id,
            account_index: payload.account_index,
            scan_pubkey,
            spend_pubkey,
            stealth_address,
            unlocked_keys: Arc::new(RwLock::new(None)),
            ephemeral_keys,
            creation_daa_score: payload.creation_daa_score,
        })
    }
    
    // ========================================================================
    // UNLOCK / LOCK SESSION
    // ========================================================================
    
    /// Unlocks the account by decrypting and caching the stealth keys.
    /// Must be called before scanning or claiming UTXOs.
    pub async fn unlock(
        &self,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
    ) -> Result<()> {
        let prv_key_data = self.prv_key_data(wallet_secret.clone()).await?;
        let payload = prv_key_data.payload.decrypt(payment_secret)?;
        let xprv = payload.get_xprv(payment_secret)?;
        
        let derivation = StealthKeyDerivation::from_xprv(&xprv, self.account_index)?;
        
        let mut keys = self.unlocked_keys.write().await;
        *keys = Some(derivation.to_unlocked_keys());
        
        Ok(())
    }
    
    /// Locks the account by clearing cached keys from memory.
    pub async fn lock(&self) {
        let mut keys = self.unlocked_keys.write().await;
        if let Some(ref mut k) = *keys {
            k.zeroize();
        }
        *keys = None;
    }
    
    /// Returns true if the account is currently unlocked
    pub async fn is_unlocked(&self) -> bool {
        self.unlocked_keys.read().await.is_some()
    }
    
    /// Returns a reference to the unlocked keys (if unlocked)
    async fn get_unlocked_keys(&self) -> Result<tokio::sync::RwLockReadGuard<'_, Option<UnlockedStealthKeys>>> {
        let keys = self.unlocked_keys.read().await;
        if keys.is_none() {
            return Err(Error::AccountLocked);
        }
        Ok(keys)
    }
    
    // ========================================================================
    // ACCESSORS
    // ========================================================================
    
    pub fn stealth_address(&self) -> &StealthAddress {
        &self.stealth_address
    }
    
    pub fn ephemeral_keys(&self) -> &Arc<EphemeralKeyStore> {
        &self.ephemeral_keys
    }
    
    pub fn account_index(&self) -> u64 {
        self.account_index
    }
    
    // ========================================================================
    // STEALTH CHANGE CREATOR
    // ========================================================================
    
    /// Creates a StealthChangeCreator for use with Generator.
    /// Requires the account to be unlocked.
    pub async fn create_change_creator(&self) -> Result<Arc<dyn StealthChangeCreator>> {
        let keys = self.get_unlocked_keys().await?;
        let keys_ref = keys.as_ref().unwrap();
        
        Ok(Arc::new(StealthChangeCreatorImpl {
            stealth_address: self.stealth_address.clone(),
            spend_secret: keys_ref.spend_secret.clone(),
        }))
    }
}
```

### 2.7 Реализация Account trait

```rust
// ============================================================================
// ACCOUNT TRAIT IMPLEMENTATION
// ============================================================================

#[async_trait]
impl Account for StealthAccount {
    fn inner(&self) -> &Arc<Inner> {
        &self.inner
    }
    
    fn account_kind(&self) -> AccountKind {
        STEALTH_ACCOUNT_KIND.into()
    }
    
    fn prv_key_data_id(&self) -> Result<&PrvKeyDataId> {
        Ok(&self.prv_key_data_id)
    }
    
    fn as_dyn_arc(self: Arc<Self>) -> Arc<dyn Account> {
        self
    }
    
    fn sig_op_count(&self) -> u8 {
        1 // Schnorr signature
    }
    
    fn minimum_signatures(&self) -> u16 {
        1
    }
    
    /// Returns the stealth address encoded as bech32m (qs1...)
    fn receive_address(&self) -> Result<Address> {
        // КРИТИЧНО: Version::Stealth требует РОВНО 64 байта: [32 scan][32 spend]
        // Address::new() паникует если payload != 64 на mainnet/testnet!
        let prefix = self.wallet().address_prefix()?
            .to_stealth()
            .ok_or(Error::InvalidNetworkPrefix)?;
        
        let mut payload = [0u8; 64];
        payload[..32].copy_from_slice(&self.scan_pubkey.serialize()); // XOnlyPublicKey = 32 bytes
        payload[32..].copy_from_slice(&self.spend_pubkey.serialize());
        
        Ok(Address::new(prefix, Version::Stealth, &payload))
    }
    
    /// Change address is the same as receive address for stealth
    fn change_address(&self) -> Result<Address> {
        self.receive_address()
    }
    
    fn to_storage(&self) -> Result<AccountStorage> {
        let settings = self.context().settings.clone();
        let storable = Payload::new(
            self.account_index,
            self.scan_pubkey,
            self.spend_pubkey,
            self.creation_daa_score,
        );
        
        AccountStorage::try_new(
            STEALTH_ACCOUNT_KIND.into(),
            self.id(),
            self.storage_key(),
            self.prv_key_data_id.into(),
            settings,
            storable,
        )
    }
    
    fn metadata(&self) -> Result<Option<AccountMetadata>> {
        // Stealth accounts don't use address derivation indexes
        Ok(None)
    }
    
    fn descriptor(&self) -> Result<AccountDescriptor> {
        let descriptor = AccountDescriptor::new(
            STEALTH_ACCOUNT_KIND.into(),
            *self.id(),
            self.name(),
            self.balance(),
            self.prv_key_data_id.into(),
            self.receive_address().ok(),
            self.change_address().ok(),
            None, // No address list for stealth
        )
        .with_property(AccountDescriptorProperty::AccountIndex, self.account_index.into());
        
        Ok(descriptor)
    }
    
    // ========================================================================
    // LIFECYCLE OVERRIDES
    // ========================================================================
    
    /// Override connect to register stealth handler
    async fn connect(self: Arc<Self>) -> Result<()> {
        // Register stealth handler in UtxoProcessor
        self.wallet().utxo_processor()
            .register_stealth_handler(self.clone())
            .await?;
        
        // Standard connect logic
        let vacated = self.wallet().active_accounts().insert(self.clone().as_dyn_arc());
        if vacated.is_none() && self.wallet().is_connected() {
            self.scan(None, None).await?;
        }
        
        Ok(())
    }
    
    /// Override disconnect to unregister stealth handler
    async fn disconnect(&self) -> Result<()> {
        // Unregister stealth handler
        self.wallet().utxo_processor()
            .unregister_stealth_handler(self.id())
            .await?;
        
        // Standard disconnect logic
        self.wallet().active_accounts().remove(self.id());
        
        Ok(())
    }
    
    /// Override stop to also lock the account
    async fn stop(self: Arc<Self>) -> Result<()> {
        self.lock().await;
        self.utxo_context().clear().await?;
        self.disconnect().await?;
        Ok(())
    }
    
    // ========================================================================
    // SCANNING
    // ========================================================================
    
    /// Scans for stealth UTXOs belonging to this account
    async fn scan(self: Arc<Self>, _window_size: Option<usize>, _extent: Option<u32>) -> Result<()> {
        if !self.is_unlocked().await {
            return Err(Error::AccountLocked);
        }
        
        let rpc = self.wallet().rpc_api();
        let current_daa_score = self.wallet().utxo_processor().current_daa_score();
        
        // Try new RPC method first, fallback to full scan
        let utxos = match rpc.get_utxos_by_script_version(
            STEALTH_SCRIPT_VERSION,
            self.creation_daa_score,
            None, // No cursor for initial scan
            10000, // Limit
        ).await {
            Ok(response) => response.entries,
            Err(RpcError::MethodNotImplemented) => {
                log_warn!("get_utxos_by_script_version not available, using fallback scan");
                self.scan_fallback().await?
            }
            Err(e) => return Err(e.into()),
        };
        
        // Process each UTXO
        for utxo in utxos {
            if let Some(key_data) = self.try_claim_utxo_internal(&utxo).await? {
                let outpoint = TransactionOutpoint::new(
                    utxo.outpoint.transaction_id,
                    utxo.outpoint.index,
                );
                
                // Store ephemeral key
                self.ephemeral_keys.store(
                    outpoint.clone(),
                    key_data,
                    current_daa_score.unwrap_or(0),
                ).await?;
                
                // Add to UTXO context
                let utxo_entry: UtxoEntryReference = (&utxo).into();
                self.utxo_context().insert(utxo_entry, current_daa_score.unwrap_or(0), false).await?;
            }
        }
        
        self.utxo_context().update_balance().await?;
        
        Ok(())
    }
    
    /// Fallback scan when RPC method is not available
    async fn scan_fallback(&self) -> Result<Vec<RpcUtxosByAddressesEntry>> {
        // This is slow but works
        // In production, iterate through virtual UTXO set
        log_warn!("Fallback stealth scan not implemented - requires full UTXO iteration");
        Ok(vec![])
    }
}
```

### 2.8 StealthUtxoHandler реализация

```rust
// ============================================================================
// STEALTH UTXO HANDLER
// ============================================================================

#[async_trait]
impl StealthUtxoHandler for StealthAccount {
    async fn try_claim_utxo(&self, utxo: &RpcUtxosByAddressesEntry) -> Option<UtxoContext> {
        // Must be unlocked to claim
        if !self.is_unlocked().await {
            return None;
        }
        
        match self.try_claim_utxo_internal(utxo).await {
            Ok(Some(key_data)) => {
                let outpoint = TransactionOutpoint::new(
                    utxo.outpoint.transaction_id,
                    utxo.outpoint.index,
                );
                
                let daa_score = self.wallet().utxo_processor()
                    .current_daa_score()
                    .unwrap_or(0);
                
                // Store ephemeral key
                if let Err(e) = self.ephemeral_keys.store(outpoint, key_data, daa_score).await {
                    log_error!("Failed to store ephemeral key: {}", e);
                    return None;
                }
                
                Some(self.utxo_context().clone())
            }
            Ok(None) => None, // Not our UTXO
            Err(e) => {
                log_error!("Error claiming UTXO: {}", e);
                None
            }
        }
    }
    
    fn utxo_context(&self) -> &UtxoContext {
        &self.inner.utxo_context
    }
    
    fn account_id(&self) -> &AccountId {
        self.id()
    }
    
    fn has_outpoint(&self, outpoint: &TransactionOutpoint) -> bool {
        self.ephemeral_keys.contains(outpoint)
    }
    
    async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()> {
        self.ephemeral_keys.remove(outpoint).await
    }
}

impl StealthAccount {
    /// Internal method to check if UTXO belongs to this account
    async fn try_claim_utxo_internal(
        &self,
        utxo: &RpcUtxosByAddressesEntry,
    ) -> Result<Option<EphemeralKeyData>> {
        use kaspa_stealth::{check_view_tag, scan_output};
        use kaspa_txscript::extract_stealth_output;
        
        let script = &utxo.utxo_entry.script_public_key;
        
        // Check script version
        if script.version() != STEALTH_SCRIPT_VERSION {
            return Ok(None);
        }
        
        // Parse ephemeral output from script
        let ephemeral_output = match extract_stealth_output(script) {
            Ok(output) => output,
            Err(_) => return Ok(None),
        };
        
        // Get unlocked keys
        let keys = self.unlocked_keys.read().await;
        let keys_ref = keys.as_ref().ok_or(Error::AccountLocked)?;
        
        // Fast check: View Tag (1 byte comparison) - отсекает 255/256 UTXO мгновенно
        // Порядок: check_view_tag(ephemeral_pubkey, tag, scan_secret)
        if !check_view_tag(
            &ephemeral_output.ephemeral_pubkey,
            ephemeral_output.view_tag,
            &keys_ref.scan_secret,
        ) {
            return Ok(None); // Not our UTXO (fast reject)
        }
        
        // Full check: Compute and verify destination pubkey
        // Порядок: scan_output(output, scan_secret, spend_pubkey)
        match scan_output(
            &ephemeral_output,
            &keys_ref.scan_secret,
            &self.spend_pubkey,
        ) {
            Ok(scan_result) => {
                // Derive spending key
                let spending_secret = kaspa_stealth::derive_spending_key(
                    &keys_ref.spend_secret,
                    &scan_result.blinding_factor,
                )?;
                
                Ok(Some(EphemeralKeyData {
                    spending_secret: spending_secret.secret_bytes(),
                    blinding_factor: scan_result.blinding_factor.to_be_bytes(),
                    destination_pubkey: scan_result.destination_pubkey.serialize(),
                }))
            }
            Err(_) => Ok(None), // False positive from View Tag collision
        }
    }
}
```

### 2.9 StealthChangeCreator реализация

```rust
// ============================================================================
// STEALTH CHANGE CREATOR IMPLEMENTATION
// ============================================================================

struct StealthChangeCreatorImpl {
    stealth_address: StealthAddress,
    spend_secret: secp256k1::SecretKey,
}

impl StealthChangeCreator for StealthChangeCreatorImpl {
    fn create_change_output(&self, amount: u64) -> Result<(TransactionOutput, PendingStealthChange)> {
        use kaspa_stealth::create_stealth_output_with_blinding;
        use kaspa_txscript::pay_to_stealth;
        use rand::rngs::OsRng;
        
        // Create ephemeral output with blinding factor
        let (ephemeral_output, blinding_factor) = 
            create_stealth_output_with_blinding(&self.stealth_address, &mut OsRng)?;
        
        // Pre-compute spending key
        let spending_secret = kaspa_stealth::derive_spending_key(
            &self.spend_secret,
            &blinding_factor,
        )?;
        
        // Create script
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

### 2.10 Регистрация Factory

**Файл:** `wallet/core/src/factory.rs`

```rust
// Добавить в функцию factories():
pub fn factories() -> Vec<Arc<dyn Factory>> {
    vec![
        // ... existing factories ...
        Arc::new(stealth::Ctor {}),
    ]
}
```

**Файл:** `wallet/core/src/account/variants/mod.rs`

```rust
pub mod bip32;
pub mod keypair;
pub mod legacy;
pub mod multisig;
pub mod stealth; // ДОБАВИТЬ

pub use stealth::{StealthAccount, STEALTH_ACCOUNT_KIND};
```

---

## 3. Часть B: Расширение UtxoProcessor

### 3.1 Новый trait StealthUtxoHandler

**Файл:** `wallet/core/src/utxo/stealth_handler.rs` (НОВЫЙ)

```rust
//! Stealth UTXO Handler trait for processing stealth transactions.

use crate::imports::*;
use crate::utxo::UtxoContext;
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_rpc_core::RpcUtxosByAddressesEntry;

/// Handler trait for stealth UTXOs.
/// 
/// Implemented by StealthAccount to receive notifications about
/// stealth UTXOs that may belong to it.
#[async_trait]
pub trait StealthUtxoHandler: Send + Sync {
    /// Attempts to claim a UTXO for this handler.
    /// 
    /// Returns Some(UtxoContext) if the UTXO belongs to this account,
    /// None otherwise.
    /// 
    /// This method should:
    /// 1. Check if script version is STEALTH_SCRIPT_VERSION
    /// 2. Parse the EphemeralOutput from the script
    /// 3. Check View Tag (fast filter)
    /// 4. If View Tag matches, perform full ECDH check
    /// 5. If UTXO belongs to us, derive and store the spending key
    async fn try_claim_utxo(&self, utxo: &RpcUtxosByAddressesEntry) -> Option<UtxoContext>;
    
    /// Returns the UtxoContext for this handler
    fn utxo_context(&self) -> &UtxoContext;
    
    /// Returns the account ID for this handler
    fn account_id(&self) -> &AccountId;
    
    /// Checks if this handler owns the given outpoint
    fn has_outpoint(&self, outpoint: &TransactionOutpoint) -> bool;
    
    /// Called when a UTXO owned by this handler is removed (spent or reorg)
    async fn handle_utxo_removed(&self, outpoint: &TransactionOutpoint) -> Result<()>;
}
```

### 3.2 Расширение Inner в UtxoProcessor

**Файл:** `wallet/core/src/utxo/processor.rs`

```rust
use crate::utxo::stealth_handler::StealthUtxoHandler;
use kaspa_consensus_core::tx::TransactionOutpoint;

pub struct Inner {
    // ... existing fields ...
    
    /// Registered stealth handlers by account ID
    stealth_handlers: DashMap<AccountId, Arc<dyn StealthUtxoHandler>>,
    
    /// Reverse index: outpoint -> account ID (for fast removal lookup)
    stealth_outpoint_index: DashMap<TransactionOutpoint, AccountId>,
}

impl Inner {
    pub fn new(...) -> Self {
        Self {
            // ... existing ...
            stealth_handlers: DashMap::new(),
            stealth_outpoint_index: DashMap::new(),
        }
    }
}
```

### 3.3 Методы регистрации/дерегистрации

```rust
impl UtxoProcessor {
    // ========================================================================
    // STEALTH HANDLER MANAGEMENT
    // ========================================================================
    
    /// Registers a stealth handler for receiving UTXO notifications
    pub async fn register_stealth_handler(
        &self,
        handler: Arc<dyn StealthUtxoHandler>,
    ) -> Result<()> {
        let account_id = *handler.account_id();
        self.inner.stealth_handlers.insert(account_id, handler);
        log_info!("Registered stealth handler for account {}", account_id);
        Ok(())
    }
    
    /// Unregisters a stealth handler
    pub async fn unregister_stealth_handler(&self, account_id: &AccountId) -> Result<()> {
        self.inner.stealth_handlers.remove(account_id);
        
        // Clean up outpoint index for this account
        self.inner.stealth_outpoint_index.retain(|_, id| id != account_id);
        
        log_info!("Unregistered stealth handler for account {}", account_id);
        Ok(())
    }
    
    /// Registers an outpoint in the reverse index
    pub fn register_stealth_outpoint(&self, outpoint: TransactionOutpoint, account_id: AccountId) {
        self.inner.stealth_outpoint_index.insert(outpoint, account_id);
    }
    
    /// Unregisters an outpoint from the reverse index
    pub fn unregister_stealth_outpoint(&self, outpoint: &TransactionOutpoint) {
        self.inner.stealth_outpoint_index.remove(outpoint);
    }
    
    /// Gets the handler for an outpoint (if registered)
    fn get_handler_for_outpoint(&self, outpoint: &TransactionOutpoint) -> Option<Arc<dyn StealthUtxoHandler>> {
        self.inner.stealth_outpoint_index
            .get(outpoint)
            .and_then(|account_id| {
                self.inner.stealth_handlers.get(&*account_id).map(|h| h.clone())
            })
    }
}
```

### 3.4 Модификация cleanup()

```rust
pub async fn cleanup(&self) -> Result<()> {
    self.inner.pending.clear();
    self.inner.stasis.clear();
    self.inner.outgoing.clear();
    self.inner.address_to_utxo_context_map.clear();
    
    // ДОБАВИТЬ: очистка stealth структур
    self.inner.stealth_handlers.clear();
    self.inner.stealth_outpoint_index.clear();
    
    Ok(())
}
```

### 3.5 Модификация handle_utxo_changed()

```rust
pub async fn handle_utxo_changed(&self, utxos: UtxosChangedNotification) -> Result<()> {
    let current_daa_score = self.current_daa_score()
        .expect("DAA score expected when handling UTXO Changed notifications");

    #[allow(clippy::mutable_key_type)]
    let mut updated_contexts: HashSet<UtxoContext> = HashSet::default();

    // ========================================================================
    // НОВОЕ: Разделяем записи на "с адресом" и "без адреса"
    // ========================================================================
    
    let (added_with_address, added_without_address): (Vec<_>, Vec<_>) = 
        (*utxos.added).clone().into_iter()
            .partition(|entry| entry.address.is_some());
    
    let (removed_with_address, removed_without_address): (Vec<_>, Vec<_>) = 
        (*utxos.removed).clone().into_iter()
            .partition(|entry| entry.address.is_some());
    
    // ========================================================================
    // ОБРАБОТКА STEALTH UTXO (без адреса)
    // ========================================================================
    
    // Process added stealth UTXOs
    for entry in added_without_address {
        if entry.utxo_entry.script_public_key.version() != STEALTH_SCRIPT_VERSION {
            continue;
        }
        
        let outpoint = TransactionOutpoint::new(
            entry.outpoint.transaction_id,
            entry.outpoint.index,
        );
        
        // First try: lookup in outpoint index (O(1))
        if let Some(handler) = self.get_handler_for_outpoint(&outpoint) {
            // Already known outpoint - just update context
            let context = handler.utxo_context();
            updated_contexts.insert(context.clone());
            
            let utxo_ref: UtxoEntryReference = (&entry).into();
            context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
            continue;
        }
        
        // Second try: iterate handlers and try to claim (rare case - first discovery)
        for handler_ref in self.inner.stealth_handlers.iter() {
            let handler = handler_ref.value();
            
            if let Some(context) = handler.try_claim_utxo(&entry).await {
                updated_contexts.insert(context.clone());
                
                // Register in outpoint index for future lookups
                self.register_stealth_outpoint(outpoint.clone(), *handler.account_id());
                
                let utxo_ref: UtxoEntryReference = (&entry).into();
                context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
                break;
            }
        }
    }
    
    // Process removed stealth UTXOs
    for entry in removed_without_address {
        if entry.utxo_entry.script_public_key.version() != STEALTH_SCRIPT_VERSION {
            continue;
        }
        
        let outpoint = TransactionOutpoint::new(
            entry.outpoint.transaction_id,
            entry.outpoint.index,
        );
        
        // Lookup handler by outpoint
        if let Some(handler) = self.get_handler_for_outpoint(&outpoint) {
            let context = handler.utxo_context();
            updated_contexts.insert(context.clone());
            
            // Remove ephemeral key
            handler.handle_utxo_removed(&outpoint).await?;
            
            // Remove from outpoint index
            self.unregister_stealth_outpoint(&outpoint);
            
            // Remove from UTXO context
            let utxo_ref: UtxoEntryReference = (&entry).into();
            context.handle_utxo_removed(vec![utxo_ref], current_daa_score).await?;
        }
    }
    
    // ========================================================================
    // СУЩЕСТВУЮЩАЯ ЛОГИКА: UTXO с адресами
    // ========================================================================
    
    let added = added_with_address.into_iter()
        .filter_map(|entry| entry.address.clone().map(|address| (address, entry)));
    let mut added = HashMap::group_from(added);

    let removed = removed_with_address.into_iter()
        .filter_map(|entry| entry.address.clone().map(|address| (address, entry)));
    let mut removed = HashMap::group_from(removed);

    // ... остальной существующий код без изменений ...
    
    // Update balances for affected contexts
    for context in updated_contexts.iter() {
        context.update_balance().await?;
    }

    Ok(())
}
```

---

## 4. Часть C: StealthSigner

### 4.1 Структура StealthSigner

**Файл:** `wallet/core/src/tx/generator/stealth_signer.rs` (НОВЫЙ)

```rust
//! Stealth transaction signer.
//!
//! Signs stealth inputs using ephemeral keys retrieved from the account's
//! EphemeralKeyStore.

use crate::account::variants::stealth::StealthAccount;
use crate::imports::*;
use crate::storage::PrvKeyData;
use crate::tx::generator::pending::PendingTransaction;
use kaspa_consensus_core::sign::Signed;
use kaspa_consensus_core::tx::{SignableTransaction, TransactionOutpoint};
use kaspa_consensus_core::hashing::sighash::{calc_schnorr_signature_hash, SigHashType};
use secp256k1::{schnorr, Message, Keypair, SECP256K1};

/// Signer for stealth transactions.
/// 
/// Unlike the standard Signer which derives keys from addresses,
/// StealthSigner retrieves pre-computed spending keys from the
/// EphemeralKeyStore.
pub struct StealthSigner {
    account: Arc<StealthAccount>,
    keydata: PrvKeyData,
    payment_secret: Option<Secret>,
}

impl StealthSigner {
    pub fn new(
        account: Arc<StealthAccount>,
        keydata: PrvKeyData,
        payment_secret: Option<Secret>,
    ) -> Self {
        Self { account, keydata, payment_secret }
    }
    
    /// Signs a pending transaction containing stealth inputs.
    pub async fn try_sign(&self, pending: &PendingTransaction) -> Result<()> {
        let mutable_tx = pending.inner.signable_tx.lock()?.clone();
        let signed = self.sign_stealth(mutable_tx).await?;
        *pending.inner.signable_tx.lock()? = signed.tx;
        Ok(())
    }
    
    /// Signs all stealth inputs in the transaction.
    async fn sign_stealth(&self, mut tx: SignableTransaction) -> Result<Signed> {
        let mut additional_signatures_required = false;
        
        for (idx, input) in tx.tx.inputs.iter_mut().enumerate() {
            let utxo_entry = tx.entries[idx].as_ref()
                .ok_or(Error::MissingUtxoEntry(idx))?;
            
            let script_version = utxo_entry.script_public_key.version();
            
            if script_version != STEALTH_SCRIPT_VERSION {
                // Not a stealth input - skip (will be signed by standard signer)
                additional_signatures_required = true;
                continue;
            }
            
            // Get outpoint for this input
            let outpoint = TransactionOutpoint::new(
                input.previous_outpoint.transaction_id,
                input.previous_outpoint.index,
            );
            
            // Retrieve spending key from ephemeral store
            let key_data = self.account.ephemeral_keys()
                .get(&outpoint)
                .await
                .ok_or(Error::EphemeralKeyNotFound(outpoint.clone()))?;
            
            // Reconstruct secret key
            let spending_secret = secp256k1::SecretKey::from_slice(&key_data.spending_secret)?;
            let keypair = Keypair::from_secret_key(SECP256K1, &spending_secret);
            
            // Calculate sighash
            let sighash = calc_schnorr_signature_hash(
                &tx.as_verifiable(),
                idx,
                SigHashType::All,
                &mut kaspa_consensus_core::hashing::sighash::SigHashReusedValues::new(),
            );
            
            // Sign
            let message = Message::from_digest_slice(sighash.as_bytes())?;
            let signature = SECP256K1.sign_schnorr(&message, &keypair);
            
            // Format signature script: [64 bytes sig][1 byte sighash_type]
            // Note: NO OP_DATA_65 prefix for Native SegWit style
            let mut sig_script = Vec::with_capacity(65);
            sig_script.extend_from_slice(&signature.serialize());
            sig_script.push(SigHashType::All.to_u8());
            
            input.signature_script = sig_script.into();
        }
        
        Ok(Signed {
            tx,
            additional_signatures_required,
        })
    }
}
```

### 4.2 Интеграция с PendingTransaction

**Файл:** `wallet/core/src/tx/generator/pending.rs`

Добавить метод:

```rust
impl PendingTransaction {
    /// Signs stealth inputs using the provided signer.
    /// 
    /// This should be called in addition to try_sign() when the
    /// transaction contains stealth inputs.
    pub async fn try_sign_stealth(&self, signer: &StealthSigner) -> Result<()> {
        signer.try_sign(self).await
    }
}
```

---

## 5. Часть D: Хранилище EphemeralKeys

### 5.1 Типы данных

**Файл:** `wallet/core/src/storage/ephemeral_keys.rs` (НОВЫЙ)

```rust
//! Ephemeral key storage for stealth transactions.
//!
//! Stores the pre-computed spending keys for received stealth UTXOs.
//! Keys are encrypted at rest using the wallet secret.

use crate::encryption::{Encryptable, EncryptionKind, Secret};
use crate::imports::*;
use kaspa_consensus_core::tx::TransactionOutpoint;
use zeroize::Zeroize;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Status of an ephemeral key
#[derive(Clone, Debug, BorshSerialize, BorshDeserialize, Serialize, Deserialize)]
pub enum EphemeralKeyStatus {
    /// UTXO is in mempool or recently added (not yet confirmed)
    Pending { added_daa_score: u64 },
    /// UTXO has sufficient confirmations
    Confirmed { confirmed_daa_score: u64 },
}

/// Data needed to spend a stealth UTXO
#[derive(Clone, BorshSerialize, BorshDeserialize)]
pub struct EphemeralKeyData {
    /// Pre-computed spending secret key (32 bytes)
    pub spending_secret: [u8; 32],
    /// Blinding factor used in derivation (32 bytes)
    pub blinding_factor: [u8; 32],
    /// Destination public key P_dest (33 bytes compressed)
    pub destination_pubkey: [u8; 33],
}

impl Zeroize for EphemeralKeyData {
    fn zeroize(&mut self) {
        self.spending_secret.zeroize();
        self.blinding_factor.zeroize();
    }
}

impl Drop for EphemeralKeyData {
    fn drop(&mut self) {
        self.zeroize();
    }
}

/// Entry stored on disk (encrypted)
#[derive(Clone, BorshSerialize, BorshDeserialize)]
pub struct EphemeralKeyEntry {
    pub outpoint: TransactionOutpoint,
    pub data: EphemeralKeyData,
    pub status: EphemeralKeyStatus,
}

impl Zeroize for EphemeralKeyEntry {
    fn zeroize(&mut self) {
        self.data.zeroize();
    }
}
```

### 5.2 EphemeralKeyStore

```rust
// ============================================================================
// EPHEMERAL KEY STORE
// ============================================================================

/// In-memory store for ephemeral keys with disk persistence.
pub struct EphemeralKeyStore {
    account_id: AccountId,
    
    /// In-memory cache (decrypted keys)
    keys: DashMap<TransactionOutpoint, EphemeralKeyData>,
    
    /// Status tracking
    statuses: DashMap<TransactionOutpoint, EphemeralKeyStatus>,
    
    /// Dirty flag for persistence
    modified: AtomicBool,
}

impl EphemeralKeyStore {
    pub fn new(account_id: AccountId) -> Self {
        Self {
            account_id,
            keys: DashMap::new(),
            statuses: DashMap::new(),
            modified: AtomicBool::new(false),
        }
    }
    
    // ========================================================================
    // IN-MEMORY OPERATIONS
    // ========================================================================
    
    /// Stores an ephemeral key in memory
    pub async fn store(
        &self,
        outpoint: TransactionOutpoint,
        data: EphemeralKeyData,
        daa_score: u64,
    ) -> Result<()> {
        self.keys.insert(outpoint.clone(), data);
        self.statuses.insert(outpoint, EphemeralKeyStatus::Pending { 
            added_daa_score: daa_score 
        });
        self.modified.store(true, Ordering::SeqCst);
        Ok(())
    }
    
    /// Retrieves an ephemeral key
    pub async fn get(&self, outpoint: &TransactionOutpoint) -> Option<EphemeralKeyData> {
        self.keys.get(outpoint).map(|r| r.clone())
    }
    
    /// Checks if an outpoint is stored
    pub fn contains(&self, outpoint: &TransactionOutpoint) -> bool {
        self.keys.contains_key(outpoint)
    }
    
    /// Removes an ephemeral key
    pub async fn remove(&self, outpoint: &TransactionOutpoint) -> Result<()> {
        self.keys.remove(outpoint);
        self.statuses.remove(outpoint);
        self.modified.store(true, Ordering::SeqCst);
        Ok(())
    }
    
    /// Confirms an ephemeral key (UTXO has sufficient confirmations)
    pub fn confirm(&self, outpoint: &TransactionOutpoint, daa_score: u64) {
        self.statuses.entry(outpoint.clone()).and_modify(|status| {
            *status = EphemeralKeyStatus::Confirmed { 
                confirmed_daa_score: daa_score 
            };
        });
        self.modified.store(true, Ordering::SeqCst);
    }
    
    /// Returns all outpoints
    pub fn outpoints(&self) -> Vec<TransactionOutpoint> {
        self.keys.iter().map(|r| r.key().clone()).collect()
    }
    
    /// Returns count of stored keys
    pub fn len(&self) -> usize {
        self.keys.len()
    }
    
    pub fn is_empty(&self) -> bool {
        self.keys.is_empty()
    }
    
    // ========================================================================
    // PERSISTENCE
    // ========================================================================
    
    /// Loads ephemeral keys from storage
    pub async fn load_from_storage(&self, wallet: &Arc<Wallet>) -> Result<()> {
        let store = EphemeralKeyFileStore::new(wallet, self.account_id);
        let entries = store.load_all().await?;
        
        for entry in entries {
            self.keys.insert(entry.outpoint.clone(), entry.data);
            self.statuses.insert(entry.outpoint, entry.status);
        }
        
        self.modified.store(false, Ordering::SeqCst);
        Ok(())
    }
    
    /// Saves ephemeral keys to storage (if modified)
    pub async fn save_to_storage(
        &self,
        wallet: &Arc<Wallet>,
        secret: &Secret,
    ) -> Result<()> {
        if !self.modified.load(Ordering::SeqCst) {
            return Ok(());
        }
        
        let store = EphemeralKeyFileStore::new(wallet, self.account_id);
        
        let entries: Vec<EphemeralKeyEntry> = self.keys.iter()
            .map(|r| {
                let outpoint = r.key().clone();
                let data = r.value().clone();
                let status = self.statuses.get(&outpoint)
                    .map(|s| s.clone())
                    .unwrap_or(EphemeralKeyStatus::Pending { added_daa_score: 0 });
                EphemeralKeyEntry { outpoint, data, status }
            })
            .collect();
        
        store.save_all(&entries, secret).await?;
        self.modified.store(false, Ordering::SeqCst);
        
        Ok(())
    }
    
    /// Clears all keys (zeroizing memory)
    pub fn clear(&self) {
        for mut entry in self.keys.iter_mut() {
            entry.value_mut().zeroize();
        }
        self.keys.clear();
        self.statuses.clear();
    }
}

impl Drop for EphemeralKeyStore {
    fn drop(&mut self) {
        self.clear();
    }
}
```

### 5.3 File Storage

```rust
// ============================================================================
// FILE STORAGE
// ============================================================================

/// File-based storage for ephemeral keys.
/// 
/// Structure: {wallet_dir}/stealth_keys/{account_id}/{network_id}/keys.dat
struct EphemeralKeyFileStore {
    folder: PathBuf,
}

impl EphemeralKeyFileStore {
    fn new(wallet: &Arc<Wallet>, account_id: AccountId) -> Self {
        let wallet_dir = wallet.store().location().unwrap_or_default();
        let network_id = wallet.network_id().unwrap_or_default();
        
        let folder = PathBuf::from(wallet_dir)
            .join("stealth_keys")
            .join(account_id.to_hex())
            .join(network_id.to_string());
        
        Self { folder }
    }
    
    async fn ensure_folder(&self) -> Result<()> {
        fs::create_dir_all(&self.folder).await?;
        Ok(())
    }
    
    fn keys_file(&self) -> PathBuf {
        self.folder.join("keys.dat")
    }
    
    /// Loads all entries from disk
    async fn load_all(&self) -> Result<Vec<EphemeralKeyEntry>> {
        let path = self.keys_file();
        
        if !fs::exists(&path).await? {
            return Ok(vec![]);
        }
        
        let bytes = fs::read(&path).await?;
        
        // Format: [count: u32][entry1][entry2]...
        // Each entry is Encryptable<EphemeralKeyEntry>
        // Note: We store encrypted on disk but load decrypted into memory
        // The actual decryption happens when the wallet is unlocked
        
        let entries: Vec<EphemeralKeyEntry> = BorshDeserialize::try_from_slice(&bytes)?;
        Ok(entries)
    }
    
    /// Saves all entries to disk (encrypted)
    async fn save_all(&self, entries: &[EphemeralKeyEntry], secret: &Secret) -> Result<()> {
        self.ensure_folder().await?;
        
        // Encrypt each entry
        let encrypted_entries: Vec<Encryptable<EphemeralKeyEntry>> = entries.iter()
            .map(|e| Encryptable::from(e.clone()).into_encrypted(secret, EncryptionKind::XChaCha20Poly1305))
            .collect::<Result<Vec<_>>>()?;
        
        let bytes = borsh::to_vec(&encrypted_entries)?;
        fs::write(self.keys_file(), &bytes).await?;
        
        Ok(())
    }
    
    /// Deletes all stored keys
    async fn delete_all(&self) -> Result<()> {
        let path = self.keys_file();
        if fs::exists(&path).await? {
            fs::remove_file(&path).await?;
        }
        Ok(())
    }
}
```

---

## 6. Часть E: RPC Расширения

### 6.1 Capability Flag

**Файл:** `rpc/core/src/model/message.rs`

```rust
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetServerInfoResponse {
    pub rpc_api_version: u16,
    pub rpc_api_revision: u16,
    pub server_version: String,
    pub network_id: RpcNetworkId,
    pub has_utxo_index: bool,
    pub is_synced: bool,
    pub virtual_daa_score: u64,
    
    // НОВОЕ ПОЛЕ
    #[serde(default)]
    pub has_stealth_support: bool,
}

impl Serializer for GetServerInfoResponse {
    fn serialize<W: std::io::Write>(&self, writer: &mut W) -> std::io::Result<()> {
        store!(u16, &2, writer)?; // Версия 2
        
        store!(u16, &self.rpc_api_version, writer)?;
        store!(u16, &self.rpc_api_revision, writer)?;
        store!(String, &self.server_version, writer)?;
        store!(RpcNetworkId, &self.network_id, writer)?;
        store!(bool, &self.has_utxo_index, writer)?;
        store!(bool, &self.is_synced, writer)?;
        store!(u64, &self.virtual_daa_score, writer)?;
        store!(bool, &self.has_stealth_support, writer)?; // НОВОЕ
        
        Ok(())
    }
}

impl Deserializer for GetServerInfoResponse {
    fn deserialize<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let version = load!(u16, reader)?;
        
        let rpc_api_version = load!(u16, reader)?;
        let rpc_api_revision = load!(u16, reader)?;
        let server_version = load!(String, reader)?;
        let network_id = load!(RpcNetworkId, reader)?;
        let has_utxo_index = load!(bool, reader)?;
        let is_synced = load!(bool, reader)?;
        let virtual_daa_score = load!(u64, reader)?;
        
        // Backward compatible: default to false for old versions
        let has_stealth_support = if version >= 2 {
            load!(bool, reader)?
        } else {
            false
        };
        
        Ok(Self {
            rpc_api_version,
            rpc_api_revision,
            server_version,
            network_id,
            has_utxo_index,
            is_synced,
            virtual_daa_score,
            has_stealth_support,
        })
    }
}
```

### 6.2 Новый RPC метод

**Файл:** `rpc/core/src/model/message.rs`

```rust
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetUtxosByScriptVersionRequest {
    pub script_version: u16,
    pub cursor: Option<RpcScriptVersionCursor>,
    pub limit: Option<u32>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RpcScriptVersionCursor {
    pub transaction_id: RpcTransactionId,
    pub index: u32,
    pub cursor_key: Vec<u8>, // сырой ключ из UTXO-индекса
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetUtxosByScriptVersionResponse {
    pub entries: Vec<RpcUtxosByScriptVersionEntry>,
    pub next_cursor: Option<RpcScriptVersionCursor>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RpcUtxosByScriptVersionEntry {
    pub outpoint: RpcTransactionOutpoint,
    pub utxo_entry: RpcUtxoEntry,
}
```

### 6.3 RPC API trait

**Файл:** `rpc/core/src/api/rpc.rs`

```rust
    async fn get_utxos_by_script_version(
        &self,
        script_version: u16,
        cursor: Option<RpcScriptVersionCursor>,
    limit: Option<u32>,
    ) -> RpcResult<GetUtxosByScriptVersionResponse> {
        self.get_utxos_by_script_version_call(
            None,
        GetUtxosByScriptVersionRequest::new(script_version, cursor, limit),
    )
    .await
}
```

### 6.4 Реализация в RPC Service

**Файл:** `rpc/service/src/service.rs`

```rust
async fn get_utxos_by_script_version_call(
    &self,
    _connection: Option<&DynRpcConnection>,
    request: GetUtxosByScriptVersionRequest,
) -> RpcResult<GetUtxosByScriptVersionResponse> {
    if !self.config.utxoindex {
        return Err(RpcError::NoUtxoIndex);
    }
    let session = self.consensus_manager.consensus().unguarded_session();
    if session.async_is_consensus_in_transitional_ibd_state().await {
        return Err(RpcError::ConsensusInTransitionalIbdState);
    }

    let limit = request.limit.unwrap_or(1000).min(10_000) as usize;
    let fetch_limit = limit.saturating_add(1);
    let cursor_key = request
        .cursor
        .as_ref()
        .and_then(|c| if c.cursor_key.is_empty() { None } else { Some(c.cursor_key.clone()) });

    let utxoindex = self.utxoindex.clone().unwrap();
    let mut raw_entries = utxoindex
        .get_utxos_by_script_version(request.script_version, cursor_key, fetch_limit)
        .await
        .map_err(|e| RpcError::General(format!("Database error: {}", e)))?;

    let mut next_cursor = None;
    if raw_entries.len() == fetch_limit {
        if let Some((_, outpoint, _, cursor_key)) = raw_entries.pop() {
            next_cursor = Some(RpcScriptVersionCursor::new(outpoint.transaction_id, outpoint.index, cursor_key));
        }
    }

    let entries = raw_entries
        .into_iter()
        .map(|(script_public_key, outpoint, compact_entry, _)| {
            let rpc_entry = RpcUtxoEntry::new(
                compact_entry.amount,
                script_public_key,
                compact_entry.block_daa_score,
                compact_entry.is_coinbase,
            );
            RpcUtxosByScriptVersionEntry::new(outpoint.into(), rpc_entry)
        })
        .collect();

    Ok(GetUtxosByScriptVersionResponse::new(entries, next_cursor))
}
```

---

## 7. Часть F: Интеграция send() и финализация

### 7.1 StealthAccount::send()

**Файл:** `wallet/core/src/account/variants/stealth.rs`

```rust
impl StealthAccount {
    /// Sends funds from this stealth account.
    pub async fn send(
        self: Arc<Self>,
        destination: PaymentDestination,
        fee_rate: Option<f64>,
        priority_fee_sompi: Fees,
        payload: Option<Vec<u8>>,
        wallet_secret: Secret,
        payment_secret: Option<Secret>,
        abortable: &Abortable,
        notifier: Option<GenerationNotifier>,
    ) -> Result<(GeneratorSummary, Vec<kaspa_hashes::Hash>)> {
        // Ensure account is unlocked
        if !self.is_unlocked().await {
            self.unlock(&wallet_secret, payment_secret.as_ref()).await?;
        }
        
        // Get key data
        let keydata = self.prv_key_data(wallet_secret.clone()).await?;
        
        // Create stealth change creator
        let change_creator = self.create_change_creator().await?;
        
        // Create stealth signer
        let signer = Arc::new(StealthSigner::new(
            self.clone(),
            keydata,
            payment_secret.clone(),
        ));
        
        // Create generator settings
        let mut settings = GeneratorSettings::try_new_with_account(
            self.clone().as_dyn_arc(),
            destination,
            fee_rate,
            priority_fee_sompi,
            payload,
        )?;
        settings.stealth_change_creator = Some(change_creator);
        
        // Create generator
        let generator = Generator::try_new(settings, None, Some(abortable))?;
        
        let mut stream = generator.stream();
        let mut ids = vec![];
        
        while let Some(transaction) = stream.try_next().await? {
            // Sign stealth inputs
            transaction.try_sign_stealth(&signer).await?;
            
            // Get pending stealth change before submit
            let pending_change = transaction.take_stealth_change();
            
            // Submit transaction
            let id = transaction.try_submit(&self.wallet().rpc_api()).await?;
            
            // Finalize stealth change (save ephemeral key)
            if let Some(pending) = pending_change {
                self.finalize_stealth_change(id, pending).await?;
            }
            
            // Notify
            if let Some(notifier) = notifier.as_ref() {
                notifier(&transaction);
            }
            
            ids.push(id);
            yield_executor().await;
        }
        
        // Save ephemeral keys to disk
        self.ephemeral_keys.save_to_storage(
            &self.wallet(),
            &wallet_secret,
        ).await?;
        
        Ok((generator.summary(), ids))
    }
    
    /// Finalizes a stealth change output after transaction submission.
    async fn finalize_stealth_change(
        &self,
        tx_id: TransactionId,
        pending: PendingStealthChange,
    ) -> Result<()> {
        let outpoint = TransactionOutpoint::new(tx_id, pending.output_index as u32);
        
        let key_data = EphemeralKeyData {
            spending_secret: pending.spending_secret.secret_bytes(),
            blinding_factor: pending.blinding_factor.to_be_bytes(),
            destination_pubkey: pending.ephemeral_output.destination_pubkey.serialize(),
        };
        
        let daa_score = self.wallet().utxo_processor()
            .current_daa_score()
            .unwrap_or(0);
        
        self.ephemeral_keys.store(outpoint.clone(), key_data, daa_score).await?;
        
        // Register in UtxoProcessor's outpoint index
        self.wallet().utxo_processor()
            .register_stealth_outpoint(outpoint, *self.id());
        
        Ok(())
    }
}
```

### 7.2 Wallet API расширения

**Файл:** `wallet/core/src/wallet/api.rs`

```rust
impl Wallet {
    /// Creates a new stealth account.
    pub async fn create_stealth_account(
        self: &Arc<Self>,
        wallet_secret: &Secret,
        payment_secret: Option<&Secret>,
        name: Option<String>,
        _guard: &WalletGuard<'_>,
    ) -> Result<Arc<StealthAccount>> {
        // Check if node supports stealth
        let server_info = self.rpc_api().get_server_info().await?;
        if !server_info.has_stealth_support {
            return Err(Error::StealthNotSupported);
        }
        
        // Get or create prv_key_data
        let prv_key_data_id = self.get_or_create_prv_key_data(wallet_secret).await?;
        
        // Determine account index
        let account_index = self.next_stealth_account_index(&prv_key_data_id).await?;
        
        // Derive keys
        let prv_key_data = self.get_prv_key_data(wallet_secret, &prv_key_data_id).await?
            .ok_or(Error::PrivateKeyNotFound(prv_key_data_id))?;
        let payload = prv_key_data.payload.decrypt(payment_secret)?;
        let xprv = payload.get_xprv(payment_secret)?;
        
        let derivation = StealthKeyDerivation::from_xprv(&xprv, account_index)?;
        
        // Get current DAA score for creation timestamp
        let creation_daa_score = self.utxo_processor().current_daa_score();
        
        // Create account
        let account = StealthAccount::try_new(
            self,
            name,
            prv_key_data_id,
            account_index,
            derivation.scan_pubkey,
            derivation.spend_pubkey,
            creation_daa_score,
        ).await?;
        
        let account = Arc::new(account);
        
        // Store account
        let account_store = self.store().as_account_store()?;
        account_store.store_single(&account.to_storage()?, account.metadata()?.as_ref()).await?;
        self.store().commit(wallet_secret).await?;
        
        // Unlock and activate
        account.unlock(wallet_secret, payment_secret).await?;
        account.clone().start().await?;
        
        Ok(account)
    }
}
```

### 7.3 Интеграция unlock при открытии кошелька

**Файл:** `wallet/core/src/wallet/mod.rs`

В `open_impl()` добавить:

```rust
async fn open_impl(...) -> Result<Option<Vec<AccountDescriptor>>> {
    // ... existing code ...
    
    if let Some(accounts) = &accounts {
        for account in accounts.iter() {
            // Existing legacy account handling
            if let Ok(legacy_account) = account.clone().as_legacy_account() {
                legacy_account.create_private_context(wallet_secret, None, None).await?;
                self.legacy_accounts().insert(account.clone());
            }
            
            // NEW: Stealth account handling
            if account.account_kind().as_ref() == STEALTH_ACCOUNT_KIND {
                if let Some(stealth_account) = account.clone()
                    .as_any()
                    .downcast_ref::<StealthAccount>() 
                {
                    stealth_account.unlock(wallet_secret, None).await?;
                }
            }
        }
    }
    
    // ... rest of existing code ...
}
```

---

## 8. Часть G: Тестирование

### 8.1 Unit Tests

**Файл:** `wallet/core/tests/stealth_account_tests.rs`

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_stealth_key_derivation() {
        // Test that keys are derived correctly from xprv
        let mnemonic = Mnemonic::random(OsRng, Default::default());
        let seed = mnemonic.to_seed("");
        let xprv = ExtendedPrivateKey::<SecretKey>::new(seed).unwrap();
        
        let derivation = StealthKeyDerivation::from_xprv(&xprv, 0).unwrap();
        
        // Verify keys are valid
        assert!(derivation.scan_pubkey.serialize().len() == 33);
        assert!(derivation.spend_pubkey.serialize().len() == 33);
        
        // Verify deterministic derivation
        let derivation2 = StealthKeyDerivation::from_xprv(&xprv, 0).unwrap();
        assert_eq!(derivation.scan_pubkey, derivation2.scan_pubkey);
        assert_eq!(derivation.spend_pubkey, derivation2.spend_pubkey);
        
        // Verify different account indexes produce different keys
        let derivation3 = StealthKeyDerivation::from_xprv(&xprv, 1).unwrap();
        assert_ne!(derivation.scan_pubkey, derivation3.scan_pubkey);
    }
    
    #[tokio::test]
    async fn test_ephemeral_key_store() {
        let account_id = AccountId::new(0xCAFE);
        let store = EphemeralKeyStore::new(account_id);
        
        let outpoint = TransactionOutpoint::new(TransactionId::default(), 0);
        let key_data = EphemeralKeyData {
            spending_secret: [1u8; 32],
            blinding_factor: [2u8; 32],
            destination_pubkey: [3u8; 33],
        };
        
        // Test store
        store.store(outpoint.clone(), key_data.clone(), 100).await.unwrap();
        assert!(store.contains(&outpoint));
        
        // Test get
        let retrieved = store.get(&outpoint).await.unwrap();
        assert_eq!(retrieved.spending_secret, key_data.spending_secret);
        
        // Test remove
        store.remove(&outpoint).await.unwrap();
        assert!(!store.contains(&outpoint));
    }
    
    #[tokio::test]
    async fn test_unlock_lock_session() {
        // Create a test wallet and stealth account
        // ...
        
        // Test unlock
        account.unlock(&wallet_secret, None).await.unwrap();
        assert!(account.is_unlocked().await);
        
        // Test lock
        account.lock().await;
        assert!(!account.is_unlocked().await);
    }
    
    #[tokio::test]
    async fn test_try_claim_utxo() {
        // Create stealth output
        let stealth_address = StealthAddress::new(scan_pubkey, spend_pubkey);
        let (ephemeral_output, blinding_factor) = 
            create_stealth_output_with_blinding(&stealth_address, &mut OsRng).unwrap();
        
        let script = pay_to_stealth(&ephemeral_output);
        
        // Create mock UTXO entry
        let utxo = RpcUtxosByAddressesEntry {
            address: None,
            outpoint: RpcTransactionOutpoint { transaction_id: TransactionId::default(), index: 0 },
            utxo_entry: RpcUtxoEntry {
                amount: 1000,
                script_public_key: script.into(),
                block_daa_score: 100,
                is_coinbase: false,
            },
        };
        
        // Unlock account
        account.unlock(&wallet_secret, None).await.unwrap();
        
        // Test claim
        let result = account.try_claim_utxo(&utxo).await;
        assert!(result.is_some());
        
        // Verify ephemeral key was stored
        let outpoint = TransactionOutpoint::new(utxo.outpoint.transaction_id, utxo.outpoint.index);
        assert!(account.ephemeral_keys().contains(&outpoint));
    }
}
```

### 8.2 Integration Tests

**Файл:** `testing/integration/src/stealth_tests.rs`

```rust
#[tokio::test]
async fn test_stealth_send_receive() {
    // 1. Create two wallets with stealth accounts
    let wallet_a = create_test_wallet().await;
    let wallet_b = create_test_wallet().await;
    
    let account_a = wallet_a.create_stealth_account(&secret_a, None, Some("Alice")).await.unwrap();
    let account_b = wallet_b.create_stealth_account(&secret_b, None, Some("Bob")).await.unwrap();
    
    // 2. Fund account A (from coinbase or faucet)
    fund_account(&account_a, 10_000_000).await;
    
    // 3. Send from A to B
    let bob_address = account_b.receive_address().unwrap();
    let (summary, ids) = account_a.send(
        PaymentDestination::PaymentOutputs(PaymentOutputs::from(vec![
            PaymentOutput::new(bob_address, 5_000_000),
        ])),
        None,
        Fees::None,
        None,
        secret_a,
        None,
        &Abortable::default(),
        None,
    ).await.unwrap();
    
    // 4. Wait for confirmation
    wait_for_confirmation(&ids[0]).await;
    
    // 5. Verify B received funds
    account_b.scan(None, None).await.unwrap();
    let balance_b = account_b.balance();
    assert_eq!(balance_b.mature, 5_000_000);
    
    // 6. Verify A's change was received
    let balance_a = account_a.balance();
    assert!(balance_a.mature > 0); // Should have change minus fees
    
    // 7. Verify B can spend
    let (summary2, ids2) = account_b.send(
        PaymentDestination::PaymentOutputs(PaymentOutputs::from(vec![
            PaymentOutput::new(account_a.receive_address().unwrap(), 1_000_000),
        ])),
        None,
        Fees::None,
        None,
        secret_b,
        None,
        &Abortable::default(),
        None,
    ).await.unwrap();
    
    assert!(!ids2.is_empty());
}

#[tokio::test]
async fn test_stealth_reorg_handling() {
    // Test that ephemeral keys are properly removed during reorg
    // ...
}

#[tokio::test]
async fn test_stealth_wallet_restore() {
    // Test wallet restoration from seed phrase
    // ...
}
```

---

## 9. Порядок реализации

### Фаза 1: Инфраструктура (1 неделя)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 1.1 | Создать `stealth_handler.rs` | `wallet/core/src/utxo/stealth_handler.rs` | - |
| 1.2 | Создать `ephemeral_keys.rs` | `wallet/core/src/storage/ephemeral_keys.rs` | - |
| 1.3 | Добавить `has_stealth_support` в RPC | `rpc/core/src/model/message.rs` | - |
| 1.4 | Добавить новые типы ошибок | `wallet/core/src/error.rs` | - |

### Фаза 2: UtxoProcessor (3-5 дней)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 2.1 | Добавить поля в Inner | `wallet/core/src/utxo/processor.rs` | 1.1 |
| 2.2 | Реализовать register/unregister | `wallet/core/src/utxo/processor.rs` | 2.1 |
| 2.3 | Модифицировать handle_utxo_changed | `wallet/core/src/utxo/processor.rs` | 2.2 |
| 2.4 | Модифицировать cleanup | `wallet/core/src/utxo/processor.rs` | 2.2 |

### Фаза 3: StealthSigner (2-3 дня)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 3.1 | Создать `stealth_signer.rs` | `wallet/core/src/tx/generator/stealth_signer.rs` | 1.2 |
| 3.2 | Добавить `try_sign_stealth` в PendingTransaction | `wallet/core/src/tx/generator/pending.rs` | 3.1 |

### Фаза 4: StealthAccount (1 неделя)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 4.1 | Создать Payload и сериализацию | `wallet/core/src/account/variants/stealth.rs` | - |
| 4.2 | Реализовать StealthKeyDerivation | `wallet/core/src/account/variants/stealth.rs` | - |
| 4.3 | Реализовать unlock/lock session | `wallet/core/src/account/variants/stealth.rs` | - |
| 4.4 | Реализовать StealthAccount struct | `wallet/core/src/account/variants/stealth.rs` | 4.1-4.3, 1.2 |
| 4.5 | Реализовать Account trait | `wallet/core/src/account/variants/stealth.rs` | 4.4, 2.2 |
| 4.6 | Реализовать StealthUtxoHandler | `wallet/core/src/account/variants/stealth.rs` | 4.5, 1.1 |
| 4.7 | Реализовать StealthChangeCreatorImpl | `wallet/core/src/account/variants/stealth.rs` | 4.4 |
| 4.8 | Регистрация Factory | `wallet/core/src/factory.rs`, `variants/mod.rs` | 4.5 |

### Фаза 5: RPC (3-5 дней) — ✅ выполнено (часть 5.2 остаётся в бэклоге)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 5.1 | Добавить типы запроса/ответа | `rpc/core/src/model/message.rs` | - |
| 5.2 | Добавить в RpcApi trait | `rpc/core/src/api/rpc.rs` | 5.1 |
| 5.3 | Реализовать fallback в service | `rpc/service/src/service.rs` | 5.2 |
| 5.4 | Protobuf схемы (если нужно) | `rpc/grpc/core/proto/` | 5.1 |

### Фаза 6: Интеграция (3-5 дней)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 6.1 | Реализовать StealthAccount::send() | `wallet/core/src/account/variants/stealth.rs` | 3.1, 4.7 |
| 6.2 | Wallet::create_stealth_account() | `wallet/core/src/wallet/api.rs` | 4.8, 1.3 |
| 6.3 | Интеграция unlock в open_impl | `wallet/core/src/wallet/mod.rs` | 4.3 |
| 6.4 | Интеграция с пунктом 8 из etap3_1 | `wallet/core/src/account/variants/stealth.rs` | 6.1 |

### Фаза 7: Тестирование (1 неделя)

| # | Задача | Файлы | Зависимости |
|---|--------|-------|-------------|
| 7.1 | Unit tests для StealthKeyDerivation | `wallet/core/tests/` | 4.2 |
| 7.2 | Unit tests для EphemeralKeyStore | `wallet/core/tests/` | 1.2 |
| 7.3 | Unit tests для try_claim_utxo | `wallet/core/tests/` | 4.6 |
| 7.4 | Integration test: send/receive | `testing/integration/src/` | 6.1 |
| 7.5 | Integration test: reorg handling | `testing/integration/src/` | 2.3 |
| 7.6 | Integration test: wallet restore | `testing/integration/src/` | 4.4 |

---

## Итоговая оценка времени

| Фаза | Время | Критичность |
|------|-------|-------------|
| Фаза 1: Инфраструктура | 5-7 дней | HIGH |
| Фаза 2: UtxoProcessor | 3-5 дней | CRITICAL |
| Фаза 3: StealthSigner | 2-3 дня | HIGH |
| Фаза 4: StealthAccount | 5-7 дней | CRITICAL |
| Фаза 5: RPC | 3-5 дней | DONE (scope + уведомления) |
| Фаза 6: Интеграция | 3-5 дней | HIGH |
| Фаза 7: Тестирование | 5-7 дней | HIGH |
| **ИТОГО** | **~4-6 недель** | |

---

## 10. Чеклист готовности к production

### 10.1 Безопасность

- [ ] `UnlockedStealthKeys` корректно zeroize при drop
- [ ] `EphemeralKeyData` корректно zeroize при drop
- [ ] Все секретные ключи хранятся только в зашифрованном виде на диске
- [ ] `scan_secret` и `spend_secret` очищаются при lock()
- [ ] Нет утечек секретных данных в логах
- [ ] Проверка точек на кривой при парсинге `R`
- [ ] Domain separation для всех хеш-функций
- [ ] Использование только `OsRng` для генерации ephemeral ключей

### 10.2 Корректность

- [ ] View tag коллизии корректно обрабатываются (полная проверка после совпадения тега)
- [ ] Реорги корректно удаляют ephemeral keys
- [ ] Outpoint index синхронизирован с ephemeral key store
- [ ] Сканирование при восстановлении кошелька работает корректно
- [ ] Stealth change создаётся с уникальным ephemeral key

### 10.3 Производительность

- [ ] View tag фильтрация отсекает 255/256 UTXO без ECDH
- [ ] Обратный индекс `outpoint → account` обеспечивает O(1) lookup
- [ ] Пагинация в RPC предотвращает OOM при большом количестве stealth UTXO
- [ ] Инкрементальное сохранение ephemeral keys

### 10.4 UX

- [ ] Понятные сообщения об ошибках при отсутствии stealth поддержки на ноде
- [ ] Прогресс-бар при сканировании блокчейна
- [ ] Возможность указать "birthday" для ускорения восстановления
- [ ] Stealth адреса отображаются в формате `qs1...`

### 10.5 Совместимость

- [ ] Capability flag `has_stealth_support` в `GetServerInfoResponse`
- [ ] Fallback на ошибку при отсутствии RPC метода
- [ ] Корректная работа с нодами без stealth поддержки (graceful degradation)

---

## 11. Известные ограничения и TODO

### 11.1 Текущие ограничения

1. **Первичное сканирование всё ещё линейное** — `get_utxos_by_script_version` использует курсор, но пока не имеет выделенного индекса по версии (см. `docs/todo/stealth_rpc_index.md`).

2. **Один stealth адрес на аккаунт** — для полной приватности по-прежнему нужен отдельный аккаунт на каждый публичный адрес.

### 11.2 Будущие улучшения

1. **Отдельный stealth-индекс** — `version → outpoint` для O(1) запросов по версии скрипта (задача описана в `docs/todo/stealth_rpc_index.md`).

2. **Batch view tag проверка** — SIMD-оптимизация для проверки множества тегов одновременно.

3. **Light client mode** — получение только view tags от ноды для минимального трафика.

---

## 12. Диаграммы

### 12.1 Поток отправки Stealth транзакции

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STEALTH SEND FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

User: send(stealth_address, amount)
         │
         ▼
┌─────────────────────┐
│   Generator::new()  │
│ ┌─────────────────┐ │
│ │ change_address  │──────► Is Stealth? ──► StealthChangeCreator required
│ │ = stealth addr  │ │
│ └─────────────────┘ │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ UtxoIterator::next()│ ◄──── Берёт UTXO только из StealthAccount.utxo_context
│                     │       (изоляция от обычных UTXO)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    create_transaction_output()                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  For each output:                                            │    │
│  │    if destination.is_stealth():                              │    │
│  │      r = random_scalar()                                     │    │
│  │      R = r * G                                               │    │
│  │      S = r * PubScan                                         │    │
│  │      t = Hash(S)                                             │    │
│  │      P_dest = PubSpend + t*G                                 │    │
│  │      view_tag = Hash("view_tag", S)[0]                       │    │
│  │      script = [R][view_tag][P_dest]                          │    │
│  │      version = STEALTH_SCRIPT_VERSION (16)                   │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    create_change_output()                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  StealthChangeCreator::create_change_output()                │    │
│  │    → Создаёт EphemeralOutput для сдачи                       │    │
│  │    → Возвращает PendingStealthChange с spending_secret       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    PendingTransaction::sign()                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  For each input:                                             │    │
│  │    if utxo.script_version == STEALTH:                        │    │
│  │      → StealthSigner::sign()                                 │    │
│  │      → Берёт spending_secret из ephemeral_keys cache         │    │
│  │      → signature_script = [64 bytes sig][1 byte sighash]     │    │
│  │    else:                                                     │    │
│  │      → Standard Signer                                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
                   Broadcast TX
```

### 12.2 Поток получения Stealth UTXO

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STEALTH RECEIVE FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                    RPC Notification: UtxosChanged
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 UtxoProcessor::handle_utxo_changed()                 │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Partition entries:                                          │    │
│  │    with_address: Vec<(Address, Entry)>                       │    │
│  │    without_address: Vec<Entry>  ◄─── Stealth UTXO попадают   │    │
│  │                                       сюда (address = None)  │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│              route_addressless_entries(without_address)              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  For each entry where version == STEALTH_SCRIPT_VERSION:     │    │
│  │                                                              │    │
│  │  1. Check outpoint_index:                                    │    │
│  │     if found → direct route to owner account                 │    │
│  │                                                              │    │
│  │  2. If not found → iterate stealth_handlers:                 │    │
│  │     for handler in handlers:                                 │    │
│  │       if handler.try_claim_utxo(&entry):                     │    │
│  │         → Add to outpoint_index                              │    │
│  │         → break                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│           StealthUtxoHandler::try_claim_utxo(&entry)                 │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  1. Parse script: [R][view_tag][P_dest]                      │    │
│  │                                                              │    │
│  │  2. Fast filter:                                             │    │
│  │     my_tag = compute_view_tag(scan_secret, R)                │    │
│  │     if my_tag != view_tag → return false (255/256 cases)     │    │
│  │                                                              │    │
│  │  3. Full check:                                              │    │
│  │     S = scan_secret * R                                      │    │
│  │     t = Hash(S)                                              │    │
│  │     expected_P = spend_pubkey + t*G                          │    │
│  │     if P_dest != expected_P → return false (tag collision)   │    │
│  │                                                              │    │
│  │  4. Compute spending key:                                    │    │
│  │     spending_secret = spend_secret + t                       │    │
│  │                                                              │    │
│  │  5. Store:                                                   │    │
│  │     ephemeral_keys.insert(outpoint, EphemeralKeyData {       │    │
│  │       spending_secret,                                       │    │
│  │       blinding_factor: t,                                    │    │
│  │       destination_pubkey: P_dest                             │    │
│  │     })                                                       │    │
│  │                                                              │    │
│  │  6. Add to UtxoContext                                       │    │
│  │                                                              │    │
│  │  return true                                                 │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.3 Структура данных

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA STRUCTURES                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ StealthAccount                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ inner: Arc<Inner>                                                            │
│   ├── id: AccountId                                                          │
│   ├── wallet: Wallet                                                         │
│   ├── utxo_context: UtxoContext  ◄─── Изолированный контекст UTXO            │
│   └── settings: AccountSettings                                              │
│                                                                              │
│ scan_pubkey: PublicKey                                                       │
│ spend_pubkey: PublicKey                                                      │
│ stealth_address: StealthAddress                                              │
│                                                                              │
│ unlocked_keys: Arc<RwLock<Option<UnlockedStealthKeys>>>                      │
│   └── UnlockedStealthKeys                                                    │
│         ├── scan_secret: SecretKey                                           │
│         └── spend_secret: SecretKey                                          │
│                                                                              │
│ ephemeral_keys: Arc<EphemeralKeyStore>                                       │
│   └── EphemeralKeyStore                                                      │
│         ├── by_outpoint: DashMap<TransactionOutpoint, EncryptedEphemeralKey> │
│         └── account_id: AccountId                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ UtxoProcessor::Inner (расширенный)                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ ... existing fields ...                                                      │
│                                                                              │
│ // NEW: Stealth support                                                      │
│ stealth_handlers: DashMap<AccountId, Arc<dyn StealthUtxoHandler>>            │
│ stealth_outpoint_index: DashMap<TransactionOutpoint, AccountId>              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ EphemeralKeyData                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ spending_secret: SecretKey    // Ключ для траты: spend_secret + t            │
│ blinding_factor: [u8; 32]     // t = Hash(S)                                 │
│ destination_pubkey: [u8; 32]  // P_dest (для верификации)                    │
│ status: EphemeralKeyStatus    // Pending | Confirmed(daa_score)              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ Stealth ScriptPublicKey (version = 16)                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ Bytes:  [0..33]  [33]      [34..66]                                          │
│         ───────  ────      ────────                                          │
│           R      tag        P_dest                                           │
│           │       │           │                                              │
│           │       │           └── XOnly pubkey для Schnorr верификации       │
│           │       └────────────── View tag для быстрой фильтрации            │
│           └────────────────────── Ephemeral pubkey R = r*G                   │
│                                                                              │
│ Total: 66 bytes                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. Глоссарий

| Термин | Описание |
|--------|----------|
| **Stealth Address** | Адрес формата `(PubScan, PubSpend)`, позволяющий получать средства на уникальные одноразовые адреса |
| **Scan Key** | Ключ для сканирования блокчейна на входящие транзакции |
| **Spend Key** | Ключ для траты полученных средств |
| **Ephemeral Key (R)** | Одноразовый публичный ключ, генерируемый отправителем |
| **View Tag** | 1 байт для быстрой фильтрации (255/256 отсечение без ECDH) |
| **Blinding Factor (t)** | `Hash(SharedSecret)` — используется для деривации одноразового адреса |
| **P_dest** | Одноразовый публичный ключ получателя: `PubSpend + t*G` |
| **Spending Secret** | Приватный ключ для траты: `PrivSpend + t` |
| **ECDH** | Elliptic Curve Diffie-Hellman — протокол обмена ключами |
| **Native SegWit** | Формат скрипта без опкодов (version 16) |
| **Outpoint** | `(txid, output_index)` — уникальный идентификатор UTXO |
| **DAA Score** | Difficulty Adjustment Algorithm score — мера "времени" в DAG |

---

## 14. СЛЕДУЮЩИЕ ШАГИ: Доработка интеграции

### 14.1 Персистентность `EphemeralKeyStore` в трейте (Уверенность: 95%)

**Проблема:**
- `save_ephemeral_keys()` в `StealthAccount` делает `Ok(())`, потому что у него нет `wallet_secret`.
- Реальное сохранение вызывается там, где секрет есть: в `StealthAccount::finalize_stealth_change` и в `send()` после генерации транзакций.
- При получении входящих UTXO `UtxoProcessor` вызывает `handler.save_ephemeral_keys()`, но без секрета это бессмысленно (ничего не происходит).
- Планы (`etap3_plan.md`, `etap3_2.md`) прямо упоминали, что `save_ephemeral_keys()` «должен принимать wallet_secret», но это противоречит архитектуре: `UtxoProcessor` не хранит секреты и не должен их знать.

**Решение:**
Убрать методы `save_ephemeral_keys()` и `load_ephemeral_keys()` из `StealthUtxoHandler` trait и вызывать `EphemeralKeyStore::save_to_storage` там, где доступен `wallet_secret` (т.е. внутри `StealthAccount`).

**Действия:**
1. Удалить `save_ephemeral_keys()` и `load_ephemeral_keys()` из `StealthUtxoHandler` trait
2. Удалить их реализации из `StealthAccount`
3. Удалить вызов `handler.save_ephemeral_keys()` из `UtxoProcessor::handle_utxo_changed()`

**Статус:** [x] DONE (2025-01-28)
- Удалены методы `save_ephemeral_keys()`, `load_ephemeral_keys()` из trait
- Удалены реализации из `StealthAccount`
- Удалён вызов из `UtxoProcessor::handle_utxo_changed()`

### 14.2 RPC `get_utxos_by_script_version` (Уверенность: 90%)

**Проблема:**
- Существующая логика `StealthAccount::scan()` — заглушка (возвращает `Ok(())`).
- Кошелёк полностью зависит от текущего живого подключения и уведомлений.
- Если пользователь импортирует сид и пытается восстановить историю, никаких механизмов нет.

**Обоснования:**
- Индекс `UtxoSetByScriptPublicKey` уже присутствует (см. `rpc/service/src/converter/index.rs`), остаётся только фильтровать по `script_public_key.version()`.
- Без RPC нельзя протестировать fallback сценарий. Любая потеря подписки = невозможность восстановить баланс.

**Решение:** добавить полнофункциональный RPC `GetUtxosByScriptVersion` с курсором на уровне «сырых» ключей UTXO-индекса.

```rust
// rpc/core/src/model/message.rs
pub struct GetUtxosByScriptVersionRequest {
    pub script_version: u16,
    pub cursor: Option<RpcScriptVersionCursor>,
    pub limit: Option<u32>,
}

pub struct RpcScriptVersionCursor {
    pub transaction_id: RpcTransactionId,
    pub index: u32,
    pub cursor_key: Vec<u8>, // raw key для seek_iterator
}

pub struct GetUtxosByScriptVersionResponse {
    pub entries: Vec<RpcUtxosByScriptVersionEntry>,
    pub next_cursor: Option<RpcScriptVersionCursor>,
}
```

Handler в `rpc/service/src/service.rs` использует `utxoindex.get_utxos_by_script_version(version, cursor_key, limit+1)` и возвращает `limit` элементов + cursor. `StealthAccount::scan()` теперь делает пагинацию через `cursor_key`.

**Статус:** [x] DONE (2025-01-28)
- Добавлены типы: `GetUtxosByScriptVersionRequest/Response`, `RpcScriptVersionCursor`, `RpcUtxosByScriptVersionEntry`
- Добавлена операция `GetUtxosByScriptVersion = 151` в `ops.rs`
- Добавлен метод в `RpcApi` trait с реализацией в `rpc/service` (fallback через итерацию)
- Добавлена поддержка в `kaspa-wrpc-client` и `kaspa-grpc-client` (stub для gRPC)
- `StealthAccount::scan()` теперь использует новый RPC для восстановления

**Примечание:** Текущая реализация в `rpc/service` использует fallback через итерацию всех UTXO.
Для продакшена рекомендуется добавить выделенный индекс по версии скрипта.

### 14.3 План действий

1. [x] Удалить методы из `StealthUtxoHandler`, почистить вызовы ✓
2. [x] Реализовать RPC метод `get_utxos_by_script_version` ✓
3. [x] Доработать `StealthAccount::scan()` для восстановления ✓
4. [ ] Интеграционные тесты (сценарий «восстановление через RPC»)

---

## 15. Ссылки

- [EIP-5564: Stealth Addresses](https://eips.ethereum.org/EIPS/eip-5564)
- [BIP-352: Silent Payments](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki)
- [Monero Stealth Addresses](https://www.getmonero.org/resources/moneropedia/stealthaddress.html)
- [View Tags Optimization](https://github.com/monero-project/research-lab/issues/73)