use crate::imports::*;
use crate::result::Result;
use crate::tests::RpcCoreMock;
use crate::tx::generator::test::*;
use crate::tx::*;
use crate::utils::*;
use crate::utxo::*;
use kaspa_addresses::Version;
use kaspa_rpc_core::message::{StealthUtxosChangedNotification, UtxosChangedNotification};
use kaspa_rpc_core::{RpcFeeEstimate, RpcFeerateBucket, RpcTransactionOutpoint, RpcUtxoEntry, RpcUtxosByAddressesEntry};
use std::time::Duration;

#[tokio::test]
async fn test_utxo_subsystem_bootstrap() -> Result<()> {
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
    let rpc_api_mock = Arc::new(RpcCoreMock::new());
    let processor = UtxoProcessor::new(Some(rpc_api_mock.clone().into()), Some(network_id), None, None);
    let _context = UtxoContext::new(&processor, UtxoContextBinding::default());

    processor.mock_set_connected(true);
    processor.handle_daa_score_change(1).await?;
    // println!("daa score: {:?}", processor.current_daa_score());
    // context.register_addresses(&[output_address(network_id.into())]).await?;
    Ok(())
}

#[tokio::test]
async fn utxo_processor_does_not_panic_on_notifications_while_disconnected() -> Result<()> {
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
    let rpc_api_mock = Arc::new(RpcCoreMock::new());
    let processor = UtxoProcessor::new(Some(rpc_api_mock.clone().into()), Some(network_id), None, None);

    // Processor starts disconnected by default. These calls must be no-ops (no panic).
    processor.handle_utxo_changed(UtxosChangedNotification::default()).await?;
    processor.handle_stealth_utxo_changed(StealthUtxosChangedNotification::default()).await?;

    Ok(())
}

#[tokio::test]
async fn utxo_context_revive_does_not_insert_when_utxo_missing_from_stasis() -> Result<()> {
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
    let rpc_api_mock = Arc::new(RpcCoreMock::new());
    let processor = UtxoProcessor::new(Some(rpc_api_mock.clone().into()), Some(network_id), None, None);

    // Keep at least one receiver alive so notify() doesn't fail.
    let _events = processor.multiplexer().channel();

    let context = UtxoContext::new(&processor, UtxoContextBinding::default());
    assert_eq!(context.pending_utxo_size(), 0);

    let address = Address::new(Prefix::Testnet, Version::PubKey, &[1u8; 32]);
    let entry = RpcUtxosByAddressesEntry {
        address: Some(address),
        outpoint: RpcTransactionOutpoint { transaction_id: TransactionId::from_bytes([7u8; 32]), index: 0 },
        utxo_entry: RpcUtxoEntry::new(100, ScriptPublicKey::from_vec(0u16, vec![]), 1, true),
    };
    let utxo_ref: UtxoEntryReference = entry.into();

    context.revive(vec![utxo_ref]).await?;
    assert_eq!(context.pending_utxo_size(), 0);

    Ok(())
}

#[tokio::test]
async fn utxo_context_revive_moves_utxo_from_stasis_to_pending() -> Result<()> {
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
    let rpc_api_mock = Arc::new(RpcCoreMock::new());
    let processor = UtxoProcessor::new(Some(rpc_api_mock.clone().into()), Some(network_id), None, None);

    // Keep at least one receiver alive so notify() doesn't fail.
    let _events = processor.multiplexer().channel();

    let context = UtxoContext::new(&processor, UtxoContextBinding::default());

    let block_daa_score: u64 = 1;
    let params = processor.network_params()?;
    let stasis_period = params.coinbase_transaction_stasis_period_daa();
    let current_daa_score_stasis =
        if stasis_period == 0 { block_daa_score.saturating_sub(1) } else { block_daa_score + stasis_period - 1 };

    let address = Address::new(Prefix::Testnet, Version::PubKey, &[2u8; 32]);
    let entry = RpcUtxosByAddressesEntry {
        address: Some(address),
        outpoint: RpcTransactionOutpoint { transaction_id: TransactionId::from_bytes([9u8; 32]), index: 0 },
        utxo_entry: RpcUtxoEntry::new(100, ScriptPublicKey::from_vec(0u16, vec![]), block_daa_score, true),
    };
    let utxo_ref: UtxoEntryReference = entry.into();

    // Insert as coinbase in stasis.
    context.insert(utxo_ref.clone(), current_daa_score_stasis, false).await?;
    assert_eq!(context.pending_utxo_size(), 0);
    assert_eq!(context.calculate_balance().await.stasis_utxo_count, 1);
    assert_eq!(processor.stasis().len(), 1);

    // Advance DAA score to stasis boundary so it becomes pending.
    let current_daa_score = block_daa_score + stasis_period;
    processor.handle_pending(current_daa_score).await?;

    assert_eq!(context.pending_utxo_size(), 1);
    let balance = context.calculate_balance().await;
    assert_eq!(balance.pending_utxo_count, 1);
    assert_eq!(balance.stasis_utxo_count, 0);
    assert_eq!(processor.stasis().len(), 0);
    assert_eq!(processor.pending().len(), 1);

    Ok(())
}

#[tokio::test]
async fn fee_rate_poller_does_not_panic_on_empty_buckets() -> Result<()> {
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
    let rpc_api_mock = Arc::new(RpcCoreMock::new());
    rpc_api_mock.mock_set_fee_estimate(RpcFeeEstimate {
        priority_bucket: RpcFeerateBucket { feerate: 1.0, estimated_seconds: 0.1 },
        normal_buckets: vec![],
        low_buckets: vec![],
    });

    let processor = UtxoProcessor::new(Some(rpc_api_mock.clone().into()), Some(network_id), None, None);

    processor.start_fee_rate_poller(Duration::from_millis(1)).await?;
    tokio::time::sleep(Duration::from_millis(10)).await;
    processor.stop_fee_rate_poller().await?;

    Ok(())
}

#[test]
fn test_utxo_generator_empty_utxo_noop() -> Result<()> {
    let network_id = NetworkId::with_suffix(NetworkType::Testnet, 10);
    let output_address = output_address(network_id.into());

    let payment_output = PaymentOutput::new(output_address, kaspa_to_sompi(2.0));
    let generator =
        make_generator(network_id, &[10.0], &[], None, Fees::SenderPays(0), change_address, payment_output.into()).unwrap();
    let _tx = generator.generate_transaction().unwrap();
    // println!("tx: {:?}", tx);
    // assert!(tx.is_none());
    Ok(())
}
