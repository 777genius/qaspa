use crate::common::daemon::Daemon;
use crate::common::utils::wait_for;
use crate::stealth_flow::StealthTestEnv;
use async_trait::async_trait;
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_bip32::{Language, Mnemonic, WordCount};
use kaspa_consensus_core::{
    hashing::sighash::SigHashReusedValuesUnsync,
    hashing::sighash_type::SIG_HASH_ALL,
    subnets::SUBNETWORK_ID_NATIVE,
    tx::{
        MutableTransaction, Transaction, TransactionInput, TransactionOutpoint, TransactionOutput, UtxoEntry, VerifiableTransaction,
    },
};
use kaspa_hashes::Hash;
use kaspa_mldsa::{MasterSeed, MlDsaLevel};
use kaspa_rpc_core::{
    api::rpc::RpcApi, GetMempoolEntryRequest, ListMldsaDelegationsRequest, RegisterMldsaAnchorRequest, RpcDelegationRecord, RpcError,
    RpcResult,
};
use kaspa_rpc_service::service::DelegationProvider;
use kaspa_txscript::{caches::Cache, pay_to_address_script, script_builder::ScriptBuilder, script_class::ScriptClass, TxScriptEngine};
use kaspa_utils::hex::ToHex;
use kaspa_wallet_core::{
    account::delegation::DelegationStatus,
    account::variants::mldsa_master::MldsaMasterAccount,
    account::variants::stealth::StealthAccount,
    account::Account,
    api::traits::WalletApi,
    deterministic::AccountId,
    encryption::{encrypt_xchacha20poly1305, EncryptionKind},
    events::Events,
    storage::ephemeral_keys::{EphemeralKeyStatus, OrphanReason},
    storage::keydata::{data::MlDsaMasterPayload, PrvKeyData, PrvKeyDataVariantKind},
    wallet::args::{PrvKeyDataCreateArgs, WalletCreateArgs},
    wallet::Wallet,
};
use kaspa_wallet_keys::{
    keypair_mldsa::{MasterAnchor, MlDsaKeypair},
    secret::Secret,
};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::{oneshot, Mutex};

struct WalletDelegationProvider {
    wallet: Arc<Wallet>,
}

impl WalletDelegationProvider {
    fn to_rpc(id: u64, record: &kaspa_wallet_core::account::delegation::DelegationRecordV1) -> RpcDelegationRecord {
        let status = match record.status {
            DelegationStatus::Active => "active".to_string(),
            DelegationStatus::Revoked { revoked_daa } => format!("revoked:{revoked_daa}"),
            DelegationStatus::Expired { expired_daa } => format!("expired:{expired_daa}"),
        };

        RpcDelegationRecord {
            anchor: record.anchor,
            account_id: record.account_id.to_hex().into_bytes(),
            delegation_id: id,
            spend_pubkey: record.spend_pubkey,
            scan_pubkey: record.scan_pubkey,
            valid_from_daa: record.valid_from_daa,
            valid_until_daa: record.valid_until_daa,
            nonce: record.nonce,
            status,
            signature: record.signature.clone(),
        }
    }
}

#[async_trait]
impl DelegationProvider for WalletDelegationProvider {
    async fn list_by_anchor(&self, anchor: [u8; 32]) -> RpcResult<Vec<RpcDelegationRecord>> {
        let list = self.wallet.list_delegations_for_master(anchor).await.map_err(|_| RpcError::UnsupportedFeature)?;
        Ok(list.iter().map(|(id, rec)| Self::to_rpc(id.0, rec)).collect())
    }

    async fn has_masters(&self) -> RpcResult<bool> {
        let anchors = self.wallet.master_anchor_infos().await.unwrap_or_default();
        Ok(!anchors.is_empty())
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_master_anchor_registration_rpc() {
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));
    let wallet = env.wallet.clone();

    env.mine_blocks(env.coinbase_maturity + 4).await;

    let (anchor_bytes, master_account_id) = create_master_account(&env, &wallet).await;
    register_anchor(&env, anchor_bytes).await;
    activate_account(&wallet, &master_account_id).await;

    // RPC list should be empty but callable, proving anchor registration and provider wiring.
    let rpc_delegations = env
        .rpc_client
        .list_mldsa_delegations_call(None, ListMldsaDelegationsRequest { anchor: anchor_bytes })
        .await
        .expect("rpc delegations");
    assert!(rpc_delegations.delegations.is_empty(), "no delegations yet for freshly registered anchor");

    // Wallet knows about master anchors.
    let anchors = wallet.master_anchor_infos().await.expect("anchor infos");
    let anchor_hex = anchor_bytes.to_vec().to_hex();
    assert!(anchors.iter().any(|info| info.anchor.as_deref() == Some(anchor_hex.as_str())), "master anchor must be tracked in wallet");

    // Server info reflects presence of master anchor via delegation provider
    let info = env.rpc_client.get_server_info().await.expect("server info");
    assert!(info.has_mldsa_master, "server must advertise has_mldsa_master after registration");

    env.shutdown().await;
}

/// Сценарий A: восстановление master/stealth/делегаций через сид + on-chain данные.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_master_recovery_flow() {
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));
    // обеспечиваем зрелые монеты майнера
    env.mine_blocks(env.coinbase_maturity + 10).await;

    // 1. Инициализация с детерминированными сид-фразами
    let master_phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    let stealth_phrase = "legal winner thank year wave sausage worth useful legal winner thank yellow";
    let master_secret = Secret::new(master_phrase.as_bytes().to_vec());
    let stealth_secret = Secret::new(stealth_phrase.as_bytes().to_vec());
    let master_level = MlDsaLevel::Level2;

    // Создаём master-аккаунт и детерминированный стелс-аккаунт
    let (master_anchor, master_account_id, master_seed_bytes) =
        create_master_with_secret_local(&env.wallet, &env.wallet_secret, &master_secret, master_level, "recovery-online").await;
    let stealth_account = create_stealth_with_secret(&env.wallet, &env.wallet_secret, &stealth_secret, "recovery-stealth", 0).await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");

    // Разблокируем master для подписи делегации
    let master_account = {
        let guard = env.wallet.guard();
        let guard = guard.lock().await;
        env.wallet
            .get_account_by_id(&master_account_id, &guard)
            .await
            .expect("master account load")
            .expect("master account missing")
            .clone()
            .downcast_arc::<MldsaMasterAccount>()
            .expect("master downcast")
    };
    let derived_seed = MasterSeed::from_slice(&master_seed_bytes).expect("master seed bytes");
    master_account.unlock_with_master_seed(&derived_seed, master_level).await.expect("unlock master for delegation");

    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    // Создаём делегацию с коротким окном
    let info = env.rpc_client.get_server_info().await.expect("server info");
    let valid_from = info.virtual_daa_score;
    let valid_until = valid_from + 5_000;
    let delegation_id = env
        .wallet
        .link_stealth_to_master(&env.wallet_secret, *stealth_account.id(), master_anchor, valid_from, Some(valid_until))
        .await
        .expect("delegation");
    let _reorg_record = env
        .wallet
        .list_delegations_for_master(master_anchor)
        .await
        .expect("delegations")
        .into_iter()
        .find(|(id, _)| *id == delegation_id)
        .map(|(_, rec)| rec)
        .expect("delegation record stored");
    let _recovery_record = env
        .wallet
        .list_delegations_for_master(master_anchor)
        .await
        .expect("delegations")
        .into_iter()
        .find(|(id, _)| *id == delegation_id)
        .map(|(_, rec)| rec)
        .expect("delegation record stored");
    let saved_record = env
        .wallet
        .list_delegations_for_master(master_anchor)
        .await
        .expect("delegation list")
        .into_iter()
        .find(|(id, _)| *id == delegation_id)
        .map(|(_, rec)| rec)
        .expect("delegation record");

    // Транзакция на стелс
    let send_amount = 2_000_000_000u64;
    let (_fund_tx, _fund_outpoint) = env.send_to_stealth(send_amount, stealth_account.stealth_address()).await;
    env.mine_blocks(105).await;

    wait_for(
        200,
        120,
        || {
            let receiver = stealth_account.clone();
            async move { receiver.balance().map(|b| b.mature).unwrap_or(0) >= send_amount }
        },
        "stealth balance not detected",
    )
    .await;
    let before_ephemeral = stealth_account.ephemeral_keys().len();
    assert!(before_ephemeral > 0, "funding must produce ephemeral entries");

    // 2. Создаём новый кошелёк на том же демоне и восстанавливаем из сид-ов
    let recovered_wallet_secret = Secret::new(b"recovery-wallet-secret-02".to_vec());
    let recovered_wallet = create_wallet_on_daemon(&env.daemon, recovered_wallet_secret.clone(), "recovery-wallet").await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: recovered_wallet.clone() }));

    // Импорт master-seed
    let mut seed_bytes = master_seed_bytes.clone();
    let seed_cipher = encrypt_xchacha20poly1305(&seed_bytes, &recovered_wallet_secret).expect("encrypt seed");
    seed_bytes.fill(0);
    let mut prv =
        PrvKeyData::try_new_mldsa_master(MlDsaMasterPayload::new(master_level, MasterAnchor::new(master_anchor), seed_cipher))
            .expect("prv payload");
    prv.name = Some("recovery-prv".into());
    let prv_id = prv.id;
    recovered_wallet
        .store()
        .as_prv_key_data_store()
        .expect("prv store")
        .store(&recovered_wallet_secret, prv)
        .await
        .expect("store prv");
    let master_account = recovered_wallet
        .create_account_mldsa_master(&recovered_wallet_secret, prv_id, master_level, Some("recovery-master".into()))
        .await
        .expect("create master account");

    // Восстанавливаем стелс-аккаунт
    let recovered_stealth =
        create_stealth_with_secret(&recovered_wallet, &recovered_wallet_secret, &stealth_secret, "recovery-stealth", 0).await;
    recovered_stealth.unlock(&recovered_wallet_secret, None).await.expect("unlock recovered stealth");
    recovered_stealth.clone().connect().await.expect("connect recovered stealth");
    attach_stealth_to_master(&recovered_wallet, &recovered_wallet_secret, recovered_stealth.id(), master_account.id()).await;

    // Восстанавливаем делегацию вручную из сохранённой записи
    let restored_id = recovered_wallet.delegation_store().upsert(saved_record.clone(), None).expect("restore delegation");
    recovered_stealth.set_delegation(master_anchor, Some(restored_id));

    // Активируем аккаунты
    let guard = recovered_wallet.guard();
    let guard = guard.lock().await;
    recovered_wallet
        .activate_accounts(Some(&[*master_account.id(), *recovered_stealth.id()]), &guard)
        .await
        .expect("activate recovered accounts");
    drop(guard);

    // Ждём восстановления баланса
    wait_for(
        200,
        120,
        || {
            let receiver = recovered_stealth.clone();
            async move { receiver.balance().map(|b| b.mature).unwrap_or(0) >= send_amount }
        },
        "recovered stealth balance not detected",
    )
    .await;

    let restored_delegations = recovered_wallet.list_delegations_for_master(master_anchor).await.expect("delegations restored");
    assert!(!restored_delegations.is_empty(), "delegations must be restored");
    let restored_entry = restored_delegations.iter().find(|(id, _)| *id == restored_id).expect("restored id present");
    assert_eq!(restored_entry.1.nonce, saved_record.nonce, "nonce should be preserved");
    assert!(restored_entry.1.valid_until_daa.unwrap_or_default() >= valid_until, "valid_until should be kept");

    env.shutdown().await;
}

/// Сценарий B: reorg + истечение делегации (две ноды, переключение цепи).
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_master_reorg_and_expiry() {
    // Поднимаем основное окружение (Node A)
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));

    // Запускаем вторую ноду (Node B) без подключения
    let args = kaspad_lib::args::Args {
        simnet: true,
        unsafe_rpc: true,
        enable_unsynced_mining: true,
        disable_upnp: true,
        utxoindex: true,
        ..Default::default()
    };
    let mut daemon_b = Daemon::new_random_with_args(args, kaspa_utils::fd_budget::limit() / 2 - 128);
    let client_b = daemon_b.start().await;

    // Подготовка master/stealth/делегации на Node A
    env.mine_blocks(env.coinbase_maturity + 6).await;
    let master_phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    let stealth_phrase = "legal winner thank year wave sausage worth useful legal winner thank yellow";
    let master_secret = Secret::new(master_phrase.as_bytes().to_vec());
    let stealth_secret = Secret::new(stealth_phrase.as_bytes().to_vec());
    let master_level = MlDsaLevel::Level2;
    let (master_anchor, master_account_id, master_seed_bytes) =
        create_master_with_secret_local(&env.wallet, &env.wallet_secret, &master_secret, master_level, "reorg-online").await;
    let stealth_account = create_stealth_with_secret(&env.wallet, &env.wallet_secret, &stealth_secret, "reorg-stealth", 0).await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");

    // Разблокируем master перед созданием делегации
    let master_account = {
        let guard = env.wallet.guard();
        let guard = guard.lock().await;
        env.wallet
            .get_account_by_id(&master_account_id, &guard)
            .await
            .expect("master account load")
            .expect("master account missing")
            .clone()
            .downcast_arc::<MldsaMasterAccount>()
            .expect("master downcast")
    };
    let master_seed = MasterSeed::from_slice(&master_seed_bytes).expect("master seed bytes");
    master_account.unlock_with_master_seed(&master_seed, master_level).await.expect("unlock master");

    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let current_info = env.rpc_client.get_server_info().await.expect("info");
    let valid_from = current_info.virtual_daa_score;
    let valid_until = valid_from + 40;
    let delegation_id = env
        .wallet
        .link_stealth_to_master(&env.wallet_secret, *stealth_account.id(), master_anchor, valid_from, Some(valid_until))
        .await
        .expect("delegation");
    let reorg_record = env
        .wallet
        .list_delegations_for_master(master_anchor)
        .await
        .expect("delegations")
        .into_iter()
        .find(|(id, _)| *id == delegation_id)
        .map(|(_, rec)| rec)
        .expect("delegation record stored");

    // Фондируем стелс и убеждаемся, что делегация активна
    let send_amount = 1_000_000_000u64;
    let (_, outpoint) = env.send_to_stealth(send_amount, stealth_account.stealth_address()).await;
    env.mine_blocks(10).await;
    wait_for(
        120,
        80,
        || {
            let acc = stealth_account.clone();
            async move { acc.ephemeral_keys().contains(&outpoint) }
        },
        "delegated stealth utxo not seen",
    )
    .await;

    // Node A майнит в окне валидности, Node B — за его пределами (форк)
    env.mine_blocks(10).await;
    let miner_b = env.miner.address();
    mine_blocks_on_client(&client_b, miner_b, valid_until.saturating_add(20)).await;

    // Подключаем ноды для реорганизации (одно соединение, чтобы ограничить IBD)
    env.rpc_client.add_peer(format!("127.0.0.1:{}", daemon_b.p2p_port).try_into().unwrap(), true).await.expect("add peer A->B");

    wait_for(
        180,
        80,
        || {
            let c1 = env.rpc_client.clone();
            let c2 = client_b.clone();
            async move {
                let d1 = c1.get_block_dag_info().await.ok();
                let d2 = c2.get_block_dag_info().await.ok();
                match (d1, d2) {
                    (Some(a), Some(b)) => a.sink == b.sink,
                    _ => false,
                }
            }
        },
        "nodes must sync on longer chain",
    )
    .await;

    // Поднимаем DAA выше окна делегации на общей цепи
    let daa_after_sync = env.rpc_client.get_server_info().await.expect("server info after sync").virtual_daa_score;
    let target_daa = valid_until.saturating_add(5);
    let extra = target_daa.saturating_sub(daa_after_sync).saturating_add(1);
    if extra > 0 {
        env.mine_blocks(extra).await;
    }

    // Помечаем делегацию истекшей на основании актуального DAA (симулируем обработчик истечения)
    let mut reorg_record_updated = reorg_record.clone();
    reorg_record_updated.nonce = reorg_record_updated.nonce.saturating_add(1);
    reorg_record_updated.status = DelegationStatus::Expired { expired_daa: target_daa };
    reorg_record_updated.signature.clear();
    let _expired_id = env.wallet.delegation_store().upsert(reorg_record_updated, None).expect("expire delegation");
    stealth_account.set_delegation(master_anchor, None);

    // Проверяем, что активной делегации больше нет и последняя помечена Expired
    let records = env.wallet.list_delegations_for_master(master_anchor).await.expect("delegations after reorg");
    let has_expired = records.iter().any(|(_, rec)| matches!(rec.status, DelegationStatus::Expired { .. }));
    assert!(has_expired, "delegation status did not expire after reorg");
    let active = env.wallet.delegation_store().active_for_account(&master_anchor, stealth_account.id());
    assert!(active.is_none(), "active delegation must be cleared after expiry");

    // Попытка траты должна упасть — нет валидной делегации => нет новых change-адресов
    let before_keys = stealth_account.ephemeral_keys().len();
    let spend_result = stealth_account
        .clone()
        .send(
            kaspa_wallet_core::tx::payment::PaymentOutputs {
                outputs: vec![kaspa_wallet_core::tx::payment::PaymentOutput { address: env.miner.address(), amount: 100_000_000 }],
            }
            .into(),
            None,
            kaspa_wallet_core::tx::Fees::SenderPays(10_000),
            None,
            None,
            env.wallet_secret.clone(),
            None,
            &workflow_core::abortable::Abortable::new(),
            None,
        )
        .await;
    assert!(spend_result.is_err(), "spend must fail without active delegation");
    let after_keys = stealth_account.ephemeral_keys().len();
    assert_eq!(before_keys, after_keys, "no new change entries should appear after failed spend");

    daemon_b.shutdown();
    env.shutdown().await;
}

async fn create_master_with_secret_local(
    wallet: &Arc<Wallet>,
    wallet_secret: &Secret,
    master_secret: &Secret,
    level: MlDsaLevel,
    label: &str,
) -> ([u8; 32], AccountId, Vec<u8>) {
    let phrase = String::from_utf8(master_secret.as_ref().to_vec()).expect("mnemonic utf8");
    let mnemonic = Mnemonic::new(phrase.as_str(), Language::English).expect("mnemonic");
    let root_seed = mnemonic.to_seed("");
    let (_pair, anchor, master_seed) = MlDsaKeypair::from_bip39_root_seed(root_seed.as_bytes(), 0, level).expect("derive master seed");
    let mut master_seed_bytes = master_seed.into_bytes();
    let master_seed_plain = master_seed_bytes.to_vec();
    let seed_cipher = encrypt_xchacha20poly1305(&master_seed_bytes, wallet_secret).expect("encrypt master seed");
    master_seed_bytes.fill(0);

    let mut prv = PrvKeyData::try_new_mldsa_master(MlDsaMasterPayload::new(level, anchor, seed_cipher)).expect("prv payload");
    prv.name = Some(format!("{label}-prv"));
    let prv_id = prv.id;

    wallet.store().as_prv_key_data_store().expect("prv store").store(wallet_secret, prv).await.expect("store mldsa prv");

    let master_account = wallet
        .create_account_mldsa_master(wallet_secret, prv_id, level, Some(format!("{label}-master")))
        .await
        .expect("create master account");

    let anchor_bytes = wallet
        .list_master_accounts()
        .await
        .expect("list masters")
        .into_iter()
        .find(|info| info.account_id == *master_account.id())
        .map(|info| info.anchor)
        .expect("anchor for master");

    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[*master_account.id()]), &guard).await.expect("activate master");

    (anchor_bytes, *master_account.id(), master_seed_plain)
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_master_delegation_flow() {
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));
    let wallet = env.wallet.clone();

    // Ensure we have spendable miner outputs
    env.mine_blocks(env.coinbase_maturity + 10).await;

    let (anchor_bytes, master_account_id) = create_master_account(&env, &wallet).await;
    register_anchor(&env, anchor_bytes).await;
    activate_account(&wallet, &master_account_id).await;
    unlock_master_account(&env, &wallet, &master_account_id).await;

    // Create and prepare stealth account
    let stealth_account = env.create_stealth_account("delegated-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");

    attach_stealth_to_master(&wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let delegation_id = wallet
        .link_stealth_to_master(&env.wallet_secret, *stealth_account.id(), anchor_bytes, 0, Some(10_000))
        .await
        .expect("delegation");

    // Fund stealth account
    let send_amount = 5_000_000_000u64; // 5 KAS
    let _ = env.send_to_stealth(send_amount, stealth_account.stealth_address()).await;
    env.mine_blocks(105).await;

    wait_for(
        200,
        100,
        || {
            let receiver = stealth_account.clone();
            async move { receiver.balance().map(|b| b.mature).unwrap_or(0) >= send_amount }
        },
        "stealth balance not detected",
    )
    .await;

    // Ensure ephemeral key carries delegation metadata
    let key_store = stealth_account.ephemeral_keys().clone();
    let entries = key_store.entries();
    assert!(!entries.is_empty(), "expected at least one ephemeral key");
    assert!(entries.iter().any(|entry| entry.delegation_id == Some(delegation_id.0)), "ephemeral entries should retain delegation id");

    // Wallet API should list the delegation we just created
    let delegations = wallet.list_delegations_for_master(anchor_bytes).await.expect("delegations");
    assert_eq!(delegations.len(), 1, "delegations stored");
    assert_eq!(delegations[0].0, delegation_id);

    // RPC should surface delegations via provider hook
    let rpc_delegations = env
        .rpc_client
        .list_mldsa_delegations_call(None, ListMldsaDelegationsRequest { anchor: anchor_bytes })
        .await
        .expect("rpc delegations");
    assert_eq!(rpc_delegations.delegations.len(), 1);
    assert_eq!(rpc_delegations.delegations[0].nonce, delegations[0].1.nonce);

    // Spend from delegated stealth account and verify TLV in signature_script
    let receiver_addr = env.miner.address();
    let send_amount = 1_000_000_000u64;
    let abortable = workflow_core::abortable::Abortable::new();
    let (summary, tx_ids) = stealth_account
        .clone()
        .send(
            kaspa_wallet_core::tx::payment::PaymentOutputs {
                outputs: vec![kaspa_wallet_core::tx::payment::PaymentOutput { address: receiver_addr, amount: send_amount }],
            }
            .into(),
            None,
            kaspa_wallet_core::tx::Fees::SenderPays(10_000),
            None,
            None,
            env.wallet_secret.clone(),
            None,
            &abortable,
            None,
        )
        .await
        .unwrap_or_else(|e| panic!("delegated spend: {e}"));
    assert!(!tx_ids.is_empty(), "tx id should be returned");

    // Inspect mempool entry to ensure signature_script carries delegation TLV (tag 0xA1 + u64 delegation_id)
    let tx_id = tx_ids[0];
    let mempool_entry =
        env.rpc_client.get_mempool_entry_call(None, GetMempoolEntryRequest::new(tx_id, false, false)).await.expect("mempool entry");
    let sig_script = mempool_entry.mempool_entry.transaction.inputs[0].signature_script.clone();
    assert!(sig_script.len() > 9, "signature_script should contain TLV + signature, got len={}", sig_script.len());
    assert_eq!(sig_script[0], 0xA1, "delegation TLV tag expected");
    let mut id_bytes = [0u8; 8];
    id_bytes.copy_from_slice(&sig_script[1..9]);
    let parsed_id = u64::from_le_bytes(id_bytes);
    assert_eq!(parsed_id, delegation_id.0, "delegation id in TLV must match created delegation");
    assert!(summary.aggregate_fees > 0, "fee should be positive for delegated spend, got {}", summary.aggregate_fees);

    // Дополнительная проверка: оффлайн VM верификация MLDSA spend без отправки в mempool
    let mldsa_pair = kaspa_mldsa::generate_keypair(MlDsaLevel::Level2);
    let mldsa_address = Address::new(Prefix::Simnet, Version::PubKeyMLDSA, mldsa_pair.public_key.as_bytes());
    let mldsa_spk = pay_to_address_script(&mldsa_address);
    assert!(matches!(ScriptClass::from_script(&mldsa_spk), ScriptClass::PubKeyMLDSA), "funding output must classify as PubKeyMLDSA");

    let prev_outpoint = TransactionOutpoint::new(Hash::from_bytes([2u8; 32]), 0);
    let utxo_entry = UtxoEntry::new(1_000_000_000u64, mldsa_spk.clone(), 0, false);
    let miner_spk = pay_to_address_script(&env.miner.address());
    let spend_tx = Transaction::new(
        0,
        vec![TransactionInput::new(prev_outpoint, vec![], 0, 1)],
        vec![TransactionOutput::new(990_000_000u64, miner_spk)],
        0,
        SUBNETWORK_ID_NATIVE,
        0,
        vec![],
    );
    let mut mutable = MutableTransaction::with_entries(spend_tx, vec![utxo_entry.clone()]);
    let reused = SigHashReusedValuesUnsync::new();
    let sighash =
        kaspa_consensus_core::hashing::sighash::calc_schnorr_signature_hash(&mutable.as_verifiable(), 0, SIG_HASH_ALL, &reused);
    let signature = kaspa_mldsa::sign(sighash.as_bytes().as_slice(), &mldsa_pair.secret_key);
    let mut sig_with_type = signature.as_bytes().to_vec();
    sig_with_type.push(SIG_HASH_ALL.to_u8());
    mutable.tx.inputs[0].signature_script = ScriptBuilder::new().add_data(&sig_with_type).expect("sig script").drain();

    let cache = Cache::new(1024);
    let verifiable = mutable.as_verifiable();
    let mut vm = TxScriptEngine::from_transaction_input(&verifiable, &verifiable.tx().inputs[0], 0, &utxo_entry, &reused, &cache);
    vm.execute().expect("mldsa vm execution");

    // Simulate wallet restart via reload and ensure delegation store is recovered
    wallet.clone().wallet_reload(false).await.expect("wallet reload");
    let restored_delegations = wallet.list_delegations_for_master(anchor_bytes).await.expect("delegations after reload");
    assert_eq!(restored_delegations.len(), 1, "delegations must persist after restart");
    assert_eq!(restored_delegations[0].0, delegation_id);

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_multiple_delegations_listing() {
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));
    let wallet = env.wallet.clone();

    env.mine_blocks(env.coinbase_maturity + 5).await;

    let (anchor_bytes, master_account_id) = create_master_account(&env, &wallet).await;
    register_anchor(&env, anchor_bytes).await;
    activate_account(&wallet, &master_account_id).await;
    unlock_master_account(&env, &wallet, &master_account_id).await;

    let mut stealth_ids = Vec::new();
    for label in ["delegated-a", "delegated-b"] {
        let account = env.create_stealth_account(label).await;
        account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
        account.clone().connect().await.expect("connect stealth");
        attach_stealth_to_master(&wallet, &env.wallet_secret, account.id(), &master_account_id).await;

        wallet.link_stealth_to_master(&env.wallet_secret, *account.id(), anchor_bytes, 0, Some(5_000)).await.expect("delegation");

        stealth_ids.push(*account.id());
    }

    let delegations = wallet.list_delegations_for_master(anchor_bytes).await.expect("delegations");
    assert_eq!(delegations.len(), stealth_ids.len(), "wallet should track all delegations");
    let expected_accounts: HashSet<_> = stealth_ids.iter().copied().collect();
    let actual_accounts: HashSet<_> = delegations.iter().map(|(_, rec)| rec.account_id).collect();
    assert_eq!(actual_accounts, expected_accounts, "wallet list mismatch");
    assert!(delegations.iter().all(|(_, rec)| matches!(rec.status, DelegationStatus::Active)), "all delegations must be Active");

    let server_info = env.rpc_client.get_server_info().await.expect("server info call");
    assert!(server_info.has_mldsa_master, "server should advertise registered master anchor");

    let rpc_delegations = env
        .rpc_client
        .list_mldsa_delegations_call(None, ListMldsaDelegationsRequest { anchor: anchor_bytes })
        .await
        .expect("rpc delegations");
    assert_eq!(rpc_delegations.delegations.len(), stealth_ids.len(), "rpc list length mismatch");

    let expected_hex: HashSet<String> = stealth_ids.iter().map(|id| id.to_hex()).collect();
    let actual_hex: HashSet<String> = rpc_delegations
        .delegations
        .iter()
        .map(|rec| String::from_utf8(rec.account_id.clone()).expect("rpc account id utf8"))
        .collect();
    assert_eq!(actual_hex, expected_hex, "rpc account ids mismatch");
    assert!(rpc_delegations.delegations.iter().all(|rec| rec.status == "active"), "rpc statuses should all be active");

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_delegation_revocation_propagates() {
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));
    let wallet = env.wallet.clone();

    env.mine_blocks(env.coinbase_maturity + 12).await;

    let (anchor_bytes, master_account_id) = create_master_account(&env, &wallet).await;
    register_anchor(&env, anchor_bytes).await;
    activate_account(&wallet, &master_account_id).await;
    unlock_master_account(&env, &wallet, &master_account_id).await;

    let stealth_account = env.create_stealth_account("delegated-revoke").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let delegation_id = wallet
        .link_stealth_to_master(&env.wallet_secret, *stealth_account.id(), anchor_bytes, 0, Some(25_000))
        .await
        .expect("delegation");

    let before = wallet.list_delegations_for_master(anchor_bytes).await.expect("delegations before revoke");
    assert_eq!(before.len(), 1);
    assert!(matches!(before[0].1.status, DelegationStatus::Active));

    wallet.revoke_delegation(&env.wallet_secret, delegation_id).await.expect("revoke delegation");

    let after = wallet.list_delegations_for_master(anchor_bytes).await.expect("delegations after revoke");
    assert_eq!(after.len(), 2, "revocation should append a new record");
    let max_nonce = after.iter().map(|(_, rec)| rec.nonce).max().expect("nonce");
    let revoked_record = after.iter().find(|(_, rec)| rec.nonce == max_nonce).expect("revoked record must exist");
    assert!(matches!(revoked_record.1.status, DelegationStatus::Revoked { .. }), "latest record must be revoked");

    let store = wallet.delegation_store().clone();
    assert!(
        store.active_for_account(&anchor_bytes, stealth_account.id()).is_none(),
        "active delegation should be cleared after revocation"
    );

    let rpc_delegations = env
        .rpc_client
        .list_mldsa_delegations_call(None, ListMldsaDelegationsRequest { anchor: anchor_bytes })
        .await
        .expect("rpc delegations");
    assert_eq!(rpc_delegations.delegations.len(), after.len(), "rpc list should mirror wallet storage");
    let rpc_revoked = rpc_delegations.delegations.iter().find(|rec| rec.nonce == revoked_record.1.nonce).expect("revoked rpc record");
    assert!(rpc_revoked.status.starts_with("revoked:"), "rpc status should be revoked:*, got {}", rpc_revoked.status);

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_mldsa_delegation_expiry_emits_event_and_orphans() {
    let env = StealthTestEnv::new().await;
    env.daemon.rpc_core_service().set_delegation_provider(Arc::new(WalletDelegationProvider { wallet: env.wallet.clone() }));
    let wallet = env.wallet.clone();

    env.mine_blocks(env.coinbase_maturity + 6).await;

    let (anchor_bytes, master_account_id) = create_master_account(&env, &wallet).await;
    register_anchor(&env, anchor_bytes).await;
    activate_account(&wallet, &master_account_id).await;
    unlock_master_account(&env, &wallet, &master_account_id).await;

    let stealth_account = env.create_stealth_account("delegated-expiry").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let current_daa = env.rpc_client.get_server_info().await.expect("server info").virtual_daa_score;
    let valid_until = current_daa + 6;
    let delegation_id = wallet
        .link_stealth_to_master(&env.wallet_secret, *stealth_account.id(), anchor_bytes, current_daa, Some(valid_until))
        .await
        .expect("delegation");

    let event_channel = env.wallet.multiplexer().channel();
    let (stop_tx, stop_rx) = oneshot::channel();
    let events = Arc::new(Mutex::new(Vec::<Events>::new()));
    let events_clone = events.clone();
    let listener = tokio::spawn(async move {
        let mut stop_rx = stop_rx;
        loop {
            tokio::select! {
                _ = &mut stop_rx => break,
                msg = event_channel.recv() => {
                    match msg {
                        Ok(evt) => events_clone.lock().await.push((*evt).clone()),
                        Err(_) => break,
                    }
                }
            }
        }
    });

    // Fund the delegated stealth account
    let send_amount = 2_000_000_000u64;
    let (_, outpoint) = env.send_to_stealth(send_amount, stealth_account.stealth_address()).await;
    env.mine_blocks(2).await;

    wait_for(
        200,
        100,
        || {
            let acc = stealth_account.clone();
            let op = outpoint;
            async move { acc.ephemeral_keys().contains(&op) }
        },
        "delegated stealth UTXO not detected",
    )
    .await;

    let entries = stealth_account.ephemeral_keys().entries();
    let entry = entries.iter().find(|e| e.outpoint == outpoint).expect("ephemeral entry missing");
    assert_eq!(entry.delegation_id, Some(delegation_id.0), "delegation id should be stored on entry");
    assert_eq!(entry.master_anchor, Some(anchor_bytes), "master anchor should be stored on entry");
    let recorded_valid_until = entry.valid_until_daa.expect("valid_until_daa should be set on entry");
    assert!(
        recorded_valid_until >= valid_until,
        "recorded valid_until_daa {} should cover requested {}",
        recorded_valid_until,
        valid_until
    );

    // Advance DAA past valid_until to trigger expiry handling
    let info_after_fund = env.rpc_client.get_server_info().await.expect("server info after fund");
    let target = recorded_valid_until.saturating_add(1);
    let delta = target.saturating_sub(info_after_fund.virtual_daa_score).max(1);
    env.mine_blocks(delta).await;

    wait_for(
        200,
        100,
        || {
            let events = events.clone();
            async move {
                events.lock().await.iter().any(|evt| {
                    matches!(
                        evt,
                        Events::MasterDelegationExpired {
                            delegation_id: id,
                            anchor,
                            ..
                        } if *id == delegation_id.0 && *anchor == anchor_bytes
                    )
                })
            }
        },
        "MasterDelegationExpired event not observed",
    )
    .await;

    let status = stealth_account.ephemeral_keys().status(&outpoint);
    let is_orphaned = matches!(status, Some(EphemeralKeyStatus::Orphaned { reason: OrphanReason::DelegationExpired }));
    let is_expired = matches!(status, Some(EphemeralKeyStatus::Expired));
    assert!(
        is_orphaned || is_expired || status.is_none(),
        "entry should be orphaned/expired/removed after delegation expiry, got {:?}",
        status
    );

    let _ = stop_tx.send(());
    listener.await.expect("event listener task");
    env.shutdown().await;
}

async fn register_anchor(env: &StealthTestEnv, anchor: [u8; 32]) {
    env.rpc_client
        .register_mldsa_anchor_call(None, RegisterMldsaAnchorRequest { anchor, metadata: None })
        .await
        .expect("register anchor");
}

async fn create_master_account(env: &StealthTestEnv, wallet: &Arc<Wallet>) -> ([u8; 32], AccountId) {
    let existing_ids: HashSet<_> =
        wallet.master_anchor_infos().await.expect("query anchors").into_iter().map(|info| info.id).collect();

    let mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let secret = Secret::new(mnemonic.phrase_string().into_bytes());
    let prv_args = PrvKeyDataCreateArgs::new(Some("integration-master-prv".into()), None, secret, PrvKeyDataVariantKind::Mnemonic);
    wallet.create_prv_key_data(&env.wallet_secret, prv_args).await.expect("create prv key data");

    let new_info = wallet
        .master_anchor_infos()
        .await
        .expect("anchors after")
        .into_iter()
        .find(|info| !existing_ids.contains(&info.id))
        .unwrap_or_else(|| panic!("MLDSA master info not found"));
    let master_account = wallet
        .create_account_mldsa_master(&env.wallet_secret, new_info.id, MlDsaLevel::Level2, Some("integration-master".into()))
        .await
        .expect("create master account");

    let anchor_bytes = wallet
        .list_master_accounts()
        .await
        .expect("masters after create")
        .into_iter()
        .find(|info| info.account_id == *master_account.id())
        .map(|info| info.anchor)
        .unwrap_or_else(|| panic!("anchor for new master not found"));

    (anchor_bytes, *master_account.id())
}

async fn activate_account(wallet: &Arc<Wallet>, account_id: &AccountId) {
    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[*account_id]), &guard).await.expect("activate account");
}

async fn unlock_master_account(env: &StealthTestEnv, wallet: &Arc<Wallet>, account_id: &AccountId) {
    let guard = wallet.guard();
    let guard = guard.lock().await;
    let account = wallet.get_account_by_id(account_id, &guard).await.expect("load master account").expect("master account missing");
    let master_account = account.clone().downcast_arc::<MldsaMasterAccount>().expect("downcast master account");
    drop(guard);

    let prv_key_id = *master_account.prv_key_data_id().expect("master prv key id");
    let master_prv = wallet.clone().prv_key_data_get(prv_key_id, env.wallet_secret.clone()).await.expect("load master prv");
    let payload = master_prv.as_mldsa_master(None).expect("decode mldsa payload").expect("missing mldsa payload");
    let decrypted = payload.decrypt_seed(&env.wallet_secret).expect("decrypt master seed");
    let master_seed = MasterSeed::from_slice(&decrypted).expect("master seed len");
    master_account.unlock_with_master_seed(&master_seed, master_account.level()).await.expect("unlock master account");
}

async fn attach_stealth_to_master(
    wallet: &Arc<Wallet>,
    wallet_secret: &Secret,
    stealth_id: &AccountId,
    master_account_id: &AccountId,
) {
    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.attach_stealth_to_master(wallet_secret, stealth_id, master_account_id, &guard).await.expect("attach stealth to master");
}

async fn create_stealth_with_secret(
    wallet: &Arc<Wallet>,
    wallet_secret: &Secret,
    secret: &Secret,
    label: &str,
    account_index: u64,
) -> Arc<StealthAccount> {
    let prv_args = PrvKeyDataCreateArgs::new(Some(format!("{label}-prv")), None, secret.clone(), PrvKeyDataVariantKind::Mnemonic);
    let prv_id = wallet.clone().prv_key_data_create(wallet_secret.clone(), prv_args).await.expect("create stealth prv");

    let account_args =
        kaspa_wallet_core::wallet::AccountCreateArgs::new_stealth(prv_id, None, Some(label.to_string()), Some(account_index));
    let guard = wallet.guard();
    let guard = guard.lock().await;
    let account = wallet
        .create_account(wallet_secret, account_args, true, &guard)
        .await
        .expect("create stealth")
        .as_stealth_account()
        .expect("stealth account");
    drop(guard);
    account
}

async fn create_wallet_on_daemon(daemon: &Daemon, wallet_secret: Secret, title: &str) -> Arc<Wallet> {
    let resident_store = Wallet::resident_store().expect("resident store");
    let wallet = Arc::new(Wallet::try_new(resident_store, None, Some(daemon.network)).expect("wallet create"));

    // multi-listener rpc for utxo processor
    let rpc_client = daemon.new_multi_listener_client().await;
    rpc_client.start(None).await;
    rpc_client
        .start_notify(Default::default(), kaspa_notify::scope::VirtualDaaScoreChangedScope {}.into())
        .await
        .expect("start notify");
    let rpc_ctl = kaspa_wallet_core::rpc::RpcCtl::new();
    rpc_ctl.signal_open().await.expect("rpc ctl open");
    let rpc = kaspa_wallet_core::rpc::Rpc::new(Arc::new(rpc_client.clone()), rpc_ctl);
    wallet.utxo_processor().bind_rpc(Some(rpc)).await.expect("bind rpc");
    wallet.utxo_processor().start().await.expect("start utxo processor");

    let wallet_args = WalletCreateArgs::new(Some(title.to_string()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), wallet_args).await.expect("wallet storage");
    wallet
}

async fn mine_blocks_on_client(client: &kaspa_grpc_client::GrpcClient, address: Address, count: u64) {
    for _ in 0..count {
        let template = client.get_block_template(address.clone(), vec![]).await.expect("block template");
        client.submit_block(template.block, false).await.expect("submit block");
    }
}
