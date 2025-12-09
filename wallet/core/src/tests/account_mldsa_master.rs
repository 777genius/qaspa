use crate::account::variants::mldsa_master::{MasterSignDomain, MldsaMasterAccount};
use crate::api::traits::WalletApi;
use crate::encryption::{encrypt_xchacha20poly1305, EncryptionKind};
use crate::storage::keydata::data::MlDsaMasterPayload;
use crate::storage::keydata::PrvKeyData;
use crate::wallet::args::WalletCreateArgs;
use crate::wallet::Wallet;
use kaspa_mldsa::{MasterSeed, MlDsaLevel};
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
    let payload = MlDsaMasterPayload::new(MlDsaLevel::Level2, kaspa_wallet_keys::keypair_mldsa::MasterAnchor::new(anchor_bytes), seed_cipher);
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

