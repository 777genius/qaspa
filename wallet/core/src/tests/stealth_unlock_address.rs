use crate::api::traits::WalletApi;
use crate::encryption::EncryptionKind;
use crate::storage::keydata::PrvKeyData;
use crate::wallet::Wallet;
use crate::wallet::args::WalletCreateArgs;
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_bip32::{Language, Mnemonic, WordCount};
use kaspa_consensus_core::network::{NetworkId, NetworkType};
use kaspa_wallet_keys::secret::Secret;
use std::sync::Arc;

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn stealth_account_unlock_returns_kaspa_address_string() {
    let store = Wallet::resident_store().expect("resident store");
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 17);
    let wallet = Arc::new(Wallet::try_with_rpc(None, store, Some(network_id)).expect("wallet"));

    let wallet_secret = Secret::new(b"test-wallet-secret".to_vec());
    let args = WalletCreateArgs::new(Some("stealth-unlock-test".into()), None, EncryptionKind::XChaCha20Poly1305, None, true);
    wallet.clone().wallet_create(wallet_secret.clone(), args).await.expect("wallet create");

    let mnemonic = Mnemonic::random(WordCount::Words12, Language::English).expect("mnemonic");
    let prv = PrvKeyData::try_new_from_mnemonic(mnemonic, None, EncryptionKind::XChaCha20Poly1305).expect("prv key data");
    let prv_id = prv.id;
    wallet.store().as_prv_key_data_store().expect("prv store").store(&wallet_secret, prv).await.expect("store prv");

    let account = wallet
        .create_account_stealth(&wallet_secret, prv_id, None, Some("stealth".into()), Some(0))
        .await
        .expect("create stealth account");
    let account_id = *account.id();

    let addr_str = wallet.stealth_account_unlock(&account_id, &wallet_secret, None).await.expect("unlock");
    let addr: Address = addr_str.as_str().try_into().expect("parse address");

    assert_eq!(addr.version, Version::Stealth);
    assert_eq!(addr.prefix, Prefix::StealthTestnet);
}
