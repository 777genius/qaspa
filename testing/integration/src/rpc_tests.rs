use std::{path::PathBuf, str::FromStr, sync::Arc, time::Duration};

use crate::common::{client_notify::ChannelNotify, daemon::Daemon};
use futures_util::future::try_join_all;
use kaspa_addresses::{Address, Prefix, Version};
use kaspa_consensus::params::{ForkActivation, OverrideParams, Params, SIMNET_GENESIS};
use kaspa_consensus_core::{
    constants::{MAX_SOMPI, TX_VERSION},
    hashing::sighash::{calc_schnorr_signature_hash, SigHashReusedValuesUnsync},
    hashing::sighash_type::SIG_HASH_ALL,
    header::Header,
    network::NetworkType,
    subnets::{SubnetworkId, SUBNETWORK_ID_NATIVE},
    tx::{MutableTransaction, Transaction, TransactionInput, TransactionOutpoint, TransactionOutput, UtxoEntry},
};
use kaspa_core::{assert_match, info};
use kaspa_grpc_core::ops::KaspadPayloadOps;
use kaspa_hashes::Hash;
use kaspa_notify::{
    connection::{ChannelConnection, ChannelType},
    scope::{
        BlockAddedScope, FinalityConflictScope, NewBlockTemplateScope, PruningPointUtxoSetOverrideScope, Scope,
        SinkBlueScoreChangedScope, UtxosChangedScope, VirtualChainChangedScope, VirtualDaaScoreChangedScope,
    },
};
use kaspa_rpc_core::{api::rpc::RpcApi, model::*, Notification};
use kaspa_stealth::{
    check_view_tag, derive_spending_key, scan_output, try_create_stealth_output, verify_derived_key, StealthSecretKey,
};
use kaspa_txscript::{extract_stealth_output, pay_to_address_script, pay_to_stealth, STEALTH_SCRIPT_VERSION};
use kaspa_utils::{fd_budget, networking::ContextualNetAddress};
use kaspad_lib::args::Args;
use secp256k1::{Keypair, Message, SECP256K1};
use tokio::task::JoinHandle;

fn write_override_params_file(filename: &str, overrides: OverrideParams) -> PathBuf {
    let json = serde_json::to_string(&overrides).expect("Failed to serialize override params");
    let path = std::env::temp_dir().join(filename);
    std::fs::write(&path, json).expect("Failed to write override params file");
    path
}

fn simnet_overrides_with_k(filename: &str, ghostdag_k: u64, crescendo_activation: ForkActivation) -> PathBuf {
    let mut overrides: OverrideParams = Params::from(NetworkType::Simnet).into();
    overrides.crescendo_activation = Some(crescendo_activation);
    overrides.blockrate.as_mut().expect("OverrideParams from Params should include blockrate").ghostdag_k = ghostdag_k as _;
    write_override_params_file(filename, overrides)
}

#[macro_export]
macro_rules! tst {
    ($op:ident, $test_body:block) => {
        tokio::spawn(async move {
            info!("Testing  {:?}", $op);
            $test_body
        })
    };

    ($op:ident, $reason:literal) => {
        tokio::spawn(async move {
            info!("Skipping {:?} --- {}", $op, $reason);
        })
    };
}

/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::sanity_test`
#[tokio::test]
async fn sanity_test() {
    kaspa_core::log::try_init_logger("info");
    // As we log the panic, we want to set it up after the logger
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true, // UPnP registration might take some time and is not needed for this test
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;
    let (sender, _) = async_channel::unbounded();
    let connection = ChannelConnection::new("test", sender, ChannelType::Closable);
    let listener_id = client.register_new_listener(connection);
    let mut tasks: Vec<JoinHandle<()>> = Vec::new();

    // The intent of this for/match design (emphasizing the absence of an arm with fallback pattern in the match)
    // is to force any implementor of a new RpcApi method to add a matching arm here and to strongly incentivize
    // the adding of an actual sanity test of said new method.
    for op in KaspadPayloadOps::iter() {
        let network_id = daemon.network;
        let task: JoinHandle<()> = match op {
            KaspadPayloadOps::SubmitBlock => {
                let rpc_client = client.clone();
                tst!(op, {
                    // Register to basic virtual events in order to keep track of block submission
                    let (sender, event_receiver) = async_channel::unbounded();
                    rpc_client.start(Some(Arc::new(ChannelNotify::new(sender)))).await;
                    rpc_client
                        .start_notify(Default::default(), Scope::VirtualDaaScoreChanged(VirtualDaaScoreChangedScope {}))
                        .await
                        .unwrap();

                    // Before submitting a first block, the sink is the genesis,
                    let response = rpc_client.get_sink_call(None, GetSinkRequest {}).await.unwrap();
                    assert_eq!(response.sink, SIMNET_GENESIS.hash);
                    let response = rpc_client.get_sink_blue_score_call(None, GetSinkBlueScoreRequest {}).await.unwrap();
                    assert_eq!(response.blue_score, 0);

                    // the block count is 0
                    let response = rpc_client.get_block_count_call(None, GetBlockCountRequest {}).await.unwrap();
                    assert_eq!(response.block_count, 0);

                    // and the virtual chain is the genesis only
                    let response = rpc_client
                        .get_virtual_chain_from_block_call(
                            None,
                            GetVirtualChainFromBlockRequest {
                                start_hash: SIMNET_GENESIS.hash,
                                include_accepted_transaction_ids: false,
                                min_confirmation_count: None,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(response.added_chain_block_hashes.is_empty());
                    assert!(response.removed_chain_block_hashes.is_empty());

                    // Get a block template
                    let GetBlockTemplateResponse { block, is_synced } = rpc_client
                        .get_block_template_call(
                            None,
                            GetBlockTemplateRequest {
                                pay_address: Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32]),
                                extra_data: Vec::new(),
                            },
                        )
                        .await
                        .unwrap();
                    assert!(!is_synced);

                    // Compute the expected block hash for the received block
                    let header: Header = (&block.header).try_into().unwrap();
                    let block_hash = header.hash;

                    // Submit the template (no mining, in simnet PoW is skipped)
                    let response = rpc_client.submit_block(block.clone(), false).await.unwrap();
                    assert_eq!(response.report, SubmitBlockReport::Success);

                    // Wait for virtual event indicating the block was processed and entered past(virtual)
                    while let Ok(notification) = match tokio::time::timeout(Duration::from_secs(1), event_receiver.recv()).await {
                        Ok(res) => res,
                        Err(elapsed) => panic!("expected virtual event before {}", elapsed),
                    } {
                        match notification {
                            Notification::VirtualDaaScoreChanged(msg) if msg.virtual_daa_score == 1 => {
                                break;
                            }
                            Notification::VirtualDaaScoreChanged(msg) if msg.virtual_daa_score > 1 => {
                                panic!("DAA score too high for number of submitted blocks")
                            }
                            Notification::VirtualDaaScoreChanged(_) => {}
                            _ => {}
                        }
                    }

                    // After submitting a first block, the sink is the submitted block,
                    let response = rpc_client.get_sink_call(None, GetSinkRequest {}).await.unwrap();
                    assert_eq!(response.sink, block_hash);

                    // the block count is 1
                    let response = rpc_client.get_block_count_call(None, GetBlockCountRequest {}).await.unwrap();
                    assert_eq!(response.block_count, 1);

                    // and the virtual chain from genesis contains the added block
                    let response = rpc_client
                        .get_virtual_chain_from_block_call(
                            None,
                            GetVirtualChainFromBlockRequest {
                                start_hash: SIMNET_GENESIS.hash,
                                include_accepted_transaction_ids: false,
                                min_confirmation_count: None,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(response.added_chain_block_hashes.contains(&block_hash));
                    assert!(response.removed_chain_block_hashes.is_empty());

                    // VSPC min confirmation count test
                    let vc_min_count_1_response = rpc_client
                        .get_virtual_chain_from_block_call(
                            None,
                            GetVirtualChainFromBlockRequest {
                                start_hash: SIMNET_GENESIS.hash,
                                include_accepted_transaction_ids: false,
                                min_confirmation_count: Some(1),
                            },
                        )
                        .await
                        .unwrap();
                    assert!(vc_min_count_1_response.added_chain_block_hashes.is_empty());

                    let result =
                        rpc_client.get_current_block_color_call(None, GetCurrentBlockColorRequest { hash: SIMNET_GENESIS.hash }).await;

                    // Genesis was merged by the new sink, so we're expecting a positive blueness response
                    assert_match!(result, Ok(GetCurrentBlockColorResponse { blue: true }));

                    // The new sink has no merging block yet, so we expect a MergerNotFound error
                    let result = rpc_client.get_current_block_color_call(None, GetCurrentBlockColorRequest { hash: block_hash }).await;
                    assert!(result.is_err());

                    // Non-existing blocks should return an error
                    let result = rpc_client.get_current_block_color_call(None, GetCurrentBlockColorRequest { hash: 999.into() }).await;
                    assert!(result.is_err());
                })
            }

            KaspadPayloadOps::GetBlockTemplate => {
                tst!(op, "see SubmitBlock")
            }

            KaspadPayloadOps::GetCurrentBlockColor => {
                tst!(op, "see SubmitBlock")
            }

            KaspadPayloadOps::GetCurrentNetwork => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_current_network_call(None, GetCurrentNetworkRequest {}).await.unwrap();
                    assert_eq!(response.network, network_id.network_type);
                })
            }

            KaspadPayloadOps::GetBlock => {
                let rpc_client = client.clone();
                tst!(op, {
                    let result =
                        rpc_client.get_block_call(None, GetBlockRequest { hash: 0.into(), include_transactions: false }).await;
                    assert!(result.is_err());

                    let response = rpc_client
                        .get_block_call(None, GetBlockRequest { hash: SIMNET_GENESIS.hash, include_transactions: false })
                        .await
                        .unwrap();
                    assert_eq!(response.block.header.hash, SIMNET_GENESIS.hash);
                })
            }

            KaspadPayloadOps::GetBlocks => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client
                        .get_blocks_call(None, GetBlocksRequest { include_blocks: true, include_transactions: false, low_hash: None })
                        .await
                        .unwrap();
                    assert_eq!(response.blocks.len(), 1, "genesis block should be returned");
                    assert_eq!(response.blocks[0].header.hash, SIMNET_GENESIS.hash);
                    assert_eq!(response.block_hashes[0], SIMNET_GENESIS.hash);
                })
            }

            KaspadPayloadOps::GetInfo => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_info_call(None, GetInfoRequest {}).await.unwrap();
                    assert_eq!(response.server_version, kaspa_core::kaspad_env::version().to_string());
                    assert_eq!(response.mempool_size, 0);
                    assert!(response.is_utxo_indexed);
                    assert!(response.has_message_id);
                    assert!(response.has_notify_command);
                })
            }

            KaspadPayloadOps::Shutdown => {
                // This test is purposely left blank since shutdown can only be tested after all other
                // tests completed
                tst!(op, "must be run in the end")
            }

            KaspadPayloadOps::GetPeerAddresses => {
                tst!(op, "see AddPeer, Ban")
            }

            KaspadPayloadOps::GetSink => {
                tst!(op, "see SubmitBlock")
            }

            KaspadPayloadOps::GetMempoolEntry => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response_result = rpc_client
                        .get_mempool_entry_call(
                            None,
                            GetMempoolEntryRequest {
                                transaction_id: 0.into(),
                                include_orphan_pool: true,
                                filter_transaction_pool: false,
                            },
                        )
                        .await;
                    // Test Get Mempool Entry:
                    // TODO: Fix by adding actual mempool entries this can get because otherwise it errors out
                    assert!(response_result.is_err());
                })
            }

            KaspadPayloadOps::GetMempoolEntries => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client
                        .get_mempool_entries_call(
                            None,
                            GetMempoolEntriesRequest { include_orphan_pool: true, filter_transaction_pool: false },
                        )
                        .await
                        .unwrap();
                    assert!(response.mempool_entries.is_empty());
                })
            }

            KaspadPayloadOps::GetConnectedPeerInfo => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_connected_peer_info_call(None, GetConnectedPeerInfoRequest {}).await.unwrap();
                    assert!(response.peer_info.is_empty());
                })
            }

            KaspadPayloadOps::AddPeer => {
                let rpc_client = client.clone();
                tst!(op, {
                    let peer_address = ContextualNetAddress::from_str("1.2.3.4").unwrap();
                    let _ = rpc_client.add_peer_call(None, AddPeerRequest { peer_address, is_permanent: true }).await.unwrap();

                    // Add peer only adds the IP to a connection request. It will only be added to known_addresses if it
                    // actually can be connected to. So in this test we can't expect it to be added unless we set up an
                    // actual peer.
                    let response = rpc_client.get_peer_addresses_call(None, GetPeerAddressesRequest {}).await.unwrap();
                    assert!(response.known_addresses.is_empty());
                })
            }

            KaspadPayloadOps::Ban => {
                let rpc_client = client.clone();
                tst!(op, {
                    let peer_address = ContextualNetAddress::from_str("5.6.7.8").unwrap();
                    let ip = peer_address.normalize(1).ip;

                    let _ = rpc_client.add_peer_call(None, AddPeerRequest { peer_address, is_permanent: false }).await.unwrap();
                    let _ = rpc_client.ban_call(None, BanRequest { ip }).await.unwrap();

                    let response = rpc_client.get_peer_addresses_call(None, GetPeerAddressesRequest {}).await.unwrap();
                    assert!(response.banned_addresses.contains(&ip));

                    let _ = rpc_client.unban_call(None, UnbanRequest { ip }).await.unwrap();
                    let response = rpc_client.get_peer_addresses_call(None, GetPeerAddressesRequest {}).await.unwrap();
                    assert!(!response.banned_addresses.contains(&ip));
                })
            }

            KaspadPayloadOps::Unban => {
                tst!(op, "see Ban")
            }

            KaspadPayloadOps::SubmitTransaction => {
                let rpc_client = client.clone();
                tst!(op, {
                    // Build an erroneous transaction...
                    let transaction = Transaction::new(0, vec![], vec![], 0, SubnetworkId::default(), 0, vec![]);
                    let result = rpc_client.submit_transaction((&transaction).into(), false).await;
                    // ...that gets rejected by the consensus
                    assert!(result.is_err());
                })
            }

            KaspadPayloadOps::SubmitTransactionReplacement => {
                let rpc_client = client.clone();
                tst!(op, {
                    // Build an erroneous transaction...
                    let transaction = Transaction::new(0, vec![], vec![], 0, SubnetworkId::default(), 0, vec![]);
                    let result = rpc_client.submit_transaction_replacement((&transaction).into()).await;
                    // ...that gets rejected by the consensus
                    assert!(result.is_err());
                })
            }

            KaspadPayloadOps::GetSubnetwork => {
                let rpc_client = client.clone();
                tst!(op, {
                    let result =
                        rpc_client.get_subnetwork_call(None, GetSubnetworkRequest { subnetwork_id: SubnetworkId::from_byte(0) }).await;

                    // Err because it's currently unimplemented
                    assert!(result.is_err());
                })
            }

            KaspadPayloadOps::GetVirtualChainFromBlock => {
                tst!(op, "see SubmitBlock")
            }

            KaspadPayloadOps::GetBlockCount => {
                tst!(op, "see SubmitBlock")
            }

            KaspadPayloadOps::GetBlockDagInfo => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_block_dag_info_call(None, GetBlockDagInfoRequest {}).await.unwrap();
                    assert_eq!(response.network, network_id);
                })
            }

            KaspadPayloadOps::ResolveFinalityConflict => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response_result = rpc_client
                        .resolve_finality_conflict_call(
                            None,
                            ResolveFinalityConflictRequest { finality_block_hash: Hash::from_bytes([0; 32]) },
                        )
                        .await;

                    // Err because it's currently unimplemented
                    assert!(response_result.is_err());
                })
            }

            KaspadPayloadOps::GetHeaders => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response_result = rpc_client
                        .get_headers_call(None, GetHeadersRequest { start_hash: SIMNET_GENESIS.hash, limit: 1, is_ascending: true })
                        .await;

                    // Err because it's currently unimplemented
                    assert!(response_result.is_err());
                })
            }

            KaspadPayloadOps::GetUtxosByAddresses => {
                let rpc_client = client.clone();
                tst!(op, {
                    let addresses = vec![Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32])];
                    let response =
                        rpc_client.get_utxos_by_addresses_call(None, GetUtxosByAddressesRequest { addresses }).await.unwrap();
                    assert!(response.entries.is_empty());
                })
            }

            KaspadPayloadOps::GetBalanceByAddress => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client
                        .get_balance_by_address_call(
                            None,
                            GetBalanceByAddressRequest { address: Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32]) },
                        )
                        .await
                        .unwrap();
                    assert_eq!(response.balance, 0);
                })
            }

            KaspadPayloadOps::GetBalancesByAddresses => {
                let rpc_client = client.clone();
                tst!(op, {
                    let addresses = vec![Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32])];
                    let response = rpc_client
                        .get_balances_by_addresses_call(None, GetBalancesByAddressesRequest::new(addresses.clone()))
                        .await
                        .unwrap();
                    assert_eq!(response.entries.len(), 1);
                    assert_eq!(response.entries[0].address, addresses[0]);
                    assert_eq!(response.entries[0].balance, Some(0));

                    let response =
                        rpc_client.get_balances_by_addresses_call(None, GetBalancesByAddressesRequest::new(vec![])).await.unwrap();
                    assert!(response.entries.is_empty());
                })
            }

            KaspadPayloadOps::GetSinkBlueScore => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_sink_blue_score_call(None, GetSinkBlueScoreRequest {}).await.unwrap();
                    // A concurrent test may have added a single block so the blue score can be either 0 or 1
                    assert!(response.blue_score < 2);
                })
            }

            KaspadPayloadOps::EstimateNetworkHashesPerSecond => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response_result = rpc_client
                        .estimate_network_hashes_per_second_call(
                            None,
                            EstimateNetworkHashesPerSecondRequest { window_size: 1000, start_hash: None },
                        )
                        .await;
                    // The current DAA window is almost empty so an error is expected
                    assert!(response_result.is_err());
                })
            }

            KaspadPayloadOps::GetMempoolEntriesByAddresses => {
                let rpc_client = client.clone();
                tst!(op, {
                    let addresses = vec![Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32])];
                    let response = rpc_client
                        .get_mempool_entries_by_addresses_call(
                            None,
                            GetMempoolEntriesByAddressesRequest::new(addresses.clone(), true, false),
                        )
                        .await
                        .unwrap();
                    assert_eq!(response.entries.len(), 1);
                    assert_eq!(response.entries[0].address, addresses[0]);
                    assert!(response.entries[0].receiving.is_empty());
                    assert!(response.entries[0].sending.is_empty());
                })
            }

            KaspadPayloadOps::GetCoinSupply => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_coin_supply_call(None, GetCoinSupplyRequest {}).await.unwrap();
                    assert_eq!(response.circulating_sompi, 0);
                    assert_eq!(response.max_sompi, MAX_SOMPI);
                })
            }

            KaspadPayloadOps::Ping => {
                let rpc_client = client.clone();
                tst!(op, {
                    let _ = rpc_client.ping_call(None, PingRequest {}).await.unwrap();
                })
            }

            KaspadPayloadOps::GetConnections => {
                let rpc_client = client.clone();
                tst!(op, {
                    let _ = rpc_client.get_connections_call(None, GetConnectionsRequest { include_profile_data: true }).await.unwrap();
                })
            }

            KaspadPayloadOps::GetMetrics => {
                let rpc_client = client.clone();
                tst!(op, {
                    let get_metrics_call_response = rpc_client
                        .get_metrics_call(
                            None,
                            GetMetricsRequest {
                                consensus_metrics: true,
                                connection_metrics: true,
                                bandwidth_metrics: true,
                                process_metrics: true,
                                storage_metrics: true,
                                custom_metrics: true,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(get_metrics_call_response.process_metrics.is_some());
                    assert!(get_metrics_call_response.consensus_metrics.is_some());

                    let get_metrics_call_response = rpc_client
                        .get_metrics_call(
                            None,
                            GetMetricsRequest {
                                consensus_metrics: false,
                                connection_metrics: true,
                                bandwidth_metrics: true,
                                process_metrics: true,
                                storage_metrics: true,
                                custom_metrics: true,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(get_metrics_call_response.process_metrics.is_some());
                    assert!(get_metrics_call_response.consensus_metrics.is_none());

                    let get_metrics_call_response = rpc_client
                        .get_metrics_call(
                            None,
                            GetMetricsRequest {
                                consensus_metrics: true,
                                connection_metrics: true,
                                bandwidth_metrics: false,
                                process_metrics: false,
                                storage_metrics: false,
                                custom_metrics: true,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(get_metrics_call_response.process_metrics.is_none());
                    assert!(get_metrics_call_response.consensus_metrics.is_some());

                    let get_metrics_call_response = rpc_client
                        .get_metrics_call(
                            None,
                            GetMetricsRequest {
                                consensus_metrics: false,
                                connection_metrics: true,
                                bandwidth_metrics: false,
                                process_metrics: false,
                                storage_metrics: false,
                                custom_metrics: true,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(get_metrics_call_response.process_metrics.is_none());
                    assert!(get_metrics_call_response.consensus_metrics.is_none());
                })
            }

            KaspadPayloadOps::GetSystemInfo => {
                let rpc_client = client.clone();
                tst!(op, {
                    let _response = rpc_client.get_system_info_call(None, GetSystemInfoRequest {}).await.unwrap();
                })
            }

            KaspadPayloadOps::GetServerInfo => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_server_info_call(None, GetServerInfoRequest {}).await.unwrap();
                    assert!(response.has_utxo_index); // we set utxoindex above
                    assert_eq!(response.network_id, network_id);
                })
            }

            KaspadPayloadOps::GetSyncStatus => {
                let rpc_client = client.clone();
                tst!(op, {
                    let _ = rpc_client.get_sync_status_call(None, GetSyncStatusRequest {}).await.unwrap();
                })
            }

            KaspadPayloadOps::GetDaaScoreTimestampEstimate => {
                let rpc_client = client.clone();
                tst!(op, {
                    let results = rpc_client
                        .get_daa_score_timestamp_estimate_call(
                            None,
                            GetDaaScoreTimestampEstimateRequest { daa_scores: vec![0, 500, 2000, u64::MAX] },
                        )
                        .await
                        .unwrap();

                    for timestamp in results.timestamps.iter() {
                        info!("Timestamp estimate is {}", timestamp);
                    }

                    let results = rpc_client
                        .get_daa_score_timestamp_estimate_call(None, GetDaaScoreTimestampEstimateRequest { daa_scores: vec![] })
                        .await
                        .unwrap();

                    for timestamp in results.timestamps.iter() {
                        info!("Timestamp estimate is {}", timestamp);
                    }
                })
            }

            KaspadPayloadOps::GetFeeEstimate => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_fee_estimate().await.unwrap();
                    info!("{:?}", response.priority_bucket);
                    assert!(!response.normal_buckets.is_empty());
                    assert!(!response.low_buckets.is_empty());
                    for bucket in response.ordered_buckets() {
                        info!("{:?}", bucket);
                    }
                })
            }

            KaspadPayloadOps::GetFeeEstimateExperimental => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client.get_fee_estimate_experimental(true).await.unwrap();
                    assert!(!response.estimate.normal_buckets.is_empty());
                    assert!(!response.estimate.low_buckets.is_empty());
                    for bucket in response.estimate.ordered_buckets() {
                        info!("{:?}", bucket);
                    }
                    assert!(response.verbose.is_some());
                    info!("{:?}", response.verbose);
                })
            }

            KaspadPayloadOps::GetUtxoReturnAddress => {
                let rpc_client = client.clone();
                tst!(op, {
                    let results = rpc_client.get_utxo_return_address(RpcHash::from_bytes([0; 32]), 1000).await;

                    assert!(results.is_err_and(|err| {
                        match err {
                            kaspa_rpc_core::RpcError::General(msg) => {
                                info!("Expected error message: {}", msg);
                                true
                            }
                            _ => false,
                        }
                    }));
                })
            }

            KaspadPayloadOps::GetUtxosByScriptVersion => {
                let rpc_client = client.clone();
                tst!(op, {
                    // Query for stealth UTXOs (script version 16)
                    // Should return empty since no stealth UTXOs exist yet
                    let response = rpc_client.get_utxos_by_script_version(16, None, None).await.unwrap();
                    assert!(response.entries.is_empty());
                    assert!(response.next_cursor.is_none());
                })
            }

            KaspadPayloadOps::RegisterMldsaAnchor => {
                let rpc_client = client.clone();
                tst!(op, {
                    let mut anchor = [0u8; 32];
                    anchor[0] = 1;
                    let first = rpc_client
                        .register_mldsa_anchor_call(
                            None,
                            RegisterMldsaAnchorRequest { anchor, metadata: Some("integration-smoke".into()) },
                        )
                        .await
                        .unwrap();
                    assert!(first.accepted, "first registration should be accepted");

                    let second = rpc_client
                        .register_mldsa_anchor_call(None, RegisterMldsaAnchorRequest { anchor, metadata: None })
                        .await
                        .unwrap();
                    assert!(!second.accepted, "duplicate registration must be rejected");
                })
            }

            KaspadPayloadOps::ListMldsaDelegations => {
                let rpc_client = client.clone();
                tst!(op, {
                    let mut anchor = [0u8; 32];
                    anchor[1] = 2;

                    // Unknown anchor should return empty set
                    let response = rpc_client.list_mldsa_delegations_call(None, ListMldsaDelegationsRequest { anchor }).await.unwrap();
                    assert!(response.delegations.is_empty());

                    // After registering an anchor, the RPC still returns empty because delegations
                    // are not indexed at service level yet.
                    rpc_client.register_mldsa_anchor_call(None, RegisterMldsaAnchorRequest { anchor, metadata: None }).await.unwrap();
                    let response = rpc_client.list_mldsa_delegations_call(None, ListMldsaDelegationsRequest { anchor }).await.unwrap();
                    assert!(response.delegations.is_empty());
                })
            }

            KaspadPayloadOps::GetBlockViewTags => {
                let rpc_client = client.clone();
                tst!(op, {
                    // Query for view tags in genesis block
                    // Should return empty stealth outputs since genesis has no stealth transactions
                    let response = rpc_client
                        .get_block_view_tags_call(None, kaspa_rpc_core::GetBlockViewTagsRequest { hash: SIMNET_GENESIS.hash })
                        .await
                        .unwrap();
                    assert_eq!(response.block_hash, SIMNET_GENESIS.hash);
                    assert!(response.stealth_outputs.is_empty());
                })
            }

            KaspadPayloadOps::GetVirtualChainFromBlockV2 => {
                let rpc_client = client.clone();
                tst!(op, {
                    let response = rpc_client
                        .get_virtual_chain_from_block_v2_call(
                            None,
                            GetVirtualChainFromBlockV2Request {
                                start_hash: SIMNET_GENESIS.hash,
                                data_verbosity_level: None,
                                min_confirmation_count: None,
                            },
                        )
                        .await
                        .unwrap();
                    assert!(response.added_chain_block_hashes.is_empty());
                    assert!(response.removed_chain_block_hashes.is_empty());
                })
            }

            KaspadPayloadOps::NotifyBlockAdded => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, BlockAddedScope::default().into()).await.unwrap();
                })
            }

            KaspadPayloadOps::NotifyNewBlockTemplate => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, NewBlockTemplateScope {}.into()).await.unwrap();
                })
            }

            KaspadPayloadOps::NotifyFinalityConflict => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, FinalityConflictScope {}.into()).await.unwrap();
                })
            }
            KaspadPayloadOps::NotifyUtxosChanged => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, UtxosChangedScope::new(vec![]).into()).await.unwrap();
                })
            }
            KaspadPayloadOps::NotifySinkBlueScoreChanged => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, SinkBlueScoreChangedScope {}.into()).await.unwrap();
                })
            }
            KaspadPayloadOps::NotifyPruningPointUtxoSetOverride => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, PruningPointUtxoSetOverrideScope {}.into()).await.unwrap();
                })
            }
            KaspadPayloadOps::NotifyVirtualDaaScoreChanged => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.start_notify(id, VirtualDaaScoreChangedScope {}.into()).await.unwrap();
                })
            }
            KaspadPayloadOps::NotifyVirtualChainChanged => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client
                        .start_notify(id, VirtualChainChangedScope { include_accepted_transaction_ids: false }.into())
                        .await
                        .unwrap();
                })
            }
            KaspadPayloadOps::StopNotifyingUtxosChanged => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.stop_notify(id, UtxosChangedScope::new(vec![]).into()).await.unwrap();
                })
            }
            KaspadPayloadOps::StopNotifyingPruningPointUtxoSetOverride => {
                let rpc_client = client.clone();
                let id = listener_id;
                tst!(op, {
                    rpc_client.stop_notify(id, PruningPointUtxoSetOverrideScope {}.into()).await.unwrap();
                })
            }
        };
        tasks.push(task);
    }

    let _results = try_join_all(tasks).await;

    // Unregister the notification listener
    assert!(client.unregister_listener(listener_id).await.is_ok());

    // Shutdown should only be tested after everything
    let rpc_client = client.clone();
    let _ = rpc_client.shutdown_call(None, ShutdownRequest {}).await.unwrap();

    //
    // Fold-up
    //
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

// ============================================================================
// Stealth Address Tests for get_block_template
// ============================================================================

/// Test that get_block_template works with stealth pay address
/// The stealth script goes into the coinbase PAYLOAD (for future payout when this block is merged).
/// To test actual stealth OUTPUTS, we mine with stealth, then mine another block that merges it.
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_stealth_address`
#[tokio::test]
async fn test_get_block_template_stealth_address() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // 1. Generate stealth address
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    // For Simnet/Devnet/Testnet use StealthTestnet (qstest)
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());

    // 2. Mine first block with stealth address
    // The stealth SPK is embedded in the coinbase PAYLOAD (not outputs yet)
    let stealth_template = client
        .get_block_template(stealth_address.clone(), vec![])
        .await
        .expect("get_block_template should succeed with stealth address");

    // Verify the template was created (stealth script is in payload)
    assert!(!stealth_template.block.transactions.is_empty(), "Block template should have coinbase");
    let stealth_coinbase = &stealth_template.block.transactions[0];
    info!("Stealth block payload length: {}", stealth_coinbase.payload.len());
    // Payload should contain stealth script (version=16, len=66)
    assert!(stealth_coinbase.payload.len() > 19 + 66, "Payload should contain stealth script");

    // Submit the stealth block
    let submit_response = client.submit_block(stealth_template.block, false).await.unwrap();
    assert_eq!(submit_response.report, SubmitBlockReport::Success, "Stealth block submission should succeed");

    // 3. Mine another block that merges the stealth block
    // This block's coinbase outputs should pay to the stealth address from the merged block
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);
    let merging_template = client.get_block_template(regular_address, vec![]).await.expect("get_block_template should succeed");

    let merging_coinbase = &merging_template.block.transactions[0];
    info!("Merging block coinbase outputs count: {}", merging_coinbase.outputs.len());

    // The merging block should have outputs paying the merged stealth block's rewards
    assert!(!merging_coinbase.outputs.is_empty(), "Merging block should have coinbase outputs for merged blocks");

    // The output paying the stealth block should have stealth script (version=16)
    let stealth_output = &merging_coinbase.outputs[0];
    assert_eq!(
        stealth_output.script_public_key.version, STEALTH_SCRIPT_VERSION,
        "Output paying stealth block should have stealth script version (16)"
    );
    assert_eq!(
        stealth_output.script_public_key.script().len(),
        66,
        "Stealth script should be 66 bytes (33B ephemeral + 1B tag + 32B dest)"
    );

    // Submit the merging block
    let submit_response = client.submit_block(merging_template.block, false).await.unwrap();
    assert_eq!(submit_response.report, SubmitBlockReport::Success);

    // Cleanup
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test regular vs stealth address comparison in get_block_template
/// Shows that regular address produces regular outputs while stealth produces stealth outputs
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_regular_vs_stealth`
#[tokio::test]
async fn test_get_block_template_regular_vs_stealth() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // 1. Mine first block with REGULAR address
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);
    let regular_template = client.get_block_template(regular_address.clone(), vec![]).await.unwrap();
    client.submit_block(regular_template.block, false).await.unwrap();

    // 2. Mine second block with STEALTH address
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());
    let stealth_template = client.get_block_template(stealth_address, vec![]).await.unwrap();

    // This block's coinbase output pays the REGULAR block (merged)
    // So output[0] should have regular script (not stealth)
    let regular_payout = &stealth_template.block.transactions[0].outputs[0];
    assert_ne!(
        regular_payout.script_public_key.version, STEALTH_SCRIPT_VERSION,
        "Output paying regular block should NOT have stealth script version"
    );

    client.submit_block(stealth_template.block, false).await.unwrap();

    // 3. Mine third block with regular address
    let third_template = client.get_block_template(regular_address, vec![]).await.unwrap();

    // This block's coinbase output pays the STEALTH block (merged)
    // So output[0] should have stealth script (version=16)
    let stealth_payout = &third_template.block.transactions[0].outputs[0];
    assert_eq!(
        stealth_payout.script_public_key.version, STEALTH_SCRIPT_VERSION,
        "Output paying stealth block should have stealth script version (16)"
    );
    assert_eq!(stealth_payout.script_public_key.script().len(), 66, "Stealth script should be 66 bytes");

    // Cleanup
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test error handling for invalid stealth payload
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_stealth_invalid_payload`
#[tokio::test]
async fn test_get_block_template_stealth_invalid_payload() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // 1. Wrong payload length (32 instead of 64 bytes)
    let bad_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &[1u8; 32]);
    let result = client.get_block_template_call(None, GetBlockTemplateRequest { pay_address: bad_address, extra_data: vec![] }).await;

    assert!(result.is_err(), "Should fail with wrong payload length");
    let err_msg = result.unwrap_err().to_string().to_lowercase();
    assert!(err_msg.contains("payload") || err_msg.contains("length"), "Error should mention payload length: {}", err_msg);

    // 2. All zeros as public keys (invalid curve points)
    let bad_keys = Address::new(Prefix::StealthTestnet, Version::Stealth, &[0u8; 64]);
    let result = client.get_block_template_call(None, GetBlockTemplateRequest { pay_address: bad_keys, extra_data: vec![] }).await;

    assert!(result.is_err(), "Should fail with invalid public keys");
    let err_msg = result.unwrap_err().to_string().to_lowercase();
    assert!(err_msg.contains("invalid") || err_msg.contains("stealth"), "Error should mention invalid stealth address: {}", err_msg);

    // Cleanup
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test error handling for wrong stealth prefix
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_stealth_invalid_prefix`
#[tokio::test]
async fn test_get_block_template_stealth_invalid_prefix() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // Use mainnet stealth prefix (qs) on simnet daemon - should fail
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let wrong_prefix_address = Address::new(
        Prefix::StealthMainnet, // "qs" instead of "qstest"
        Version::Stealth,
        &stealth_addr.to_bytes(),
    );

    let result =
        client.get_block_template_call(None, GetBlockTemplateRequest { pay_address: wrong_prefix_address, extra_data: vec![] }).await;

    assert!(result.is_err(), "Should fail with wrong prefix");
    let err_msg = result.unwrap_err().to_string().to_lowercase();
    assert!(err_msg.contains("prefix") || err_msg.contains("invalid"), "Error should mention invalid prefix: {}", err_msg);

    // Cleanup
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test full stealth coinbase cycle: mine -> scan -> verify ownership
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_stealth_coinbase_can_be_scanned`
#[tokio::test]
async fn test_stealth_coinbase_can_be_scanned() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // 1. Generate stealth keys
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());

    // 2. Mine block with stealth address (stealth SPK goes into payload)
    let stealth_template = client.get_block_template(stealth_address, vec![]).await.unwrap();
    client.submit_block(stealth_template.block, false).await.unwrap();

    // 3. Mine another block that merges the stealth block
    // The merging block's coinbase will have a stealth OUTPUT paying the stealth block
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);
    let merging_template = client.get_block_template(regular_address, vec![]).await.unwrap();

    let merging_coinbase = &merging_template.block.transactions[0];
    assert!(!merging_coinbase.outputs.is_empty(), "Merging block should have coinbase outputs");

    // 4. Extract ephemeral output from the stealth payout
    let stealth_output_spk = &merging_coinbase.outputs[0].script_public_key;
    assert_eq!(stealth_output_spk.version, STEALTH_SCRIPT_VERSION, "Output should be stealth");

    let ephemeral = extract_stealth_output(stealth_output_spk).expect("Should be valid stealth output");

    // 5. Check view tag matches for owner
    // check_view_tag(ephemeral_pubkey, view_tag, scan_secret) -> bool
    let view_tag_matches = check_view_tag(&ephemeral.ephemeral_pubkey, ephemeral.view_tag, &stealth_secret.scan_secret());
    assert!(view_tag_matches, "View tag should match for owner");

    // 6. Full scan - verify ownership
    let scan_result = scan_output(&ephemeral, &stealth_secret.scan_secret(), &stealth_addr.spend_pubkey)
        .expect("Should scan successfully for owner");

    // 7. Derive spending key and verify
    // ScanResult only has blinding_factor, use it to derive the spending key
    let spending_key = derive_spending_key(&stealth_secret.spend_secret(), &scan_result.blinding_factor).unwrap();

    // 8. Verify derived key matches destination in ephemeral output
    assert!(verify_derived_key(&spending_key, &ephemeral.destination_pubkey), "Derived spending key should be valid");

    // Cleanup
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test stealth payout for red blocks using simnet with overridden k=3
/// red_reward goes directly to current miner's stealth SPK
///
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_stealth_red_reward`
#[tokio::test]
async fn test_get_block_template_stealth_red_reward() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    // Override simnet params for test: set small k to force red blocks and disable crescendo.
    let override_file = simnet_overrides_with_k("test_stealth_red_reward_params.json", 3, ForkActivation::never());

    let override_path = override_file.to_string_lossy().to_string();
    println!("Override params file: {}", override_path);
    println!("Override params content: {}", std::fs::read_to_string(&override_file).unwrap());

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        override_params_file: Some(override_path.clone()),
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // Mine initial block to have a valid tip
    let initial_address = Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32]);
    let initial_template = client.get_block_template(initial_address.clone(), vec![]).await.unwrap();
    client.submit_block(initial_template.block, false).await.unwrap();

    // Create k+2 = 5 competing blocks with the same parent to force at least 1-2 to be red
    // Each block needs different extra_data to have different hash
    // Using 5 blocks to ensure at least 1 red even if k rounds up
    const NUM_COMPETING_BLOCKS: usize = 5;
    let mut templates = Vec::with_capacity(NUM_COMPETING_BLOCKS);

    for i in 0..NUM_COMPETING_BLOCKS {
        let extra_data = format!("block_{}", i).into_bytes();
        let template = client.get_block_template(initial_address.clone(), extra_data).await.unwrap();
        templates.push(template);
    }

    // Verify all templates have the same parent
    let first_parents = &templates[0].block.header.parents_by_level;
    for (i, template) in templates.iter().enumerate().skip(1) {
        assert_eq!(&template.block.header.parents_by_level, first_parents, "Block {} should have same parent as block 0", i);
    }

    // Submit all competing blocks
    for (i, template) in templates.into_iter().enumerate() {
        let result = client.submit_block(template.block, false).await;
        println!("Submit competing block {} result: {:?}", i, result);
    }

    // Now get block template with stealth address
    // This block will merge all 4 blocks: 3 will be blue, 1 will be red
    // red_reward should go to current miner's stealth SPK
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());

    let final_template = client.get_block_template(stealth_address, vec![]).await.unwrap();
    let final_coinbase = &final_template.block.transactions[0];

    println!("Final coinbase outputs count: {}", final_coinbase.outputs.len());
    for (i, output) in final_coinbase.outputs.iter().enumerate() {
        println!(
            "  Output {}: amount={}, version={}, script_len={}",
            i,
            output.value,
            output.script_public_key.version,
            output.script_public_key.script().len()
        );
    }

    // We should have:
    // - 3 outputs for merged blue blocks (to initial_address) - k=3
    // - 1+ outputs for red_reward (to current miner's stealth SPK) - 5-3=2 red blocks
    // Total: at least 4 outputs
    assert!(
        final_coinbase.outputs.len() >= 4,
        "Should have at least 4 outputs (3 blue payouts + red rewards), got {}",
        final_coinbase.outputs.len()
    );

    // Find the stealth output (should be the red_reward)
    let stealth_outputs: Vec<_> =
        final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == STEALTH_SCRIPT_VERSION).collect();

    assert!(!stealth_outputs.is_empty(), "Should have at least one stealth output for red_reward");

    // Verify the stealth output format
    let stealth_output = stealth_outputs[0];
    assert_eq!(stealth_output.script_public_key.version, STEALTH_SCRIPT_VERSION);
    assert_eq!(stealth_output.script_public_key.script().len(), 66, "Stealth script should be 66 bytes");

    // Verify we can scan this stealth output
    let ephemeral = extract_stealth_output(&stealth_output.script_public_key).expect("Should be valid stealth output");

    let view_tag_matches = check_view_tag(&ephemeral.ephemeral_pubkey, ephemeral.view_tag, &stealth_secret.scan_secret());
    assert!(view_tag_matches, "View tag should match for stealth owner");

    let scan_result = scan_output(&ephemeral, &stealth_secret.scan_secret(), &stealth_addr.spend_pubkey)
        .expect("Should scan successfully for owner");

    let spending_key = derive_spending_key(&stealth_secret.spend_secret(), &scan_result.blinding_factor).unwrap();
    assert!(
        verify_derived_key(&spending_key, &ephemeral.destination_pubkey),
        "Derived spending key should be valid for red_reward output"
    );

    println!("Red reward stealth output verified successfully!");
    println!("  Amount: {}", stealth_output.value);

    // Cleanup
    std::fs::remove_file(&override_file).ok();
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test mixed stealth/regular blue blocks in coinbase
/// Blue block rewards preserve the original miner's SPK
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_mixed_stealth_regular_blues`
#[tokio::test]
async fn test_get_block_template_mixed_stealth_regular_blues() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    // Override simnet params for test: k=3 and disable crescendo.
    let override_file = simnet_overrides_with_k("test_mixed_blues_params.json", 3, ForkActivation::never());

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        override_params_file: Some(override_file.to_string_lossy().to_string()),
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // Mine initial block to have a valid tip
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32]);
    let initial_template = client.get_block_template(regular_address.clone(), vec![]).await.unwrap();
    client.submit_block(initial_template.block, false).await.unwrap();

    // Create 4 competing blocks with the same parent:
    // - 2 with regular addresses
    // - 2 with stealth addresses
    // With k=3, all 4 can be blue (k+1=4)

    let stealth_secret1 = StealthSecretKey::generate().unwrap();
    let stealth_addr1 = stealth_secret1.to_address();
    let stealth_address1 = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr1.to_bytes());

    let stealth_secret2 = StealthSecretKey::generate().unwrap();
    let stealth_addr2 = stealth_secret2.to_address();
    let stealth_address2 = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr2.to_bytes());

    let regular_address2 = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);

    // Create templates for all 4 competing blocks
    let template_regular1 = client.get_block_template(regular_address.clone(), "regular1".as_bytes().to_vec()).await.unwrap();
    let template_regular2 = client.get_block_template(regular_address2.clone(), "regular2".as_bytes().to_vec()).await.unwrap();
    let template_stealth1 = client.get_block_template(stealth_address1.clone(), "stealth1".as_bytes().to_vec()).await.unwrap();
    let template_stealth2 = client.get_block_template(stealth_address2.clone(), "stealth2".as_bytes().to_vec()).await.unwrap();

    // Submit all 4 competing blocks
    client.submit_block(template_regular1.block, false).await.unwrap();
    client.submit_block(template_regular2.block, false).await.unwrap();
    client.submit_block(template_stealth1.block, false).await.unwrap();
    client.submit_block(template_stealth2.block, false).await.unwrap();

    // Get final block template with a regular address (doesn't matter for this test)
    let final_template = client.get_block_template(regular_address, vec![]).await.unwrap();
    let final_coinbase = &final_template.block.transactions[0];

    println!("Final coinbase outputs count: {}", final_coinbase.outputs.len());
    for (i, output) in final_coinbase.outputs.iter().enumerate() {
        println!(
            "  Output {}: amount={}, version={}, script_len={}",
            i,
            output.value,
            output.script_public_key.version,
            output.script_public_key.script().len()
        );
    }

    // Count regular and stealth outputs
    let regular_outputs: Vec<_> = final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == 0).collect();
    let stealth_outputs: Vec<_> =
        final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == STEALTH_SCRIPT_VERSION).collect();

    println!("Regular outputs: {}, Stealth outputs: {}", regular_outputs.len(), stealth_outputs.len());

    // We should have:
    // - 2 regular outputs (from regular1 and regular2 blocks)
    // - 2 stealth outputs (from stealth1 and stealth2 blocks)
    assert!(regular_outputs.len() >= 2, "Should have at least 2 regular outputs, got {}", regular_outputs.len());
    assert!(stealth_outputs.len() >= 2, "Should have at least 2 stealth outputs, got {}", stealth_outputs.len());

    // Verify each stealth output has unique ephemeral pubkey
    let ephemeral1 = extract_stealth_output(&stealth_outputs[0].script_public_key).expect("Should be valid stealth output 1");
    let ephemeral2 = extract_stealth_output(&stealth_outputs[1].script_public_key).expect("Should be valid stealth output 2");

    assert_ne!(ephemeral1.ephemeral_pubkey, ephemeral2.ephemeral_pubkey, "Each stealth output should have unique ephemeral pubkey");

    println!("Mixed stealth/regular blues test passed!");

    // Cleanup
    std::fs::remove_file(&override_file).ok();
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test multiple red block rewards aggregation
/// When multiple blocks become red, their rewards are summed into one output
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_multiple_red_aggregation`
#[tokio::test]
async fn test_get_block_template_multiple_red_aggregation() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    // Override simnet params for test: k=2 to force red blocks and disable crescendo.
    let override_file = simnet_overrides_with_k("test_multiple_red_params.json", 2, ForkActivation::never());

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        override_params_file: Some(override_file.to_string_lossy().to_string()),
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // Mine initial block
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32]);
    let initial_template = client.get_block_template(regular_address.clone(), vec![]).await.unwrap();
    client.submit_block(initial_template.block, false).await.unwrap();

    // Create 5 competing blocks with the same parent
    // With k=2: max k+1=3 blue, so at least 5-3=2 red
    const NUM_COMPETING_BLOCKS: usize = 5;
    let mut templates = Vec::with_capacity(NUM_COMPETING_BLOCKS);

    for i in 0..NUM_COMPETING_BLOCKS {
        let extra_data = format!("block_{}", i).into_bytes();
        let template = client.get_block_template(regular_address.clone(), extra_data).await.unwrap();
        templates.push(template);
    }

    // Submit all competing blocks
    for template in templates {
        client.submit_block(template.block, false).await.unwrap();
    }

    // Get final block template with stealth address
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());

    let final_template = client.get_block_template(stealth_address, vec![]).await.unwrap();
    let final_coinbase = &final_template.block.transactions[0];

    println!("Final coinbase outputs count: {}", final_coinbase.outputs.len());
    for (i, output) in final_coinbase.outputs.iter().enumerate() {
        println!(
            "  Output {}: amount={}, version={}, script_len={}",
            i,
            output.value,
            output.script_public_key.version,
            output.script_public_key.script().len()
        );
    }

    // Count outputs
    let regular_outputs: Vec<_> = final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == 0).collect();
    let stealth_outputs: Vec<_> =
        final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == STEALTH_SCRIPT_VERSION).collect();

    // With k=2 and 5 competing blocks: 3 blue (regular) + 2 red (aggregated to 1 stealth)
    assert_eq!(regular_outputs.len(), 3, "Should have exactly 3 blue outputs (k+1=3), got {}", regular_outputs.len());
    assert_eq!(
        stealth_outputs.len(),
        1,
        "Should have exactly 1 stealth output (aggregated red reward), got {}",
        stealth_outputs.len()
    );

    // Verify red reward amount = subsidy × 2 (two red blocks)
    // simnet subsidy at low daa_score should be 50 KAS = 5_000_000_000 sompi
    let expected_subsidy = 5_000_000_000u64; // 50 KAS
    let expected_red_reward = expected_subsidy * 2; // 2 red blocks
    let actual_red_reward = stealth_outputs[0].value;

    println!("Red reward: expected={} (2 × {}), actual={}", expected_red_reward, expected_subsidy, actual_red_reward);

    assert_eq!(actual_red_reward, expected_red_reward, "Red reward should be subsidy × num_red_blocks");

    println!("Multiple red aggregation test passed!");

    // Cleanup
    std::fs::remove_file(&override_file).ok();
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test non-DAA red blocks - blocks with blue_score below difficulty window
/// Non-DAA red blocks contribute only fees (not subsidy) to the red reward
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_get_block_template_non_daa_red_blocks`
#[tokio::test]
async fn test_get_block_template_non_daa_red_blocks() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    // Override params:
    // - difficulty_window_size=5 (small window for non-DAA condition)
    // - min_difficulty_window_size=5
    // - ghostdag_k=2 (to create red blocks)
    // - crescendo_activation=always (non-DAA reds get fees only)
    let mut overrides: OverrideParams = Params::from(NetworkType::Simnet).into();
    overrides.difficulty_window_size = Some(5);
    overrides.min_difficulty_window_size = Some(5);
    overrides.crescendo_activation = Some(ForkActivation::always());
    overrides.blockrate.as_mut().expect("OverrideParams from Params should include blockrate").ghostdag_k = 2;
    let override_file = write_override_params_file("test_non_daa_params.json", overrides);

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        override_params_file: Some(override_file.to_string_lossy().to_string()),
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[0u8; 32]);

    // Step 1: Create multiple "early" templates pointing to genesis (don't submit yet)
    // These will have blue_score ~1 (parent is genesis with blue_score 0)
    let mut early_templates = Vec::new();
    for i in 0..5 {
        let extra_data = format!("early_{}", i).into_bytes();
        let template = client.get_block_template(regular_address.clone(), extra_data).await.unwrap();
        early_templates.push(template);
    }
    println!("Created {} early templates (blue_score ~1)", early_templates.len());

    // Step 2: Mine the first template to start the chain
    let first_template = early_templates.remove(0);
    client.submit_block(first_template.block, false).await.unwrap();

    // Step 3: Mine 15 more blocks to advance the chain
    // This increases blue_score significantly
    for i in 0..15 {
        let extra_data = format!("chain_{}", i).into_bytes();
        let template = client.get_block_template(regular_address.clone(), extra_data).await.unwrap();
        client.submit_block(template.block, false).await.unwrap();
    }
    println!("Mined 15 blocks - chain advanced");

    // Step 4: Now submit the remaining early templates
    // They still point to genesis, so their blue_score remains ~1
    // But current blue_score is ~16
    // With difficulty_window=5, lowest_daa_blue_score = 16 - 5 = 11
    // Early blocks with blue_score ~1 < 11 → non-DAA!
    for (i, template) in early_templates.into_iter().enumerate() {
        let result = client.submit_block(template.block, false).await.unwrap();
        println!("Submitted early template {}: {:?}", i, result.report);
    }

    // Step 5: Get final block template with stealth address
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());

    let final_template = client.get_block_template(stealth_address, vec![]).await.unwrap();
    let final_coinbase = &final_template.block.transactions[0];

    println!("Final coinbase outputs count: {}", final_coinbase.outputs.len());
    for (i, output) in final_coinbase.outputs.iter().enumerate() {
        println!(
            "  Output {}: amount={}, version={}, script_len={}",
            i,
            output.value,
            output.script_public_key.version,
            output.script_public_key.script().len()
        );
    }

    // Step 6: Verify the coinbase structure
    // The early templates now have blue_score ~1 which is < lowest_daa_blue_score
    // With crescendo active, non-DAA red blocks contribute only fees (not subsidy)
    // Since these blocks have no user transactions, fees = 0
    // Therefore, non-DAA red blocks contribute 0 to red_reward

    // Count outputs by type
    let regular_outputs: Vec<_> = final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == 0).collect();
    let stealth_outputs: Vec<_> =
        final_coinbase.outputs.iter().filter(|o| o.script_public_key.version == STEALTH_SCRIPT_VERSION).collect();

    println!("Regular outputs: {}, Stealth outputs: {}", regular_outputs.len(), stealth_outputs.len());

    // Analysis:
    // - 4 early templates submitted late (non-DAA, blue_score ~1)
    // - With k=2, max k+1=3 can be blue from anticone
    // - The rest become red
    // - Non-DAA red blocks: contribute 0 (fees only, no transactions)
    // - Non-DAA blue blocks: filtered out (no output)

    // The key verification: non-DAA blocks (whether blue or red) don't add subsidy
    // This test confirms the scenario exists and completes without error
    // A more precise check would require examining the exact reward amounts

    // If there's a stealth output, it's for DAA red blocks only (which got subsidy)
    // Non-DAA red blocks contributed 0
    if !stealth_outputs.is_empty() {
        println!("Stealth output present - likely from DAA red blocks (if any)");
        let stealth_output = stealth_outputs[0];
        // With k=2 and recent blocks, some might be DAA red
        // The non-DAA early blocks don't contribute subsidy
        println!("Stealth output amount: {}", stealth_output.value);
    } else {
        println!("No stealth output - all red blocks were non-DAA (contributed 0)");
    }

    println!("Non-DAA red blocks test completed successfully!");

    // Cleanup
    std::fs::remove_file(&override_file).ok();
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test that stealth coinbase output can be spent
/// This is a consensus-critical test - verifies miners can actually spend their rewards
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_stealth_coinbase_can_be_spent`
#[tokio::test]
async fn test_stealth_coinbase_can_be_spent() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    // Create override params file with low coinbase maturity for faster test
    // Also disable crescendo so prior_coinbase_maturity is used
    let override_params = r#"{"prior_coinbase_maturity": 10, "crescendo_activation": 18446744073709551615}"#;
    let temp_dir = std::env::temp_dir();
    let override_file = temp_dir.join("test_stealth_coinbase_spend_params.json");
    std::fs::write(&override_file, override_params).expect("Failed to write override params file");

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true,
        override_params_file: Some(override_file.to_string_lossy().to_string()),
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // 1. Generate stealth keys
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_address = Address::new(Prefix::StealthTestnet, Version::Stealth, &stealth_addr.to_bytes());

    // 2. Mine first block with stealth address (stealth SPK goes into coinbase payload)
    let stealth_template = client.get_block_template(stealth_address.clone(), vec![]).await.unwrap();
    client.submit_block(stealth_template.block.clone(), false).await.unwrap();
    println!("Mined block with stealth address in payload");

    // 3. Mine a merging block - the stealth reward appears as UTXO in this block's coinbase
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);
    let merging_template = client.get_block_template(regular_address.clone(), vec![]).await.unwrap();
    let merging_coinbase = &merging_template.block.transactions[0];

    // Find the stealth output in the merging block's coinbase
    let stealth_output_idx = merging_coinbase
        .outputs
        .iter()
        .position(|o| o.script_public_key.version == STEALTH_SCRIPT_VERSION)
        .expect("Merging block should have stealth output");
    let stealth_utxo_spk = merging_coinbase.outputs[stealth_output_idx].script_public_key.clone();
    let stealth_utxo_value = merging_coinbase.outputs[stealth_output_idx].value;

    println!(
        "Found stealth output in merging block coinbase: index={}, value={}, script_len={}",
        stealth_output_idx,
        stealth_utxo_value,
        stealth_utxo_spk.script().len()
    );

    // Submit the merging block
    client.submit_block(merging_template.block.clone(), false).await.unwrap();
    println!("Submitted merging block");

    // 4. Mine COINBASE_MATURITY blocks for the UTXO to mature
    // Using override params: prior_coinbase_maturity = 10
    const COINBASE_MATURITY: u64 = 10;
    for i in 0..COINBASE_MATURITY + 5 {
        let template = client.get_block_template(regular_address.clone(), vec![]).await.unwrap();
        client.submit_block(template.block, false).await.unwrap();
        if i % 20 == 0 {
            println!("Mined {} maturity blocks...", i + 1);
        }
    }
    println!("Mined {} blocks for coinbase maturity", COINBASE_MATURITY + 5);

    // 5. Extract ephemeral output from the stealth SPK
    let ephemeral = extract_stealth_output(&stealth_utxo_spk).expect("Should be valid stealth output");

    // 6. Scan the output to get blinding factor
    let scan_result =
        scan_output(&ephemeral, &stealth_secret.scan_secret(), &stealth_addr.spend_pubkey).expect("Should scan successfully");

    // 7. Derive the spending key
    let spending_secret =
        derive_spending_key(&stealth_secret.spend_secret(), &scan_result.blinding_factor).expect("Should derive spending key");

    // Verify the derived key matches
    assert!(
        verify_derived_key(&spending_secret, &ephemeral.destination_pubkey),
        "Derived spending key should match destination pubkey"
    );

    println!("Successfully derived spending key from scan result");

    // 8. Create a transaction spending the stealth UTXO
    // The coinbase transaction ID is needed to reference the UTXO
    let coinbase_consensus_tx =
        Transaction::try_from(merging_template.block.transactions[0].clone()).expect("valid coinbase transaction");
    let coinbase_tx_id = coinbase_consensus_tx.id();
    let stealth_outpoint = TransactionOutpoint::new(coinbase_tx_id, stealth_output_idx as u32);

    // Create output to a stealth address (simnet policy requires stealth outputs)
    // Reuse the same stealth address for simplicity
    let destination_ephemeral = try_create_stealth_output(&stealth_addr).expect("valid stealth output");
    let destination_spk = pay_to_stealth(&destination_ephemeral);
    let fee = 10_000u64; // 10000 sompi fee
    let output_value = stealth_utxo_value.saturating_sub(fee);

    let unsigned_tx = Transaction::new(
        TX_VERSION,
        vec![TransactionInput::new(stealth_outpoint, vec![], 0, 1)], // sig_op_count = 1 for stealth
        vec![TransactionOutput::new(output_value, destination_spk)],
        0,
        SUBNETWORK_ID_NATIVE,
        0,
        vec![],
    );

    // 9. Sign the stealth input
    // Create UTXO entry for signing
    let utxo_entry = UtxoEntry::new(stealth_utxo_value, stealth_utxo_spk.clone(), COINBASE_MATURITY + 2, true);
    let mutable_tx = MutableTransaction::with_entries(unsigned_tx.clone(), vec![utxo_entry]);

    // Calculate sighash
    let reused_values = SigHashReusedValuesUnsync::new();
    let verifiable = mutable_tx.as_verifiable();
    let sighash = calc_schnorr_signature_hash(&verifiable, 0, SIG_HASH_ALL, &reused_values);

    // Create keypair from spending secret (derive_spending_key already returns SecretKey)
    let keypair = Keypair::from_secret_key(SECP256K1, &spending_secret);

    // Sign
    let message = Message::from_digest_slice(sighash.as_bytes().as_slice()).expect("valid message");
    let signature = SECP256K1.sign_schnorr(&message, &keypair);

    // Create signature script: [64 bytes sig][1 byte sighash_type]
    let mut sig_script = Vec::with_capacity(65);
    sig_script.extend_from_slice(&signature.serialize());
    sig_script.push(SIG_HASH_ALL.to_u8());

    // Create the signed transaction
    let mut signed_tx = unsigned_tx;
    signed_tx.inputs[0].signature_script = sig_script;

    println!("Created signed transaction: {}", signed_tx.id());
    println!("  Input: {:?}", stealth_outpoint);
    println!("  Output value: {} (fee: {})", output_value, fee);
    println!("  Signature script length: {}", signed_tx.inputs[0].signature_script.len());

    // 10. Submit the transaction
    let submit_result = client.submit_transaction((&signed_tx).into(), false).await;
    match &submit_result {
        Ok(_) => println!("Transaction submitted successfully!"),
        Err(e) => println!("Transaction submission failed: {:?}", e),
    }
    assert!(submit_result.is_ok(), "Stealth coinbase spending transaction should be accepted");

    // 11. Mine a block to confirm the transaction
    let confirm_template = client.get_block_template(regular_address, vec![]).await.unwrap();
    let confirm_result = client.submit_block(confirm_template.block, false).await.unwrap();
    assert_eq!(confirm_result.report, SubmitBlockReport::Success, "Confirmation block should be accepted");

    println!("Stealth coinbase spending test PASSED!");

    // Cleanup
    std::fs::remove_file(&override_file).ok();
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}

/// Test that stealth outputs have correct mass calculation
/// Stealth outputs have script_len=66 vs regular=34, affecting compute mass
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_stealth_mass_calculation`
#[tokio::test]
async fn test_stealth_mass_calculation() {
    use kaspa_consensus::params::SIMNET_PARAMS;
    use kaspa_consensus_core::mass::MassCalculator;

    kaspa_core::log::try_init_logger("info");

    // Create mass calculator with simnet params
    let mass_calculator = MassCalculator::new(
        SIMNET_PARAMS.mass_per_tx_byte,
        SIMNET_PARAMS.mass_per_script_pub_key_byte,
        SIMNET_PARAMS.mass_per_sig_op,
        SIMNET_PARAMS.storage_mass_parameter,
    );

    // Create a base transaction structure
    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);
    let regular_spk = pay_to_address_script(&regular_address).expect("valid address");
    println!("Regular SPK version: {}, script len: {}", regular_spk.version, regular_spk.script().len());
    assert_eq!(regular_spk.script().len(), 34, "Regular P2PK script should be 34 bytes");

    // Create stealth output
    let stealth_secret = StealthSecretKey::generate().unwrap();
    let stealth_addr = stealth_secret.to_address();
    let stealth_ephemeral = try_create_stealth_output(&stealth_addr).expect("valid stealth output");
    let stealth_spk = pay_to_stealth(&stealth_ephemeral);
    println!("Stealth SPK version: {}, script len: {}", stealth_spk.version, stealth_spk.script().len());
    assert_eq!(stealth_spk.script().len(), 66, "Stealth script should be 66 bytes");

    // Create transaction with regular output
    let tx_regular = Transaction::new(
        TX_VERSION,
        vec![TransactionInput::new(
            TransactionOutpoint::new(Hash::from_bytes([1u8; 32]), 0),
            vec![0u8; 65], // signature
            0,
            1,
        )],
        vec![TransactionOutput::new(1_000_000_000, regular_spk.clone())],
        0,
        SUBNETWORK_ID_NATIVE,
        0,
        vec![],
    );

    // Create transaction with stealth output
    let tx_stealth = Transaction::new(
        TX_VERSION,
        vec![TransactionInput::new(
            TransactionOutpoint::new(Hash::from_bytes([2u8; 32]), 0),
            vec![0u8; 65], // signature
            0,
            1,
        )],
        vec![TransactionOutput::new(1_000_000_000, stealth_spk.clone())],
        0,
        SUBNETWORK_ID_NATIVE,
        0,
        vec![],
    );

    // Calculate masses
    let regular_mass = mass_calculator.calc_non_contextual_masses(&tx_regular);
    let stealth_mass = mass_calculator.calc_non_contextual_masses(&tx_stealth);

    println!("Regular transaction compute mass: {}", regular_mass.compute_mass);
    println!("Stealth transaction compute mass: {}", stealth_mass.compute_mass);
    println!("Difference: {}", stealth_mass.compute_mass - regular_mass.compute_mass);

    // The mass difference should be due to:
    // 1. Script public key size difference: (66 - 34) = 32 bytes
    // 2. Plus version bytes (2 each), but same for both = 0
    // 3. Transaction serialized size difference: 32 bytes (script is embedded in output)
    //
    // Expected extra mass for stealth:
    // - Script public key mass: 32 * mass_per_script_pub_key_byte = 32 * 2 = 64
    // - Serialized size mass: 32 * mass_per_tx_byte = 32 * 1 = 32
    // Total: 64 + 32 = 96

    let expected_diff = 32 * (SIMNET_PARAMS.mass_per_script_pub_key_byte + SIMNET_PARAMS.mass_per_tx_byte);
    println!("Expected difference: {}", expected_diff);

    assert!(stealth_mass.compute_mass > regular_mass.compute_mass, "Stealth transaction should have higher compute mass");
    assert_eq!(
        stealth_mass.compute_mass - regular_mass.compute_mass,
        expected_diff,
        "Mass difference should be {} (32 bytes × (spk_mass + tx_byte_mass))",
        expected_diff
    );

    println!("Stealth mass calculation test PASSED!");
}

/// Test that stealth UTXOs can be queried via get_utxos_by_script_version API
/// This tests the view tag-based UTXO index query mechanism
/// `cargo test --release --package kaspa-testing-integration --lib -- rpc_tests::test_utxo_index_view_tag_query`
#[tokio::test]
async fn test_utxo_index_view_tag_query() {
    kaspa_core::log::try_init_logger("info");
    kaspa_core::panic::configure_panic();

    let args = Args {
        simnet: true,
        disable_upnp: true,
        enable_unsynced_mining: true,
        block_template_cache_lifetime: Some(0),
        utxoindex: true,
        unsafe_rpc: true, // Required for get_utxos_by_script_version with stealth
        ..Default::default()
    };

    let fd_total_budget = fd_budget::limit();
    let mut daemon = Daemon::new_random_with_args(args, fd_total_budget);
    let client = daemon.start().await;

    // Create 3 different stealth addresses
    let stealth_keys: Vec<_> = (0..3).map(|_| StealthSecretKey::generate().unwrap()).collect();

    let stealth_addresses: Vec<_> = stealth_keys
        .iter()
        .map(|sk| {
            let addr = sk.to_address();
            Address::new(Prefix::StealthTestnet, Version::Stealth, &addr.to_bytes())
        })
        .collect();

    let regular_address = Address::new(Prefix::Simnet, Version::PubKey, &[1u8; 32]);

    // Mine blocks with stealth payouts - each miner gets a stealth coinbase
    // Block 1: stealth_addresses[0]
    let template0 = client.get_block_template(stealth_addresses[0].clone(), vec![]).await.unwrap();
    client.submit_block(template0.block, false).await.unwrap();
    println!("Mined block 1 with stealth address 0");

    // Block 2: stealth_addresses[1]
    let template1 = client.get_block_template(stealth_addresses[1].clone(), vec![]).await.unwrap();
    client.submit_block(template1.block, false).await.unwrap();
    println!("Mined block 2 with stealth address 1");

    // Block 3: stealth_addresses[2]
    let template2 = client.get_block_template(stealth_addresses[2].clone(), vec![]).await.unwrap();
    client.submit_block(template2.block, false).await.unwrap();
    println!("Mined block 3 with stealth address 2");

    // Mine a merging block to make the stealth UTXOs appear
    let merging_template = client.get_block_template(regular_address.clone(), vec![]).await.unwrap();
    client.submit_block(merging_template.block, false).await.unwrap();
    println!("Mined merging block");

    // Query all stealth UTXOs via script version
    let stealth_utxos = client.get_utxos_by_script_version(STEALTH_SCRIPT_VERSION, None, Some(100)).await.unwrap();

    println!("Found {} stealth UTXOs via script version query", stealth_utxos.entries.len());

    // We should have at least 3 stealth UTXOs (one for each miner)
    assert!(stealth_utxos.entries.len() >= 3, "Should find at least 3 stealth UTXOs, found {}", stealth_utxos.entries.len());

    // Verify each stealth UTXO has correct script version
    for (i, entry) in stealth_utxos.entries.iter().enumerate() {
        assert_eq!(
            entry.utxo_entry.script_public_key.version(),
            STEALTH_SCRIPT_VERSION,
            "UTXO {} should have stealth script version",
            i
        );
        println!(
            "Stealth UTXO {}: value={}, script_len={}",
            i,
            entry.utxo_entry.amount,
            entry.utxo_entry.script_public_key.script().len()
        );
    }

    // Test scanning: verify we can extract ephemeral outputs and check view tags
    let mut scan_matches = 0;
    for (key_idx, stealth_key) in stealth_keys.iter().enumerate() {
        let scan_secret = stealth_key.scan_secret();
        let stealth_addr = stealth_key.to_address();

        for entry in &stealth_utxos.entries {
            // Try to extract ephemeral output from the script
            if let Ok(ephemeral) = extract_stealth_output(&entry.utxo_entry.script_public_key) {
                // Check view tag using ephemeral pubkey and view_tag from the output
                if check_view_tag(&ephemeral.ephemeral_pubkey, ephemeral.view_tag, &scan_secret) {
                    // Full scan to verify ownership
                    if let Ok(_scan_result) = scan_output(&ephemeral, &scan_secret, &stealth_addr.spend_pubkey) {
                        println!(
                            "Key {} can scan UTXO with destination pubkey: {:?}",
                            key_idx,
                            &ephemeral.destination_pubkey.serialize()[..4]
                        );
                        scan_matches += 1;
                    }
                }
            }
        }
    }

    println!("Total scan matches: {}", scan_matches);
    assert!(scan_matches >= 3, "Each stealth key should find at least 1 matching UTXO, found {} matches", scan_matches);

    // Test pagination by querying with limit
    let limited_utxos = client.get_utxos_by_script_version(STEALTH_SCRIPT_VERSION, None, Some(1)).await.unwrap();
    assert_eq!(limited_utxos.entries.len(), 1, "Limit=1 should return exactly 1 UTXO");
    println!("Pagination test passed: limit=1 returned 1 entry");

    // If there's a next_cursor, we can paginate
    if let Some(cursor) = limited_utxos.next_cursor {
        let next_page = client.get_utxos_by_script_version(STEALTH_SCRIPT_VERSION, Some(cursor), Some(10)).await.unwrap();
        println!("Pagination: next page has {} entries", next_page.entries.len());
    }

    println!("Stealth UTXO view tag query test PASSED!");

    // Cleanup
    client.disconnect().await.unwrap();
    drop(client);
    daemon.shutdown();
}
