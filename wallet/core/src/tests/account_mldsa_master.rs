use crate::account::delegation::{sign_with_master, DelegationRecordV1, DelegationStatus};
use crate::account::variants::mldsa_master::{MasterSignDomain, MasterStatus, MldsaMasterAccount};
use crate::account::variants::stealth::StealthAccount;
use crate::api::traits::WalletApi;
use crate::encryption::{encrypt_xchacha20poly1305, EncryptionKind};
use crate::message::{calc_request_id, DelegationRecordHeaderV1, MasterDelegationRequestBodyV1, MasterDelegationResponseBodyV1};
use crate::storage::keydata::data::MlDsaMasterPayload;
use crate::storage::keydata::PrvKeyData;
use crate::storage::keydata::PrvKeyDataId;
use crate::wallet::args::WalletCreateArgs;
use crate::wallet::Wallet;
use kaspa_bip32::{Language, Mnemonic, WordCount};
use kaspa_consensus_core::network::{NetworkId, NetworkType};
use kaspa_mldsa::{MasterSeed, MlDsaKeypair as CryptoMlDsaKeypair, MlDsaLevel};
use kaspa_wallet_keys::keypair_mldsa::MlDsaKeypair;
use kaspa_wallet_keys::secret::Secret;
use std::sync::Arc;

async fn setup_wallet() -> Arc<Wallet> {
    let store = Wallet::resident_store().expect("resident store");
    let wallet = Arc::new(Wallet::try_with_rpc(None, store, None).expect("wallet"));
    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let args = WalletCreateArgs::new(Some("mldsa-master-test".into()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), args).await.expect("wallet create");
    wallet
}

fn make_seed_and_anchor(level: MlDsaLevel) -> ([u8; 48], MlDsaKeypair, [u8; 32]) {
    let mut root_seed = [0u8; 64];
    for (i, b) in root_seed.iter_mut().enumerate() {
        *b = (i as u8).wrapping_mul(5);
    }
    let (pair, anchor, master_seed) = MlDsaKeypair::from_bip39_root_seed(&root_seed, 0, level).expect("derive");
    (master_seed.into_bytes(), pair, *anchor.as_bytes())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn create_and_unlock_master_account() {
    let wallet = setup_wallet().await;
    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let (seed_bytes, _pair, anchor_bytes) = make_seed_and_anchor(MlDsaLevel::Level2);
    let seed_cipher = encrypt_xchacha20poly1305(&seed_bytes, &wallet_secret).expect("encrypt seed");
    let payload =
        MlDsaMasterPayload::new(MlDsaLevel::Level2, kaspa_wallet_keys::keypair_mldsa::MasterAnchor::new(anchor_bytes), seed_cipher);
    let mut prv = PrvKeyData::try_new_mldsa_master(payload).expect("prv");
    prv.name = Some("test-master-prv".into());
    let prv_id = prv.id;

    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv).await.expect("store prv");

    let account = wallet
        .create_account_mldsa_master(&wallet_secret, prv_id, MlDsaLevel::Level2, Some("master-acc".into()))
        .await
        .expect("create account");

    let guard = wallet.guard();
    let guard = guard.lock().await;
    let loaded = wallet.get_account_by_id(account.id(), &guard).await.expect("get account").expect("account missing");
    drop(guard);
    let master = loaded.clone().downcast_arc::<MldsaMasterAccount>().expect("downcast master");

    let master_seed = MasterSeed::from_slice(&seed_bytes).expect("seed len");
    master.unlock_with_master_seed(&master_seed, MlDsaLevel::Level2).await.expect("unlock");

    let sig = master.sign_message(&MasterSignDomain::AnchorExport, b"hello").await.expect("sign");
    assert!(!sig.as_bytes().is_empty(), "signature must be non-empty");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn master_sign_does_not_panic_with_keypair_constructed_from_raw_bytes() {
    let wallet = setup_wallet().await;

    let level = MlDsaLevel::Level2;
    let public_bytes = vec![0u8; level.public_key_len()];
    let secret_bytes = vec![0u8; level.secret_key_len()];
    let crypto = CryptoMlDsaKeypair::from_bytes(&public_bytes, &secret_bytes, level).expect("construct keypair");

    let pair = MlDsaKeypair::new(crypto, level);
    let anchor = pair.anchor();

    let master_id = PrvKeyDataId::new(1);
    let master = MldsaMasterAccount::try_new(
        &wallet,
        Some("bad-master".into()),
        master_id,
        anchor,
        public_bytes,
        level,
        0,
        MasterStatus::Active,
        vec![],
    )
    .await
    .expect("create master");

    master.unlock_with_master_keypair(pair).await.expect("unlock");

    let sig = master.sign_delegation_hash(b"hello").await.expect("sign");
    assert!(!sig.as_bytes().is_empty(), "signature must be non-empty");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn anchor_corrected_even_if_payload_anchor_wrong() {
    let wallet = setup_wallet().await;
    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let (seed_bytes, _pair, anchor_bytes) = make_seed_and_anchor(MlDsaLevel::Level2);

    // Wrong anchor on purpose
    let wrong_anchor = [9u8; 32];
    let seed_cipher = encrypt_xchacha20poly1305(&seed_bytes, &wallet_secret).expect("encrypt seed");
    let payload =
        MlDsaMasterPayload::new(MlDsaLevel::Level2, kaspa_wallet_keys::keypair_mldsa::MasterAnchor::new(wrong_anchor), seed_cipher);
    let prv = PrvKeyData::try_new_mldsa_master(payload).expect("prv");
    let prv_id = prv.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv).await.expect("store prv");

    let account = wallet
        .create_account_mldsa_master(&wallet_secret, prv_id, MlDsaLevel::Level2, Some("master-acc-bad".into()))
        .await
        .expect("create account");

    let guard = wallet.guard();
    let guard = guard.lock().await;
    let loaded = wallet.get_account_by_id(account.id(), &guard).await.expect("get account").expect("account missing");
    drop(guard);
    let master = loaded.clone().downcast_arc::<MldsaMasterAccount>().expect("downcast master");

    // Кошелёк должен держать консистентный anchor (не злоупотребляя содержимым payload)
    assert_ne!(master.anchor().as_bytes(), &wrong_anchor);
    assert_eq!(master.anchor().as_bytes(), &anchor_bytes);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn apply_delegation_relinks_account_when_record_already_present() {
    let store = Wallet::resident_store().expect("resident store");
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 17);
    let wallet = Arc::new(Wallet::try_with_rpc(None, store, Some(network_id)).expect("wallet"));
    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let args = WalletCreateArgs::new(Some("delegation-apply-test".into()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), args).await.expect("wallet create");

    // Create MLDSA master account
    let (seed_bytes, master_key, anchor_bytes) = make_seed_and_anchor(MlDsaLevel::Level2);
    let seed_cipher = encrypt_xchacha20poly1305(&seed_bytes, &wallet_secret).expect("encrypt seed");
    let payload =
        MlDsaMasterPayload::new(MlDsaLevel::Level2, kaspa_wallet_keys::keypair_mldsa::MasterAnchor::new(anchor_bytes), seed_cipher);
    let prv_master = PrvKeyData::try_new_mldsa_master(payload).expect("prv master");
    let prv_master_id = prv_master.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv_master).await.expect("store master prv");
    let master = wallet
        .create_account_mldsa_master(&wallet_secret, prv_master_id, MlDsaLevel::Level2, Some("master".into()))
        .await
        .expect("create master");
    let master_id = *master.id();

    // Create Stealth account
    let mnemonic = Mnemonic::random(WordCount::Words12, Language::English).expect("mnemonic");
    let prv = PrvKeyData::try_new_from_mnemonic(mnemonic, None, EncryptionKind::XChaCha20Poly1305).expect("prv key data");
    let prv_id = prv.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv).await.expect("store prv");
    let account =
        wallet.create_account_stealth(&wallet_secret, prv_id, None, Some("stealth".into()), Some(0)).await.expect("create stealth");
    let account_id = *account.id();

    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[master_id, account_id]), &guard).await.expect("activate accounts");
    drop(guard);

    let guard = wallet.guard();
    let guard = guard.lock().await;
    let loaded = wallet.get_account_by_id(&account_id, &guard).await.expect("get account").expect("account missing");
    drop(guard);
    let stealth = loaded.downcast_arc::<StealthAccount>().expect("downcast stealth");

    let spend_pubkey = stealth.spend_pubkey().expect("spend pubkey").serialize();
    let scan_pubkey = stealth.scan_pubkey().expect("scan pubkey").serialize();

    let header = DelegationRecordHeaderV1 {
        version: 1,
        level: MlDsaLevel::Level2 as u8,
        anchor: anchor_bytes,
        account_id,
        spend_pubkey,
        scan_pubkey,
        valid_from_daa: 0,
        valid_until_daa: Some(100),
        nonce: 1,
        status: DelegationStatus::Active,
    };

    let mut request = MasterDelegationRequestBodyV1 {
        version: 1,
        master_anchor: anchor_bytes,
        master_level: MlDsaLevel::Level2 as u8,
        network_id,
        delegations: vec![header.clone()],
        created_at_unixtime: 1_730_000_000,
        request_id: [0u8; 32],
    };
    let request_id = calc_request_id(&request).expect("calc request id");
    request.request_id = request_id;

    let mut record = DelegationRecordV1::from(&header);
    sign_with_master(&master_key, &mut record).expect("sign record");
    let response = MasterDelegationResponseBodyV1 {
        version: 1,
        master_anchor: anchor_bytes,
        master_level: MlDsaLevel::Level2 as u8,
        request_id,
        delegations: vec![record.clone()],
    };

    // Emulate partial apply: record exists in store, but account has no link to it.
    let existing_id = wallet.delegation_store().upsert(record, Some(request_id)).expect("upsert record");
    assert_eq!(stealth.master_anchor(), None);
    assert_eq!(stealth.delegation_id(), None);

    wallet.apply_master_delegation_response(&wallet_secret, request, response, false).await.expect("apply");

    assert_eq!(stealth.master_anchor(), Some(anchor_bytes));
    assert_eq!(stealth.delegation_id(), Some(existing_id));
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn link_delegation_requires_current_daa_when_valid_for_is_set() {
    let store = Wallet::resident_store().expect("resident store");
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 17);
    let wallet = Arc::new(Wallet::try_with_rpc(None, store, Some(network_id)).expect("wallet"));
    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let args = WalletCreateArgs::new(Some("delegation-requires-daa".into()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), args).await.expect("wallet create");

    // Create MLDSA master account (and activate it so it's discoverable by anchor)
    let (seed_bytes, _master_key, anchor_bytes) = make_seed_and_anchor(MlDsaLevel::Level2);
    let seed_cipher = encrypt_xchacha20poly1305(&seed_bytes, &wallet_secret).expect("encrypt seed");
    let payload =
        MlDsaMasterPayload::new(MlDsaLevel::Level2, kaspa_wallet_keys::keypair_mldsa::MasterAnchor::new(anchor_bytes), seed_cipher);
    let prv_master = PrvKeyData::try_new_mldsa_master(payload).expect("prv master");
    let prv_master_id = prv_master.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv_master).await.expect("store master prv");
    let master = wallet
        .create_account_mldsa_master(&wallet_secret, prv_master_id, MlDsaLevel::Level2, Some("master".into()))
        .await
        .expect("create master");
    let master_id = *master.id();

    // Unlock the ACTIVE master account instance (link_stealth_to_master signs delegations)
    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[master_id]), &guard).await.expect("activate master");
    let loaded = wallet.get_account_by_id(&master_id, &guard).await.expect("get master").expect("master missing");
    drop(guard);
    let master = loaded.downcast_arc::<MldsaMasterAccount>().expect("downcast master");
    let master_seed = MasterSeed::from_slice(&seed_bytes).expect("seed len");
    master.unlock_with_master_seed(&master_seed, MlDsaLevel::Level2).await.expect("unlock master");

    // Create stealth account (activated so store updates work)
    let mnemonic = Mnemonic::random(WordCount::Words12, Language::English).expect("mnemonic");
    let prv = PrvKeyData::try_new_from_mnemonic(mnemonic, None, EncryptionKind::XChaCha20Poly1305).expect("prv key data");
    let prv_id = prv.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv).await.expect("store prv");
    let stealth =
        wallet.create_account_stealth(&wallet_secret, prv_id, None, Some("stealth".into()), Some(0)).await.expect("create stealth");
    let stealth_id = *stealth.id();

    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[stealth_id]), &guard).await.expect("activate stealth");
    drop(guard);

    // Sanity: without RPC connection we should not have a DAA score.
    assert!(wallet.current_daa_score().is_none(), "test requires disconnected wallet (no DAA score)");

    // Should fail deterministically: valid_for_daa needs current DAA score to compute absolute valid_until.
    let err =
        wallet.link_stealth_to_master(&wallet_secret, stealth_id, anchor_bytes, 0, Some(10_000)).await.expect_err("expected error");
    assert!(err.to_string().contains("valid_for_daa requires current DAA score"));
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn link_delegation_requires_current_daa_when_window_is_set() {
    let store = Wallet::resident_store().expect("resident store");
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 17);
    let wallet = Arc::new(Wallet::try_with_rpc(None, store, Some(network_id)).expect("wallet"));
    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let args =
        WalletCreateArgs::new(Some("delegation-window-requires-daa".into()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), args).await.expect("wallet create");

    // Create MLDSA master account (and activate it so it's discoverable by anchor)
    let (seed_bytes, _master_key, anchor_bytes) = make_seed_and_anchor(MlDsaLevel::Level2);
    let seed_cipher = encrypt_xchacha20poly1305(&seed_bytes, &wallet_secret).expect("encrypt seed");
    let payload =
        MlDsaMasterPayload::new(MlDsaLevel::Level2, kaspa_wallet_keys::keypair_mldsa::MasterAnchor::new(anchor_bytes), seed_cipher);
    let prv_master = PrvKeyData::try_new_mldsa_master(payload).expect("prv master");
    let prv_master_id = prv_master.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv_master).await.expect("store master prv");
    let master = wallet
        .create_account_mldsa_master(&wallet_secret, prv_master_id, MlDsaLevel::Level2, Some("master".into()))
        .await
        .expect("create master");
    let master_id = *master.id();

    // Unlock the ACTIVE master account instance (link_stealth_to_master signs delegations)
    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[master_id]), &guard).await.expect("activate master");
    let loaded = wallet.get_account_by_id(&master_id, &guard).await.expect("get master").expect("master missing");
    drop(guard);
    let master = loaded.downcast_arc::<MldsaMasterAccount>().expect("downcast master");
    let master_seed = MasterSeed::from_slice(&seed_bytes).expect("seed len");
    master.unlock_with_master_seed(&master_seed, MlDsaLevel::Level2).await.expect("unlock master");

    // Create stealth account (activated so store updates work)
    let mnemonic = Mnemonic::random(WordCount::Words12, Language::English).expect("mnemonic");
    let prv = PrvKeyData::try_new_from_mnemonic(mnemonic, None, EncryptionKind::XChaCha20Poly1305).expect("prv key data");
    let prv_id = prv.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv).await.expect("store prv");
    let stealth =
        wallet.create_account_stealth(&wallet_secret, prv_id, None, Some("stealth".into()), Some(0)).await.expect("create stealth");
    let stealth_id = *stealth.id();

    let guard = wallet.guard();
    let guard = guard.lock().await;
    wallet.activate_accounts(Some(&[stealth_id]), &guard).await.expect("activate stealth");
    drop(guard);

    // Sanity: without RPC connection we should not have a DAA score.
    assert!(wallet.current_daa_score().is_none(), "test requires disconnected wallet (no DAA score)");

    // Should fail deterministically: window_daa needs current DAA score to compute absolute valid_from.
    let err = wallet.link_stealth_to_master(&wallet_secret, stealth_id, anchor_bytes, 10, None).await.expect_err("expected error");
    assert!(err.to_string().contains("window_daa requires current DAA score"));
}
