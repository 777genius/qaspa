use crate::common::utils::wait_for;
use crate::stealth_flow::StealthTestEnv;
use async_trait::async_trait;
use kaspa_bip32::{Language, Mnemonic, WordCount};
use kaspa_mldsa::{MasterSeed, MlDsaLevel};
use kaspa_rpc_core::{
    api::rpc::RpcApi, GetMempoolEntryRequest, ListMldsaDelegationsRequest, RegisterMldsaAnchorRequest, RpcDelegationRecord, RpcError,
    RpcResult,
};
use kaspa_rpc_service::service::DelegationProvider;
use kaspa_utils::hex::ToHex;
use kaspa_wallet_core::account::variants::mldsa_master::MldsaMasterAccount;
use kaspa_wallet_core::api::traits::WalletApi;
use kaspa_wallet_core::{
    account::delegation::DelegationStatus, account::Account, deterministic::AccountId, storage::keydata::PrvKeyDataVariantKind,
    wallet::args::PrvKeyDataCreateArgs, wallet::Wallet,
};
use kaspa_wallet_core::events::Events;
use kaspa_wallet_core::storage::ephemeral_keys::{EphemeralKeyStatus, OrphanReason};
use kaspa_wallet_keys::secret::Secret;
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::{oneshot, Mutex};

struct WalletDelegationProvider {
    wallet: Arc<Wallet>,
}

impl WalletDelegationProvider {
    fn to_rpc(record: &kaspa_wallet_core::account::delegation::DelegationRecordV1) -> RpcDelegationRecord {
        let status = match record.status {
            DelegationStatus::Active => "active".to_string(),
            DelegationStatus::Revoked { revoked_daa } => format!("revoked:{revoked_daa}"),
            DelegationStatus::Expired { expired_daa } => format!("expired:{expired_daa}"),
        };

        RpcDelegationRecord {
            anchor: record.anchor,
            account_id: record.account_id.to_hex().into_bytes(),
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
        Ok(list.iter().map(|(_, rec)| Self::to_rpc(rec)).collect())
    }

    async fn has_masters(&self) -> RpcResult<bool> {
        let anchors = self.wallet.master_anchor_infos().await.unwrap_or_default();
        Ok(!anchors.is_empty())
    }
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

    // Mine the spend so state is persisted
    env.mine_blocks(1).await;

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
    let is_orphaned = matches!(
        status,
        Some(EphemeralKeyStatus::Orphaned { reason: OrphanReason::DelegationExpired })
    );
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
