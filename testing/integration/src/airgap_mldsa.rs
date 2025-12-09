use crate::common::utils::wait_for;
use crate::stealth_flow::StealthTestEnv;
use kaspa_bip32::{Language, Mnemonic, WordCount};
use kaspa_consensus_core::network::{NetworkId, NetworkType};
use kaspa_mldsa::MlDsaLevel;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_core::account::variants::stealth::StealthAccount;
use kaspa_wallet_core::account::Account;
use kaspa_wallet_core::api::message::MasterDelegationTarget;
use kaspa_wallet_core::api::traits::WalletApi;
use kaspa_wallet_core::encryption::{encrypt_xchacha20poly1305, EncryptionKind};
use kaspa_wallet_core::message::{calc_request_id, MasterDelegationRequestBodyV1};
use kaspa_wallet_core::rpc::RpcApi;
use kaspa_wallet_core::storage::{self, keydata::data::MlDsaMasterPayload};
use kaspa_wallet_core::wallet::args::WalletCreateArgs;
use kaspa_wallet_core::wallet::Wallet;
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
use kaspa_wallet_keys::secret::Secret;
use std::sync::Arc;

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_airgap_delegation_offline_sign_and_apply() {
    // Online environment with full RPC / UTXO processing
    let env = StealthTestEnv::new().await;
    env.mine_blocks(env.coinbase_maturity + 8).await;
    let network_id = env.wallet.network_id().expect("network id");

    // Use a deterministic master seed shared between online/offline wallets
    let master_mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let master_secret = Secret::new(master_mnemonic.phrase_string().into_bytes());
    let master_level = MlDsaLevel::Level2;

    // Online master + stealth setup
    let (master_anchor, master_account_id) =
        create_master_with_secret(&env.wallet, &env.wallet_secret, &master_secret, master_level, "airgap-online").await;

    // Create target stealth account once and bind it to the master
    let stealth_account = env.create_stealth_account("airgap-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    // Prepare offline wallet with the same master seed but no RPC binding
    let offline_wallet_secret = Secret::new(b"offline-wallet-secret-01".to_vec());
    let offline_wallet = create_offline_wallet(network_id, &offline_wallet_secret, &master_secret, master_level).await;
    let offline_anchor = offline_wallet
        .list_master_accounts()
        .await
        .expect("offline anchors")
        .first()
        .map(|info| info.anchor)
        .expect("offline master anchor");
    assert_eq!(offline_anchor, master_anchor, "offline anchor must match online anchor");

    // Build delegation request on the online wallet (simulating connected UI)
    let request_body = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(1)).await;
    // Ensure checksum is deterministic before sending offline
    let recomputed = calc_request_id(&request_body).expect("calc request_id");
    assert_eq!(recomputed, request_body.request_id, "request checksum should be stable");

    // Offline signing on isolated wallet
    let signed = offline_wallet
        .sign_master_delegation_request(&offline_wallet_secret, request_body.clone(), false)
        .await
        .expect("offline sign");
    assert_eq!(signed.response.request_id, request_body.request_id, "signed response must carry original request_id");

    // Apply signed response back online
    let applied = env
        .wallet
        .apply_master_delegation_response(&env.wallet_secret, request_body.clone(), signed.response.clone(), false)
        .await
        .expect("apply response");
    assert_eq!(applied.applied, 1, "one delegation should be applied");
    assert_eq!(applied.skipped, 0, "no delegation should be skipped");
    assert!(applied.missing_accounts.is_empty(), "all accounts should exist locally");

    // Fund delegated stealth account and ensure the wallet recognizes funds via delegation
    let send_amount = 2_000_000_000u64;
    let _ = env.send_to_stealth(send_amount, stealth_account.stealth_address()).await;
    env.mine_blocks(105).await;

    wait_for(
        200,
        150,
        || {
            let receiver = stealth_account.clone();
            async move { receiver.balance().map(|b| b.mature).unwrap_or(0) >= send_amount }
        },
        "delegated stealth balance not detected",
    )
    .await;

    // Delegation metadata should be attached to ephemeral entries after apply()
    let entries = stealth_account.ephemeral_keys().entries();
    assert!(
        entries.iter().any(|entry| entry.delegation_id.is_some()),
        "ephemeral keys should retain delegation id after offline apply"
    );

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_airgap_delegation_tampered_request_rejected_offline() {
    let env = StealthTestEnv::new().await;
    env.mine_blocks(env.coinbase_maturity + 4).await;
    let network_id = env.wallet.network_id().expect("network id");

    let master_mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let master_secret = Secret::new(master_mnemonic.phrase_string().into_bytes());
    let master_level = MlDsaLevel::Level2;

    let (master_anchor, master_account_id) =
        create_master_with_secret(&env.wallet, &env.wallet_secret, &master_secret, master_level, "tamper-online").await;
    let stealth_account = env.create_stealth_account("tamper-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let offline_wallet_secret = Secret::new(b"offline-wallet-secret-02".to_vec());
    let offline_wallet = create_offline_wallet(network_id, &offline_wallet_secret, &master_secret, master_level).await;
    let mut request_body = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(1)).await;

    // Подмена payload без пересчёта request_id должна отклоняться оффлайн-кошельком.
    request_body.delegations[0].nonce += 1;
    let tampered = offline_wallet.sign_master_delegation_request(&offline_wallet_secret, request_body, false).await;
    assert!(tampered.is_err(), "tampered request must be rejected by checksum");

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_airgap_delegation_network_mismatch_rejected() {
    let env = StealthTestEnv::new().await;
    env.mine_blocks(env.coinbase_maturity + 4).await;

    let master_mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let master_secret = Secret::new(master_mnemonic.phrase_string().into_bytes());
    let master_level = MlDsaLevel::Level2;

    let (master_anchor, master_account_id) =
        create_master_with_secret(&env.wallet, &env.wallet_secret, &master_secret, master_level, "mismatch-online").await;
    let stealth_account = env.create_stealth_account("mismatch-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let request_body = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(1)).await;

    // Оффлайн кошелёк на другой сети должен отказать без force-флага.
    let offline_wallet_secret = Secret::new(b"offline-wallet-secret-03".to_vec());
    let offline_wallet =
        create_offline_wallet(NetworkId::new(NetworkType::Mainnet), &offline_wallet_secret, &master_secret, master_level).await;
    let result = offline_wallet.sign_master_delegation_request(&offline_wallet_secret, request_body, false).await;
    assert!(result.is_err(), "network mismatch must be rejected without force flag");

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_airgap_delegation_missing_account_is_skipped() {
    let env = StealthTestEnv::new().await;
    env.mine_blocks(env.coinbase_maturity + 4).await;
    let network_id = env.wallet.network_id().expect("network id");

    let master_mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let master_secret = Secret::new(master_mnemonic.phrase_string().into_bytes());
    let master_level = MlDsaLevel::Level2;

    let (master_anchor, master_account_id) =
        create_master_with_secret(&env.wallet, &env.wallet_secret, &master_secret, master_level, "missing-online").await;
    let stealth_account = env.create_stealth_account("missing-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let request_body = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(1)).await;

    let offline_wallet_secret = Secret::new(b"offline-wallet-secret-04".to_vec());
    let offline_wallet = create_offline_wallet(network_id, &offline_wallet_secret, &master_secret, master_level).await;
    let signed = offline_wallet
        .sign_master_delegation_request(&offline_wallet_secret, request_body.clone(), false)
        .await
        .expect("offline sign");

    // Применяем ответ в кошельке без стелс-аккаунта: делегация должна быть пропущена и отражена в missing_accounts.
    let missing_wallet_secret = Secret::new(b"missing-wallet-secret-05".to_vec());
    let missing_wallet = create_offline_wallet(network_id, &missing_wallet_secret, &master_secret, master_level).await;
    let result = missing_wallet
        .apply_master_delegation_response(&missing_wallet_secret, request_body, signed.response, false)
        .await
        .expect("apply in wallet without stealth account");

    assert_eq!(result.applied, 0, "no delegations should be applied without local accounts");
    assert_eq!(result.skipped, 1, "delegation should be skipped when account is absent");
    assert_eq!(result.missing_accounts.len(), 1, "missing account must be reported");

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_airgap_delegation_stale_nonce_is_skipped() {
    let env = StealthTestEnv::new().await;
    env.mine_blocks(env.coinbase_maturity + 4).await;
    let network_id = env.wallet.network_id().expect("network id");

    let master_mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let master_secret = Secret::new(master_mnemonic.phrase_string().into_bytes());
    let master_level = MlDsaLevel::Level2;

    let (master_anchor, master_account_id) =
        create_master_with_secret(&env.wallet, &env.wallet_secret, &master_secret, master_level, "stale-online").await;
    let stealth_account = env.create_stealth_account("stale-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let offline_wallet_secret = Secret::new(b"offline-wallet-secret-06".to_vec());
    let offline_wallet = create_offline_wallet(network_id, &offline_wallet_secret, &master_secret, master_level).await;

    let request_v1 = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(1)).await;
    let request_v2 = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(2)).await;

    let signed_v1 = offline_wallet
        .sign_master_delegation_request(&offline_wallet_secret, request_v1.clone(), false)
        .await
        .expect("offline sign v1");
    let signed_v2 = offline_wallet
        .sign_master_delegation_request(&offline_wallet_secret, request_v2.clone(), false)
        .await
        .expect("offline sign v2");

    let applied_new = env
        .wallet
        .apply_master_delegation_response(&env.wallet_secret, request_v2, signed_v2.response, false)
        .await
        .expect("apply higher nonce");
    assert_eq!(applied_new.applied, 1, "higher nonce delegation should apply");
    assert_eq!(applied_new.skipped, 0);

    let applied_old = env
        .wallet
        .apply_master_delegation_response(&env.wallet_secret, request_v1, signed_v1.response, false)
        .await
        .expect("apply lower nonce");
    assert_eq!(applied_old.applied, 0, "lower nonce should be skipped");
    assert_eq!(applied_old.skipped, 1, "stale delegation counted as skipped");
    assert!(applied_old.missing_accounts.is_empty(), "account exists locally");

    env.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_airgap_delegation_tampered_response_rejected_online() {
    let env = StealthTestEnv::new().await;
    env.mine_blocks(env.coinbase_maturity + 4).await;
    let network_id = env.wallet.network_id().expect("network id");

    let master_mnemonic = Mnemonic::random(WordCount::Words12, Language::English).unwrap();
    let master_secret = Secret::new(master_mnemonic.phrase_string().into_bytes());
    let master_level = MlDsaLevel::Level2;

    let (master_anchor, master_account_id) =
        create_master_with_secret(&env.wallet, &env.wallet_secret, &master_secret, master_level, "tampered-response-online").await;
    let stealth_account = env.create_stealth_account("tampered-response-stealth").await;
    stealth_account.unlock(&env.wallet_secret, None).await.expect("unlock stealth");
    stealth_account.clone().connect().await.expect("connect stealth");
    attach_stealth_to_master(&env.wallet, &env.wallet_secret, stealth_account.id(), &master_account_id).await;

    let offline_wallet_secret = Secret::new(b"offline-wallet-secret-07".to_vec());
    let offline_wallet = create_offline_wallet(network_id, &offline_wallet_secret, &master_secret, master_level).await;

    let request_body = build_delegation_request(&env, master_anchor, master_level as u8, &stealth_account, Some(1)).await;
    let signed = offline_wallet
        .sign_master_delegation_request(&offline_wallet_secret, request_body.clone(), false)
        .await
        .expect("offline sign");

    let mut tampered_response = signed.response.clone();
    tampered_response.request_id[0] ^= 0xFF;

    let result = env.wallet.apply_master_delegation_response(&env.wallet_secret, request_body, tampered_response, false).await;
    assert!(result.is_err(), "tampered response must be rejected online");

    env.shutdown().await;
}

async fn create_master_with_secret(
    wallet: &Arc<Wallet>,
    wallet_secret: &Secret,
    master_secret: &Secret,
    level: MlDsaLevel,
    label: &str,
) -> ([u8; 32], kaspa_wallet_core::deterministic::AccountId) {
    // Конвертируем заранее сгенерированную мнемонику в MLDSA master payload и сохраняем как MlDsaMaster.
    let phrase = String::from_utf8(master_secret.as_ref().to_vec()).expect("mnemonic utf8");
    let mnemonic = Mnemonic::new(phrase.as_str(), Language::English).expect("mnemonic");
    let seed = mnemonic.to_seed("");
    let root_seed = seed.as_bytes();
    let (_pair, anchor, master_seed) = MlDsaKeypair::from_bip39_root_seed(root_seed, 0, level).expect("derive master seed");
    let mut master_seed_bytes = master_seed.into_bytes();
    let seed_cipher = encrypt_xchacha20poly1305(&master_seed_bytes, wallet_secret).expect("encrypt master seed");
    master_seed_bytes.fill(0);

    let mut prv = storage::PrvKeyData::try_new_mldsa_master(MlDsaMasterPayload::new(level, anchor, seed_cipher)).expect("prv payload");
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

    (anchor_bytes, *master_account.id())
}

async fn create_offline_wallet(
    network_id: NetworkId,
    wallet_secret: &Secret,
    master_secret: &Secret,
    level: MlDsaLevel,
) -> Arc<Wallet> {
    let store = Wallet::resident_store().expect("offline store");
    let wallet = Arc::new(Wallet::try_with_rpc(None, store, Some(network_id)).expect("offline wallet"));
    let wallet_args = WalletCreateArgs::new(Some("airgap-offline-wallet".into()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), wallet_args).await.expect("create offline wallet storage");

    let _ = create_master_with_secret(&wallet, wallet_secret, master_secret, level, "airgap-offline").await;
    wallet
}

async fn attach_stealth_to_master(
    wallet: &Arc<Wallet>,
    wallet_secret: &Secret,
    stealth_id: &kaspa_wallet_core::deterministic::AccountId,
    master_account_id: &kaspa_wallet_core::deterministic::AccountId,
) {
    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.attach_stealth_to_master(wallet_secret, stealth_id, master_account_id, &guard).await.expect("attach stealth");
}

async fn build_delegation_request(
    env: &StealthTestEnv,
    master_anchor: [u8; 32],
    master_level: u8,
    stealth_account: &Arc<StealthAccount>,
    nonce_hint: Option<u64>,
) -> MasterDelegationRequestBodyV1 {
    let server_info = env.rpc_client.get_server_info().await.expect("server info");
    let valid_from = server_info.virtual_daa_score;
    let valid_until = valid_from + 5_000;

    let request = env
        .wallet
        .build_master_delegation_request(
            &env.wallet_secret,
            kaspa_wallet_core::api::message::MasterDelegationBuildRequest {
                wallet_secret: env.wallet_secret.clone(),
                master_anchor: Some(master_anchor.to_vec().to_hex()),
                master_level: Some(master_level),
                network_id: Some(server_info.network_id),
                targets: vec![MasterDelegationTarget {
                    account_id: *stealth_account.id(),
                    valid_from_daa: Some(valid_from),
                    valid_until_daa: Some(valid_until),
                    nonce_hint: nonce_hint.or(Some(1)),
                    status: None,
                }],
                created_at_unixtime: Some(
                    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs(),
                ),
            },
        )
        .await
        .expect("build delegation request");

    request.request
}
