use axum::extract::{Path, Query, State};
use axum::Json;
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::api::rpc::RpcApi;
use serde::Deserialize;
use std::time::Duration;
use tracing::{debug, warn};

use crate::api::dto::{DagBlockResponse, DagBlocksResponse, DagInfoResponse};
use crate::api::AppState;
use crate::error::{ControllerError, Result};

/// Query parameters for getting blocks
#[derive(Debug, Deserialize)]
pub struct GetBlocksQuery {
    #[serde(default = "default_limit")]
    pub limit: usize,
    pub from_daa_score: Option<u64>,
}

fn default_limit() -> usize {
    100
}

/// Maximum blocks to return in a single request
const MAX_BLOCKS: usize = 200;
/// Timeout for gRPC calls
const GRPC_TIMEOUT: Duration = Duration::from_secs(10);

/// Get gRPC client for a node
async fn get_node_client(state: &AppState, node_id: &str) -> Result<GrpcClient> {
    let (container_name, grpc_port) = {
        let cluster_state = state.cluster_state.read();
        cluster_state
            .nodes
            .get(node_id)
            .map(|n| (n.container_name.clone(), n.grpc_port))
            .ok_or_else(|| ControllerError::NodeNotFound(node_id.to_string()))?
    };

    // Use container name for DNS resolution within Docker network
    let grpc_url = format!("grpc://{}:{}", container_name, grpc_port);
    debug!("Connecting to node {} at {}", node_id, grpc_url);

    let client = tokio::time::timeout(GRPC_TIMEOUT, GrpcClient::connect(grpc_url.clone()))
        .await
        .map_err(|_| ControllerError::Grpc(format!("Connection timeout to {}", grpc_url)))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    Ok(client)
}

/// GET /api/v1/nodes/:id/dag
/// Get DAG info for a node
pub async fn get_dag_info(State(state): State<AppState>, Path(node_id): Path<String>) -> Result<Json<DagInfoResponse>> {
    let client = get_node_client(&state, &node_id).await?;

    let dag_info = tokio::time::timeout(GRPC_TIMEOUT, client.get_block_dag_info())
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting DAG info".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    let tip_hashes: Vec<String> = dag_info.tip_hashes.iter().map(|h| h.to_string()).collect();
    let sink_hash = dag_info.sink.to_string();

    // Disconnect client
    let _ = client.disconnect().await;

    Ok(Json(DagInfoResponse {
        tip_hashes,
        sink_hash,
        pruning_point_hash: dag_info.pruning_point_hash.to_string(),
        virtual_daa_score: dag_info.virtual_daa_score,
        block_count: dag_info.block_count,
        difficulty: dag_info.difficulty,
    }))
}

/// GET /api/v1/nodes/:id/dag/blocks
/// Get recent blocks from DAG
pub async fn get_blocks(
    State(state): State<AppState>,
    Path(node_id): Path<String>,
    Query(query): Query<GetBlocksQuery>,
) -> Result<Json<DagBlocksResponse>> {
    let limit = query.limit.min(MAX_BLOCKS);
    let client = get_node_client(&state, &node_id).await?;

    // Get DAG info to find tips
    let dag_info = tokio::time::timeout(GRPC_TIMEOUT, client.get_block_dag_info())
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting DAG info".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    // Get virtual chain from pruning point
    // TODO: In future, use from_daa_score to find a specific starting block
    let low_hash = dag_info.pruning_point_hash;
    let _ = query.from_daa_score; // Acknowledge unused parameter

    let chain = tokio::time::timeout(GRPC_TIMEOUT, client.get_virtual_chain_from_block(low_hash, true, None))
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting virtual chain".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    // Get the most recent blocks from the chain
    let block_hashes: Vec<_> = chain.added_chain_block_hashes.iter().rev().take(limit).cloned().collect();

    let mut blocks = Vec::with_capacity(block_hashes.len());

    // Fetch block details
    for hash in block_hashes {
        match tokio::time::timeout(GRPC_TIMEOUT, client.get_block(hash, true)).await {
            Ok(Ok(block)) => {
                let header = &block.header;

                // Determine block type
                let block_type = if dag_info.tip_hashes.contains(&hash) {
                    "tip"
                } else if hash == dag_info.sink {
                    "sink"
                } else {
                    "regular"
                };

                // Check if block is in the virtual chain (chain block = blue)
                let is_chain_block = chain.added_chain_block_hashes.contains(&hash);

                blocks.push(DagBlockResponse {
                    hash: hash.to_string(),
                    daa_score: header.daa_score,
                    blue_score: header.blue_score,
                    blue_work: header.blue_work.to_string(),
                    parent_hashes: header
                        .parents_by_level
                        .first()
                        .map(|parents| parents.iter().map(|h| h.to_string()).collect())
                        .unwrap_or_default(),
                    children_hashes: vec![], // Children are computed by Flutter client
                    selected_parent_hash: header.parents_by_level.first().and_then(|parents| parents.first()).map(|h| h.to_string()),
                    merge_set_blues: vec![], // Not available from basic RPC
                    merge_set_reds: vec![],
                    is_chain_block,
                    timestamp: header.timestamp,
                    block_type: block_type.to_string(),
                });
            }
            Ok(Err(e)) => {
                warn!("Failed to get block {}: {}", hash, e);
            }
            Err(_) => {
                warn!("Timeout getting block {}", hash);
            }
        }
    }

    // Disconnect client
    let _ = client.disconnect().await;

    Ok(Json(DagBlocksResponse { blocks }))
}

/// GET /api/v1/nodes/:id/dag/blocks/:hash
/// Get a specific block by hash
pub async fn get_block(
    State(state): State<AppState>,
    Path((node_id, hash)): Path<(String, String)>,
) -> Result<Json<DagBlockResponse>> {
    let client = get_node_client(&state, &node_id).await?;

    // Parse hash
    let block_hash: kaspa_hashes::Hash =
        hash.parse().map_err(|_| ControllerError::InvalidConfig(format!("Invalid block hash: {}", hash)))?;

    // Get DAG info for context
    let dag_info = tokio::time::timeout(GRPC_TIMEOUT, client.get_block_dag_info())
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting DAG info".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    // Get block
    let block = tokio::time::timeout(GRPC_TIMEOUT, client.get_block(block_hash, true))
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting block".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    let header = &block.header;

    // Determine block type
    let block_type = if dag_info.tip_hashes.contains(&block_hash) {
        "tip"
    } else if block_hash == dag_info.sink {
        "sink"
    } else {
        "regular"
    };

    // Get virtual chain to check if block is chain block
    let chain = tokio::time::timeout(GRPC_TIMEOUT, client.get_virtual_chain_from_block(dag_info.pruning_point_hash, true, None))
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting virtual chain".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    let is_chain_block = chain.added_chain_block_hashes.contains(&block_hash);

    // Disconnect client
    let _ = client.disconnect().await;

    Ok(Json(DagBlockResponse {
        hash: block_hash.to_string(),
        daa_score: header.daa_score,
        blue_score: header.blue_score,
        blue_work: header.blue_work.to_string(),
        parent_hashes: header
            .parents_by_level
            .first()
            .map(|parents| parents.iter().map(|h| h.to_string()).collect())
            .unwrap_or_default(),
        children_hashes: vec![],
        selected_parent_hash: header.parents_by_level.first().and_then(|parents| parents.first()).map(|h| h.to_string()),
        merge_set_blues: vec![],
        merge_set_reds: vec![],
        is_chain_block,
        timestamp: header.timestamp,
        block_type: block_type.to_string(),
    }))
}
