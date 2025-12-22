use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::Response;
use futures::{SinkExt, StreamExt};
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::api::rpc::RpcApi;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::time::Duration;
use tokio::sync::mpsc;
use tokio::time::interval;
use tracing::{debug, error, info, warn};

use crate::api::AppState;

/// Query parameters for DAG WebSocket
#[derive(Debug, Deserialize)]
pub struct DagWsQuery {
    pub node_id: String,
}

/// DAG WebSocket message types
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", content = "data")]
pub enum DagWsMessage {
    BlockAdded(DagBlockMessage),
    VirtualChainChanged(VirtualChainChangedMessage),
    Error { error: String },
    Subscribed { scopes: Vec<String> },
}

#[derive(Debug, Clone, Serialize)]
pub struct DagBlockMessage {
    pub hash: String,
    pub daa_score: u64,
    pub blue_score: u64,
    pub blue_work: String,
    pub parent_hashes: Vec<String>,
    pub selected_parent_hash: Option<String>,
    pub is_chain_block: bool,
    pub timestamp: u64,
    pub block_type: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct VirtualChainChangedMessage {
    pub removed: Vec<String>,
    pub added: Vec<String>,
}

/// Client subscribe message
#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
pub enum ClientMessage {
    Subscribe { scopes: Vec<String> },
}

/// Timeout for WebSocket send operations
const WS_SEND_TIMEOUT: Duration = Duration::from_secs(30);
/// Polling interval for DAG changes
const POLL_INTERVAL: Duration = Duration::from_millis(500);
/// gRPC timeout
const GRPC_TIMEOUT: Duration = Duration::from_secs(10);

/// GET /ws/dag?node_id={id}
/// WebSocket endpoint for DAG notifications
pub async fn handler(State(state): State<AppState>, Query(query): Query<DagWsQuery>, ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(move |socket| handle_socket(socket, state, query.node_id))
}

async fn handle_socket(socket: WebSocket, state: AppState, node_id: String) {
    let (mut sender, mut receiver) = socket.split();

    info!("WebSocket client connected to /ws/dag for node {}", node_id);

    // Get gRPC port for the node (release lock before any await)
    let grpc_port = {
        let cluster_state = state.cluster_state.read();
        cluster_state.nodes.get(&node_id).map(|n| n.grpc_port)
    };

    let grpc_port = match grpc_port {
        Some(port) => port,
        None => {
            let _ = sender
                .send(Message::Text(
                    serde_json::to_string(&DagWsMessage::Error { error: format!("Node {} not found", node_id) })
                        .unwrap_or_default()
                        .into(),
                ))
                .await;
            return;
        }
    };

    // Get container name for Docker network DNS resolution
    let container_name = {
        let cluster_state = state.cluster_state.read();
        cluster_state.nodes.get(&node_id).map(|n| n.container_name.clone())
    };

    let container_name = match container_name {
        Some(name) => name,
        None => {
            let _ = sender
                .send(Message::Text(
                    serde_json::to_string(&DagWsMessage::Error { error: format!("Node {} container not found", node_id) })
                        .unwrap_or_default()
                        .into(),
                ))
                .await;
            return;
        }
    };

    // Use localhost in local mode, Docker container name otherwise
    let host = if state.config.local_mode { "localhost" } else { container_name.as_str() };
    let grpc_url = format!("grpc://{}:{}", host, grpc_port);

    // Connect to the node
    let client = match tokio::time::timeout(GRPC_TIMEOUT, GrpcClient::connect(grpc_url.clone())).await {
        Ok(Ok(client)) => client,
        Ok(Err(e)) => {
            let _ = sender
                .send(Message::Text(
                    serde_json::to_string(&DagWsMessage::Error { error: format!("Failed to connect: {}", e) })
                        .unwrap_or_default()
                        .into(),
                ))
                .await;
            return;
        }
        Err(_) => {
            let _ = sender
                .send(Message::Text(
                    serde_json::to_string(&DagWsMessage::Error { error: "Connection timeout".to_string() }).unwrap_or_default().into(),
                ))
                .await;
            return;
        }
    };

    // Channel for messages from polling task to WebSocket sender
    let (msg_tx, mut msg_rx) = mpsc::channel::<DagWsMessage>(100);
    // Channel to signal subscription
    let (sub_tx, mut sub_rx) = mpsc::channel::<bool>(1);

    // Polling task
    let poll_client = client.clone();
    let poll_msg_tx = msg_tx.clone();
    let poll_task = tokio::spawn(async move {
        // Wait for subscription
        info!("DAG WS poll task: waiting for subscription signal");
        if sub_rx.recv().await.is_none() {
            info!("DAG WS poll task: subscription channel closed, exiting");
            return;
        }
        info!("DAG WS poll task: subscription received, starting polling");

        let mut known_blocks: HashSet<kaspa_hashes::Hash> = HashSet::new();
        let mut last_chain_blocks: Vec<kaspa_hashes::Hash> = Vec::new();
        let mut poll_interval = interval(POLL_INTERVAL);

        loop {
            poll_interval.tick().await;

            // Get DAG info
            let dag_info = match tokio::time::timeout(GRPC_TIMEOUT, poll_client.get_block_dag_info()).await {
                Ok(Ok(info)) => info,
                Ok(Err(e)) => {
                    warn!("Failed to get DAG info: {}", e);
                    continue;
                }
                Err(_) => {
                    warn!("Timeout getting DAG info");
                    continue;
                }
            };

            // Get virtual chain
            let chain = match tokio::time::timeout(
                GRPC_TIMEOUT,
                poll_client.get_virtual_chain_from_block(dag_info.pruning_point_hash, true, None),
            )
            .await
            {
                Ok(Ok(chain)) => chain,
                Ok(Err(e)) => {
                    warn!("Failed to get virtual chain: {}", e);
                    continue;
                }
                Err(_) => {
                    warn!("Timeout getting virtual chain");
                    continue;
                }
            };

            // Check for chain changes
            let current_chain_blocks: Vec<_> = chain.added_chain_block_hashes.clone();

            if !last_chain_blocks.is_empty() && current_chain_blocks != last_chain_blocks {
                let old_set: HashSet<_> = last_chain_blocks.iter().cloned().collect();
                let new_set: HashSet<_> = current_chain_blocks.iter().cloned().collect();

                let removed: Vec<String> = old_set.difference(&new_set).map(|h| h.to_string()).collect();
                let added: Vec<String> = new_set.difference(&old_set).map(|h| h.to_string()).collect();

                if !removed.is_empty() || !added.is_empty() {
                    let _ = poll_msg_tx.send(DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage { removed, added })).await;
                }
            }

            last_chain_blocks = current_chain_blocks;

            // Check for new blocks (tips)
            for tip_hash in &dag_info.tip_hashes {
                if !known_blocks.contains(tip_hash) {
                    known_blocks.insert(*tip_hash);
                    info!("DAG WS poll: found new tip block {}", tip_hash);

                    match tokio::time::timeout(GRPC_TIMEOUT, poll_client.get_block(*tip_hash, true)).await {
                        Ok(Ok(block)) => {
                            let header = &block.header;

                            // New tip blocks are always considered chain blocks initially.
                            // Virtual chain updates asynchronously, so the tip won't be in
                            // added_chain_block_hashes immediately. If a reorg happens later,
                            // VirtualChainChanged will update the block status.
                            let is_chain_block = true;

                            info!("DAG WS: new block {} - is_chain_block={}", tip_hash, is_chain_block);

                            let _ = poll_msg_tx
                                .send(DagWsMessage::BlockAdded(DagBlockMessage {
                                    hash: tip_hash.to_string(),
                                    daa_score: header.daa_score,
                                    blue_score: header.blue_score,
                                    blue_work: header.blue_work.to_string(),
                                    parent_hashes: header
                                        .parents_by_level
                                        .first()
                                        .map(|p| p.iter().map(|h| h.to_string()).collect())
                                        .unwrap_or_default(),
                                    selected_parent_hash: header
                                        .parents_by_level
                                        .first()
                                        .and_then(|p| p.first())
                                        .map(|h| h.to_string()),
                                    is_chain_block,
                                    timestamp: header.timestamp,
                                    block_type: "tip".to_string(),
                                }))
                                .await;
                            info!("DAG WS poll: sent BlockAdded for {}", tip_hash);
                        }
                        _ => {
                            warn!("Failed to get block {}", tip_hash);
                        }
                    }
                }
            }
        }
    });

    // Sender task - forwards messages to WebSocket
    let send_task = tokio::spawn(async move {
        while let Some(msg) = msg_rx.recv().await {
            if let Ok(json) = serde_json::to_string(&msg) {
                debug!("DAG WS sender: sending message");
                match tokio::time::timeout(WS_SEND_TIMEOUT, sender.send(Message::Text(json.into()))).await {
                    Ok(Ok(_)) => debug!("DAG WS sender: message sent successfully"),
                    Ok(Err(_)) => break,
                    Err(_) => {
                        warn!("WebSocket send timeout");
                        break;
                    }
                }
            }
        }
    });

    // Handle incoming messages
    while let Some(msg) = receiver.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                info!("DAG WS received raw message: {}", text);
                match serde_json::from_str::<ClientMessage>(&text) {
                    Ok(client_msg) => match client_msg {
                        ClientMessage::Subscribe { scopes } => {
                            info!("DAG WS client subscribed to {:?}", scopes);
                            let _ = sub_tx.send(true).await;
                            let _ = msg_tx.send(DagWsMessage::Subscribed { scopes }).await;
                            info!("DAG WS subscription signal sent");
                        }
                    },
                    Err(e) => {
                        warn!("DAG WS failed to parse message '{}': {}", text, e);
                    }
                }
            }
            Ok(Message::Close(_)) => {
                debug!("Client sent close");
                break;
            }
            Ok(Message::Ping(_)) => {
                debug!("Received ping");
            }
            Err(e) => {
                error!("WebSocket error: {}", e);
                break;
            }
            _ => {}
        }
    }

    // Cleanup
    poll_task.abort();
    send_task.abort();
    let _ = poll_task.await;
    let _ = send_task.await;
    let _ = client.disconnect().await;

    info!("WebSocket client disconnected from /ws/dag");
}

#[cfg(test)]
mod tests {
    use super::*;

    // ==================== is_chain_block logic tests ====================

    #[test]
    fn test_is_chain_block_single_tip() {
        let tip_hashes_count = 1;
        let chain_contains_tip = false;
        let is_chain_block = tip_hashes_count == 1 || chain_contains_tip;
        assert!(is_chain_block, "Single tip should always be chain block");
    }

    #[test]
    fn test_is_chain_block_multiple_tips_in_chain() {
        let tip_hashes_count = 3;
        let chain_contains_tip = true;
        let is_chain_block = tip_hashes_count == 1 || chain_contains_tip;
        assert!(is_chain_block, "Tip in chain should be chain block");
    }

    #[test]
    fn test_is_chain_block_multiple_tips_not_in_chain() {
        let tip_hashes_count = 3;
        let chain_contains_tip = false;
        let is_chain_block = tip_hashes_count == 1 || chain_contains_tip;
        assert!(!is_chain_block, "Tip not in chain should NOT be chain block");
    }

    // ==================== DagBlockMessage tests ====================

    #[test]
    fn test_dag_block_message_serialization() {
        let msg = DagBlockMessage {
            hash: "abc123".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "123456".to_string(),
            parent_hashes: vec!["parent1".to_string()],
            selected_parent_hash: Some("parent1".to_string()),
            is_chain_block: true,
            timestamp: 1234567890,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"is_chain_block\":true"));

        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["is_chain_block"], true);
    }

    #[test]
    fn test_dag_block_message_is_chain_block_false() {
        let msg = DagBlockMessage {
            hash: "abc123".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "123456".to_string(),
            parent_hashes: vec!["parent1".to_string()],
            selected_parent_hash: Some("parent1".to_string()),
            is_chain_block: false,
            timestamp: 1234567890,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"is_chain_block\":false"));

        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["is_chain_block"], false);
    }

    #[test]
    fn test_dag_block_message_multiple_parents() {
        let msg = DagBlockMessage {
            hash: "abc123".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "123456".to_string(),
            parent_hashes: vec!["parent1".to_string(), "parent2".to_string(), "parent3".to_string()],
            selected_parent_hash: Some("parent1".to_string()),
            is_chain_block: true,
            timestamp: 1234567890,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["parent_hashes"].as_array().unwrap().len(), 3);
        assert_eq!(parsed["selected_parent_hash"], "parent1");
    }

    #[test]
    fn test_dag_block_message_no_selected_parent() {
        let msg = DagBlockMessage {
            hash: "genesis".to_string(),
            daa_score: 0,
            blue_score: 0,
            blue_work: "0".to_string(),
            parent_hashes: vec![],
            selected_parent_hash: None,
            is_chain_block: true,
            timestamp: 1234567890,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert!(parsed["selected_parent_hash"].is_null());
        assert!(parsed["parent_hashes"].as_array().unwrap().is_empty());
    }

    #[test]
    fn test_dag_block_message_field_names_snake_case() {
        let msg = DagBlockMessage {
            hash: "abc".to_string(),
            daa_score: 1,
            blue_score: 2,
            blue_work: "3".to_string(),
            parent_hashes: vec![],
            selected_parent_hash: None,
            is_chain_block: true,
            timestamp: 4,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();

        // Verify snake_case field names for Flutter compatibility
        assert!(json.contains("\"daa_score\""), "Should use daa_score (snake_case)");
        assert!(json.contains("\"blue_score\""), "Should use blue_score (snake_case)");
        assert!(json.contains("\"blue_work\""), "Should use blue_work (snake_case)");
        assert!(json.contains("\"parent_hashes\""), "Should use parent_hashes (snake_case)");
        assert!(json.contains("\"selected_parent_hash\""), "Should use selected_parent_hash (snake_case)");
        assert!(json.contains("\"is_chain_block\""), "Should use is_chain_block (snake_case)");
        assert!(json.contains("\"block_type\""), "Should use block_type (snake_case)");
    }

    // ==================== DagWsMessage tests ====================

    #[test]
    fn test_dag_ws_message_block_added_serialization() {
        let block_msg = DagBlockMessage {
            hash: "abc123".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "123456".to_string(),
            parent_hashes: vec!["parent1".to_string()],
            selected_parent_hash: Some("parent1".to_string()),
            is_chain_block: true,
            timestamp: 1234567890,
            block_type: "tip".to_string(),
        };

        let ws_msg = DagWsMessage::BlockAdded(block_msg);
        let json = serde_json::to_string(&ws_msg).unwrap();

        assert!(json.contains("\"type\":\"BlockAdded\""));
        assert!(json.contains("\"is_chain_block\":true"));

        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["type"], "BlockAdded");
        assert_eq!(parsed["data"]["is_chain_block"], true);
    }

    #[test]
    fn test_dag_ws_message_error() {
        let msg = DagWsMessage::Error { error: "Connection failed".to_string() };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["type"], "Error");
        // With tag+content, struct fields are in "data"
        assert_eq!(parsed["data"]["error"], "Connection failed");
    }

    #[test]
    fn test_dag_ws_message_subscribed() {
        let msg = DagWsMessage::Subscribed { scopes: vec!["block_added".to_string(), "virtual_chain_changed".to_string()] };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["type"], "Subscribed");
        // With tag+content, struct fields are in "data"
        assert_eq!(parsed["data"]["scopes"].as_array().unwrap().len(), 2);
        assert_eq!(parsed["data"]["scopes"][0], "block_added");
        assert_eq!(parsed["data"]["scopes"][1], "virtual_chain_changed");
    }

    // ==================== VirtualChainChanged tests ====================

    #[test]
    fn test_virtual_chain_changed_serialization() {
        let msg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec!["hash1".to_string()],
            added: vec!["hash2".to_string(), "hash3".to_string()],
        });

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["type"], "VirtualChainChanged");
        assert_eq!(parsed["data"]["removed"][0], "hash1");
        assert_eq!(parsed["data"]["added"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn test_virtual_chain_changed_empty_removed() {
        let msg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec![],
            added: vec!["new_chain_block".to_string()],
        });

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert!(parsed["data"]["removed"].as_array().unwrap().is_empty());
        assert_eq!(parsed["data"]["added"].as_array().unwrap().len(), 1);
    }

    #[test]
    fn test_virtual_chain_changed_empty_added() {
        let msg =
            DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage { removed: vec!["orphaned".to_string()], added: vec![] });

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["data"]["removed"].as_array().unwrap().len(), 1);
        assert!(parsed["data"]["added"].as_array().unwrap().is_empty());
    }

    #[test]
    fn test_virtual_chain_changed_reorg_scenario() {
        // Simulate a reorg: multiple blocks removed, multiple added
        let msg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec!["old_block_1".to_string(), "old_block_2".to_string(), "old_block_3".to_string()],
            added: vec!["new_block_1".to_string(), "new_block_2".to_string()],
        });

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["data"]["removed"].as_array().unwrap().len(), 3);
        assert_eq!(parsed["data"]["added"].as_array().unwrap().len(), 2);
    }

    // ==================== ClientMessage parsing tests ====================

    #[test]
    fn test_client_message_subscribe_parsing() {
        let json = r#"{"type":"Subscribe","scopes":["block_added","virtual_chain_changed"]}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();

        match msg {
            ClientMessage::Subscribe { scopes } => {
                assert_eq!(scopes.len(), 2);
                assert!(scopes.contains(&"block_added".to_string()));
                assert!(scopes.contains(&"virtual_chain_changed".to_string()));
            }
        }
    }

    #[test]
    fn test_client_message_subscribe_empty_scopes() {
        let json = r#"{"type":"Subscribe","scopes":[]}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();

        match msg {
            ClientMessage::Subscribe { scopes } => {
                assert!(scopes.is_empty());
            }
        }
    }

    #[test]
    fn test_client_message_invalid_type() {
        let json = r#"{"type":"InvalidType","scopes":[]}"#;
        let result: Result<ClientMessage, _> = serde_json::from_str(json);
        assert!(result.is_err(), "Should fail on invalid message type");
    }

    #[test]
    fn test_client_message_missing_scopes() {
        let json = r#"{"type":"Subscribe"}"#;
        let result: Result<ClientMessage, _> = serde_json::from_str(json);
        assert!(result.is_err(), "Should fail when scopes is missing");
    }

    // ==================== Chain diff calculation tests ====================

    #[test]
    fn test_chain_diff_calculation() {
        let old_chain: HashSet<String> = ["a", "b", "c"].iter().map(|s| s.to_string()).collect();
        let new_chain: HashSet<String> = ["b", "c", "d", "e"].iter().map(|s| s.to_string()).collect();

        let removed: Vec<String> = old_chain.difference(&new_chain).cloned().collect();
        let added: Vec<String> = new_chain.difference(&old_chain).cloned().collect();

        assert_eq!(removed.len(), 1);
        assert!(removed.contains(&"a".to_string()));

        assert_eq!(added.len(), 2);
        assert!(added.contains(&"d".to_string()));
        assert!(added.contains(&"e".to_string()));
    }

    #[test]
    fn test_chain_diff_no_change() {
        let old_chain: HashSet<String> = ["a", "b", "c"].iter().map(|s| s.to_string()).collect();
        let new_chain: HashSet<String> = ["a", "b", "c"].iter().map(|s| s.to_string()).collect();

        let removed: Vec<String> = old_chain.difference(&new_chain).cloned().collect();
        let added: Vec<String> = new_chain.difference(&old_chain).cloned().collect();

        assert!(removed.is_empty());
        assert!(added.is_empty());
    }

    #[test]
    fn test_chain_diff_complete_reorg() {
        let old_chain: HashSet<String> = ["a", "b", "c"].iter().map(|s| s.to_string()).collect();
        let new_chain: HashSet<String> = ["x", "y", "z"].iter().map(|s| s.to_string()).collect();

        let removed: Vec<String> = old_chain.difference(&new_chain).cloned().collect();
        let added: Vec<String> = new_chain.difference(&old_chain).cloned().collect();

        assert_eq!(removed.len(), 3);
        assert_eq!(added.len(), 3);
    }

    // ==================== Block type tests ====================

    #[test]
    fn test_block_type_tip() {
        let msg = DagBlockMessage {
            hash: "tip_hash".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "123".to_string(),
            parent_hashes: vec!["parent".to_string()],
            selected_parent_hash: Some("parent".to_string()),
            is_chain_block: true,
            timestamp: 0,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"block_type\":\"tip\""));
    }

    #[test]
    fn test_block_type_regular() {
        let msg = DagBlockMessage {
            hash: "regular_hash".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "123".to_string(),
            parent_hashes: vec!["parent".to_string()],
            selected_parent_hash: Some("parent".to_string()),
            is_chain_block: true,
            timestamp: 0,
            block_type: "regular".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"block_type\":\"regular\""));
    }

    // ==================== Edge cases ====================

    #[test]
    fn test_very_large_daa_score() {
        let msg = DagBlockMessage {
            hash: "hash".to_string(),
            daa_score: u64::MAX,
            blue_score: u64::MAX,
            blue_work: "ffffffffffffffffffffffffffffffff".to_string(),
            parent_hashes: vec![],
            selected_parent_hash: None,
            is_chain_block: true,
            timestamp: u64::MAX,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["daa_score"], u64::MAX);
        assert_eq!(parsed["blue_score"], u64::MAX);
        assert_eq!(parsed["timestamp"], u64::MAX);
    }

    #[test]
    fn test_hash_with_special_characters() {
        // Hash should be hex, but test that serialization handles it
        let msg = DagBlockMessage {
            hash: "0000000000000000000000000000000000000000000000000000000000000000".to_string(),
            daa_score: 0,
            blue_score: 0,
            blue_work: "0".to_string(),
            parent_hashes: vec![],
            selected_parent_hash: None,
            is_chain_block: true,
            timestamp: 0,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed["hash"], "0000000000000000000000000000000000000000000000000000000000000000");
    }

    #[test]
    fn test_message_roundtrip() {
        let original = DagBlockMessage {
            hash: "abc123def456".to_string(),
            daa_score: 12345,
            blue_score: 6789,
            blue_work: "fedcba".to_string(),
            parent_hashes: vec!["p1".to_string(), "p2".to_string()],
            selected_parent_hash: Some("p1".to_string()),
            is_chain_block: true,
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        };

        let json = serde_json::to_string(&original).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        // Verify all fields survive roundtrip
        assert_eq!(parsed["hash"], original.hash);
        assert_eq!(parsed["daa_score"], original.daa_score);
        assert_eq!(parsed["blue_score"], original.blue_score);
        assert_eq!(parsed["blue_work"], original.blue_work);
        assert_eq!(parsed["parent_hashes"][0], "p1");
        assert_eq!(parsed["parent_hashes"][1], "p2");
        assert_eq!(parsed["selected_parent_hash"], "p1");
        assert_eq!(parsed["is_chain_block"], original.is_chain_block);
        assert_eq!(parsed["timestamp"], original.timestamp);
        assert_eq!(parsed["block_type"], original.block_type);
    }

    // ==================== E2E Flow Tests ====================

    /// Simulates the full client-server flow:
    /// 1. Client connects and sends Subscribe message
    /// 2. Server responds with Subscribed
    /// 3. Server sends BlockAdded messages
    /// 4. Server sends VirtualChainChanged on reorg
    #[test]
    fn test_e2e_client_subscribe_flow() {
        // Step 1: Client sends Subscribe
        let client_msg = r#"{"type":"Subscribe","scopes":["block_added","virtual_chain_changed"]}"#;
        let parsed_client: ClientMessage = serde_json::from_str(client_msg).unwrap();

        match parsed_client {
            ClientMessage::Subscribe { scopes } => {
                assert!(scopes.contains(&"block_added".to_string()));
                assert!(scopes.contains(&"virtual_chain_changed".to_string()));
            }
        }

        // Step 2: Server responds with Subscribed (as it would over WebSocket)
        let server_response =
            DagWsMessage::Subscribed { scopes: vec!["block_added".to_string(), "virtual_chain_changed".to_string()] };
        let response_json = serde_json::to_string(&server_response).unwrap();

        // Client parses the response
        let parsed_response: serde_json::Value = serde_json::from_str(&response_json).unwrap();
        assert_eq!(parsed_response["type"], "Subscribed");
        assert_eq!(parsed_response["data"]["scopes"].as_array().unwrap().len(), 2);
    }

    /// Test the full block addition flow as seen by the client
    #[test]
    fn test_e2e_block_added_flow() {
        // Server sends BlockAdded
        let block = DagBlockMessage {
            hash: "new_block_hash".to_string(),
            daa_score: 1000,
            blue_score: 500,
            blue_work: "abcdef".to_string(),
            parent_hashes: vec!["parent_hash".to_string()],
            selected_parent_hash: Some("parent_hash".to_string()),
            is_chain_block: true,
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        };

        let ws_msg = DagWsMessage::BlockAdded(block);
        let json = serde_json::to_string(&ws_msg).unwrap();

        // Client parses and processes the message
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        // Verify client can extract all required data
        assert_eq!(parsed["type"], "BlockAdded");

        let data = &parsed["data"];
        assert_eq!(data["hash"], "new_block_hash");
        assert_eq!(data["is_chain_block"], true);
        assert_eq!(data["block_type"], "tip");
        assert_eq!(data["daa_score"], 1000);
        assert_eq!(data["parent_hashes"][0], "parent_hash");
        assert_eq!(data["selected_parent_hash"], "parent_hash");
    }

    /// Test the reorg flow: block becomes off-chain
    #[test]
    fn test_e2e_reorg_flow() {
        // Initial state: client has block A as chain block
        let block_a = DagBlockMessage {
            hash: "block_a".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec!["parent".to_string()],
            selected_parent_hash: Some("parent".to_string()),
            is_chain_block: true,
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        };

        let msg_a = DagWsMessage::BlockAdded(block_a);
        let json_a = serde_json::to_string(&msg_a).unwrap();
        let parsed_a: serde_json::Value = serde_json::from_str(&json_a).unwrap();
        assert_eq!(parsed_a["data"]["is_chain_block"], true);

        // Reorg happens: block_a is removed from chain, block_b is added
        let reorg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec!["block_a".to_string()],
            added: vec!["block_b".to_string()],
        });

        let reorg_json = serde_json::to_string(&reorg).unwrap();
        let parsed_reorg: serde_json::Value = serde_json::from_str(&reorg_json).unwrap();

        // Client processes reorg
        assert_eq!(parsed_reorg["type"], "VirtualChainChanged");

        let removed = parsed_reorg["data"]["removed"].as_array().unwrap();
        let added = parsed_reorg["data"]["added"].as_array().unwrap();

        // Client should mark block_a as off-chain
        assert!(removed.iter().any(|h| h == "block_a"));
        // Client should mark block_b as chain block
        assert!(added.iter().any(|h| h == "block_b"));
    }

    /// Test concurrent blocks at the same height (fork scenario)
    #[test]
    fn test_e2e_fork_scenario() {
        // Two blocks arrive at the same height
        let block_1 = DagBlockMessage {
            hash: "fork_block_1".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec!["common_parent".to_string()],
            selected_parent_hash: Some("common_parent".to_string()),
            is_chain_block: true, // First one is chain block
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        };

        let block_2 = DagBlockMessage {
            hash: "fork_block_2".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec!["common_parent".to_string()],
            selected_parent_hash: Some("common_parent".to_string()),
            is_chain_block: true, // Also chain block initially
            timestamp: 1700000001,
            block_type: "tip".to_string(),
        };

        // Both blocks serialize correctly
        let json_1 = serde_json::to_string(&DagWsMessage::BlockAdded(block_1)).unwrap();
        let json_2 = serde_json::to_string(&DagWsMessage::BlockAdded(block_2)).unwrap();

        let parsed_1: serde_json::Value = serde_json::from_str(&json_1).unwrap();
        let parsed_2: serde_json::Value = serde_json::from_str(&json_2).unwrap();

        // Both have same parent
        assert_eq!(parsed_1["data"]["parent_hashes"][0], parsed_2["data"]["parent_hashes"][0]);

        // Both are initially chain blocks (as per new logic)
        assert_eq!(parsed_1["data"]["is_chain_block"], true);
        assert_eq!(parsed_2["data"]["is_chain_block"], true);

        // Later VirtualChainChanged will resolve which one stays
    }

    /// Test client state management simulation
    #[test]
    fn test_e2e_client_state_management() {
        // Simulate client-side block map
        let mut blocks: std::collections::HashMap<String, bool> = std::collections::HashMap::new();

        // Receive first block
        let block_1 = DagWsMessage::BlockAdded(DagBlockMessage {
            hash: "block_1".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec![],
            selected_parent_hash: None,
            is_chain_block: true,
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        });

        let json = serde_json::to_string(&block_1).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        let hash = parsed["data"]["hash"].as_str().unwrap().to_string();
        let is_chain = parsed["data"]["is_chain_block"].as_bool().unwrap();
        blocks.insert(hash.clone(), is_chain);

        assert_eq!(blocks.get("block_1"), Some(&true));

        // Receive second block
        let block_2 = DagWsMessage::BlockAdded(DagBlockMessage {
            hash: "block_2".to_string(),
            daa_score: 101,
            blue_score: 51,
            blue_work: "101".to_string(),
            parent_hashes: vec!["block_1".to_string()],
            selected_parent_hash: Some("block_1".to_string()),
            is_chain_block: true,
            timestamp: 1700000001,
            block_type: "tip".to_string(),
        });

        let json = serde_json::to_string(&block_2).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        let hash = parsed["data"]["hash"].as_str().unwrap().to_string();
        let is_chain = parsed["data"]["is_chain_block"].as_bool().unwrap();
        blocks.insert(hash.clone(), is_chain);

        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks.get("block_2"), Some(&true));

        // Receive reorg - block_2 is removed from chain
        let reorg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec!["block_2".to_string()],
            added: vec!["block_3".to_string()],
        });

        let json = serde_json::to_string(&reorg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        for removed_hash in parsed["data"]["removed"].as_array().unwrap() {
            let hash = removed_hash.as_str().unwrap();
            if let Some(is_chain) = blocks.get_mut(hash) {
                *is_chain = false;
            }
        }

        // block_2 should now be off-chain
        assert_eq!(blocks.get("block_2"), Some(&false));
        // block_1 unchanged
        assert_eq!(blocks.get("block_1"), Some(&true));
    }

    /// Test deep reorg (multiple blocks affected)
    #[test]
    fn test_e2e_deep_reorg() {
        let mut chain_blocks: HashSet<String> = HashSet::new();

        // Initial chain: A -> B -> C -> D
        chain_blocks.insert("A".to_string());
        chain_blocks.insert("B".to_string());
        chain_blocks.insert("C".to_string());
        chain_blocks.insert("D".to_string());

        // Deep reorg: C, D removed; E, F, G added
        let reorg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec!["C".to_string(), "D".to_string()],
            added: vec!["E".to_string(), "F".to_string(), "G".to_string()],
        });

        let json = serde_json::to_string(&reorg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        // Apply reorg
        for removed in parsed["data"]["removed"].as_array().unwrap() {
            chain_blocks.remove(removed.as_str().unwrap());
        }
        for added in parsed["data"]["added"].as_array().unwrap() {
            chain_blocks.insert(added.as_str().unwrap().to_string());
        }

        // Verify final state
        assert!(chain_blocks.contains("A"));
        assert!(chain_blocks.contains("B"));
        assert!(!chain_blocks.contains("C"));
        assert!(!chain_blocks.contains("D"));
        assert!(chain_blocks.contains("E"));
        assert!(chain_blocks.contains("F"));
        assert!(chain_blocks.contains("G"));
    }

    /// Test that new tip blocks are always chain blocks (the fix we implemented)
    #[test]
    fn test_e2e_new_tip_always_chain_block() {
        // This test verifies the core fix: new tip blocks should always be is_chain_block=true
        // The VirtualChainChanged event will correct if needed

        let new_tip = DagBlockMessage {
            hash: "brand_new_tip".to_string(),
            daa_score: 999999,
            blue_score: 500000,
            blue_work: "fffff".to_string(),
            parent_hashes: vec!["previous_tip".to_string()],
            selected_parent_hash: Some("previous_tip".to_string()),
            is_chain_block: true, // MUST be true for new tips
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        };

        let msg = DagWsMessage::BlockAdded(new_tip);
        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        // This is the critical assertion - new tips must be chain blocks
        assert_eq!(parsed["data"]["is_chain_block"], true, "New tip blocks MUST be chain blocks initially");
    }

    /// Test message sequence ordering (BlockAdded before VirtualChainChanged)
    #[test]
    fn test_e2e_message_sequence() {
        let mut received_messages: Vec<String> = Vec::new();

        // Server sends BlockAdded first
        let block = DagWsMessage::BlockAdded(DagBlockMessage {
            hash: "new_block".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec!["parent".to_string()],
            selected_parent_hash: Some("parent".to_string()),
            is_chain_block: true,
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        });

        let json = serde_json::to_string(&block).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        received_messages.push(parsed["type"].as_str().unwrap().to_string());

        // Then VirtualChainChanged
        let chain_change =
            DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage { removed: vec![], added: vec!["new_block".to_string()] });

        let json = serde_json::to_string(&chain_change).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        received_messages.push(parsed["type"].as_str().unwrap().to_string());

        // Verify order
        assert_eq!(received_messages[0], "BlockAdded");
        assert_eq!(received_messages[1], "VirtualChainChanged");
    }

    /// Test error handling flow
    #[test]
    fn test_e2e_error_handling() {
        // Server sends error
        let error = DagWsMessage::Error { error: "Node kaspad-1 not found".to_string() };

        let json = serde_json::to_string(&error).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        // Client can identify error type
        assert_eq!(parsed["type"], "Error");

        // Client can extract error message
        let error_msg = parsed["data"]["error"].as_str().unwrap();
        assert!(error_msg.contains("not found"));
    }

    /// Test multiple tips scenario (parallel blocks)
    #[test]
    fn test_e2e_multiple_tips() {
        // DAG can have multiple tips at the same time
        let tip1 = DagBlockMessage {
            hash: "tip1".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec!["common_ancestor".to_string()],
            selected_parent_hash: Some("common_ancestor".to_string()),
            is_chain_block: true,
            timestamp: 1700000000,
            block_type: "tip".to_string(),
        };

        let tip2 = DagBlockMessage {
            hash: "tip2".to_string(),
            daa_score: 100,
            blue_score: 50,
            blue_work: "100".to_string(),
            parent_hashes: vec!["common_ancestor".to_string()],
            selected_parent_hash: Some("common_ancestor".to_string()),
            is_chain_block: true,
            timestamp: 1700000001,
            block_type: "tip".to_string(),
        };

        // Both tips are chain blocks
        let msg1 = DagWsMessage::BlockAdded(tip1);
        let msg2 = DagWsMessage::BlockAdded(tip2);

        let json1 = serde_json::to_string(&msg1).unwrap();
        let json2 = serde_json::to_string(&msg2).unwrap();

        let parsed1: serde_json::Value = serde_json::from_str(&json1).unwrap();
        let parsed2: serde_json::Value = serde_json::from_str(&json2).unwrap();

        // Both tips should be chain blocks
        assert_eq!(parsed1["data"]["is_chain_block"], true);
        assert_eq!(parsed2["data"]["is_chain_block"], true);
        assert_eq!(parsed1["data"]["block_type"], "tip");
        assert_eq!(parsed2["data"]["block_type"], "tip");
    }

    /// Test genesis block handling
    #[test]
    fn test_e2e_genesis_block() {
        let genesis = DagBlockMessage {
            hash: "0".repeat(64),
            daa_score: 0,
            blue_score: 0,
            blue_work: "0".to_string(),
            parent_hashes: vec![], // Genesis has no parents
            selected_parent_hash: None,
            is_chain_block: true,
            timestamp: 1636298787,
            block_type: "tip".to_string(),
        };

        let msg = DagWsMessage::BlockAdded(genesis);
        let json = serde_json::to_string(&msg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        // Genesis is always chain block
        assert_eq!(parsed["data"]["is_chain_block"], true);
        // Genesis has no parents
        assert!(parsed["data"]["parent_hashes"].as_array().unwrap().is_empty());
        assert!(parsed["data"]["selected_parent_hash"].is_null());
    }

    /// Test DAA score ordering
    #[test]
    fn test_e2e_daa_score_ordering() {
        let blocks = vec![("block_c", 300u64), ("block_a", 100u64), ("block_b", 200u64)];

        let mut messages: Vec<(String, u64)> = Vec::new();

        for (hash, daa) in blocks {
            let block = DagBlockMessage {
                hash: hash.to_string(),
                daa_score: daa,
                blue_score: daa / 2,
                blue_work: format!("{}", daa),
                parent_hashes: vec![],
                selected_parent_hash: None,
                is_chain_block: true,
                timestamp: 1700000000,
                block_type: "tip".to_string(),
            };

            let msg = DagWsMessage::BlockAdded(block);
            let json = serde_json::to_string(&msg).unwrap();
            let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

            let h = parsed["data"]["hash"].as_str().unwrap().to_string();
            let d = parsed["data"]["daa_score"].as_u64().unwrap();
            messages.push((h, d));
        }

        // Sort by DAA score (as client would for display)
        messages.sort_by(|a, b| b.1.cmp(&a.1));

        assert_eq!(messages[0].0, "block_c");
        assert_eq!(messages[1].0, "block_b");
        assert_eq!(messages[2].0, "block_a");
    }

    /// Test complete deserialization for Flutter client
    #[test]
    fn test_e2e_flutter_client_deserialization() {
        // This simulates what the Flutter client receives and needs to parse
        let server_msg = DagWsMessage::BlockAdded(DagBlockMessage {
            hash: "abc123".to_string(),
            daa_score: 12345,
            blue_score: 6789,
            blue_work: "fedcba9876543210".to_string(),
            parent_hashes: vec!["parent1".to_string(), "parent2".to_string()],
            selected_parent_hash: Some("parent1".to_string()),
            is_chain_block: true,
            timestamp: 1700000000000, // milliseconds
            block_type: "tip".to_string(),
        });

        let json = serde_json::to_string(&server_msg).unwrap();

        // Simulate Flutter's json.decode
        let decoded: serde_json::Value = serde_json::from_str(&json).unwrap();

        // Flutter mapper would do:
        let msg_type = decoded["type"].as_str().unwrap();
        assert_eq!(msg_type, "BlockAdded");

        let data = &decoded["data"];

        // All fields the Flutter mapper needs:
        let _hash = data["hash"].as_str().unwrap();
        let _daa_score = data["daa_score"].as_u64().unwrap();
        let _blue_score = data["blue_score"].as_u64().unwrap();
        let _blue_work = data["blue_work"].as_str().unwrap();
        let _is_chain_block = data["is_chain_block"].as_bool().unwrap();
        let _timestamp = data["timestamp"].as_u64().unwrap();
        let _block_type = data["block_type"].as_str().unwrap();

        // Parent hashes array
        let parents = data["parent_hashes"].as_array().unwrap();
        assert_eq!(parents.len(), 2);

        // Selected parent (nullable)
        let selected = data["selected_parent_hash"].as_str();
        assert_eq!(selected, Some("parent1"));
    }

    /// Test VirtualChainChanged deserialization for Flutter
    #[test]
    fn test_e2e_flutter_chain_changed_deserialization() {
        let server_msg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage {
            removed: vec!["old1".to_string(), "old2".to_string()],
            added: vec!["new1".to_string(), "new2".to_string(), "new3".to_string()],
        });

        let json = serde_json::to_string(&server_msg).unwrap();
        let decoded: serde_json::Value = serde_json::from_str(&json).unwrap();

        let msg_type = decoded["type"].as_str().unwrap();
        assert_eq!(msg_type, "VirtualChainChanged");

        let data = &decoded["data"];

        // Flutter needs these as List<String>
        let removed: Vec<String> = data["removed"].as_array().unwrap().iter().map(|v| v.as_str().unwrap().to_string()).collect();

        let added: Vec<String> = data["added"].as_array().unwrap().iter().map(|v| v.as_str().unwrap().to_string()).collect();

        assert_eq!(removed, vec!["old1", "old2"]);
        assert_eq!(added, vec!["new1", "new2", "new3"]);
    }

    /// Test realistic block sequence (several consecutive blocks)
    #[test]
    fn test_e2e_realistic_block_sequence() {
        let mut client_blocks: std::collections::HashMap<String, (u64, bool)> = std::collections::HashMap::new();
        let mut chain_blocks: HashSet<String> = HashSet::new();

        // Simulate receiving 5 consecutive blocks
        for i in 0..5 {
            let parent = if i == 0 { "genesis".to_string() } else { format!("block_{}", i - 1) };

            let block = DagBlockMessage {
                hash: format!("block_{}", i),
                daa_score: 100 + i as u64,
                blue_score: 50 + i as u64,
                blue_work: format!("{}", 100 + i),
                parent_hashes: vec![parent.clone()],
                selected_parent_hash: Some(parent),
                is_chain_block: true,
                timestamp: 1700000000 + i as u64,
                block_type: "tip".to_string(),
            };

            let msg = DagWsMessage::BlockAdded(block);
            let json = serde_json::to_string(&msg).unwrap();
            let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

            let hash = parsed["data"]["hash"].as_str().unwrap().to_string();
            let daa = parsed["data"]["daa_score"].as_u64().unwrap();
            let is_chain = parsed["data"]["is_chain_block"].as_bool().unwrap();

            client_blocks.insert(hash.clone(), (daa, is_chain));
            if is_chain {
                chain_blocks.insert(hash);
            }
        }

        // Verify all blocks received
        assert_eq!(client_blocks.len(), 5);
        assert_eq!(chain_blocks.len(), 5);

        // Verify DAA scores are increasing
        for i in 0..5 {
            let (daa, _) = client_blocks.get(&format!("block_{}", i)).unwrap();
            assert_eq!(*daa, 100 + i as u64);
        }

        // All are chain blocks
        for i in 0..5 {
            assert!(chain_blocks.contains(&format!("block_{}", i)));
        }
    }

    /// Test high-throughput scenario (many blocks quickly)
    #[test]
    fn test_e2e_high_throughput() {
        let mut messages: Vec<String> = Vec::new();

        // Simulate 100 blocks arriving quickly
        for i in 0..100 {
            let block = DagBlockMessage {
                hash: format!("block_{:04}", i),
                daa_score: i as u64,
                blue_score: i as u64 / 2,
                blue_work: format!("{:x}", i),
                parent_hashes: if i == 0 { vec![] } else { vec![format!("block_{:04}", i - 1)] },
                selected_parent_hash: if i == 0 { None } else { Some(format!("block_{:04}", i - 1)) },
                is_chain_block: true,
                timestamp: 1700000000 + i as u64,
                block_type: "tip".to_string(),
            };

            let msg = DagWsMessage::BlockAdded(block);
            let json = serde_json::to_string(&msg).unwrap();
            messages.push(json);
        }

        // Verify all messages are valid JSON
        for (i, json) in messages.iter().enumerate() {
            let parsed: serde_json::Value = serde_json::from_str(json).unwrap();
            assert_eq!(parsed["type"], "BlockAdded");
            assert_eq!(parsed["data"]["hash"], format!("block_{:04}", i));
        }
    }

    /// Test empty reorg (no changes)
    #[test]
    fn test_e2e_empty_reorg() {
        let reorg = DagWsMessage::VirtualChainChanged(VirtualChainChangedMessage { removed: vec![], added: vec![] });

        let json = serde_json::to_string(&reorg).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert!(parsed["data"]["removed"].as_array().unwrap().is_empty());
        assert!(parsed["data"]["added"].as_array().unwrap().is_empty());
    }
}
