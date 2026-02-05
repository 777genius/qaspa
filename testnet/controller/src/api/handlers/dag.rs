use axum::Json;
use axum::extract::{Path, Query, State};
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::api::rpc::RpcApi;
use serde::Deserialize;
use std::time::Duration;
use tracing::debug;

use crate::api::AppState;
use crate::api::dto::{DagBlockResponse, DagBlocksResponse, DagInfoResponse};
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

    // Use localhost in local mode, Docker container name otherwise
    let host = if state.config.local_mode { "localhost" } else { container_name.as_str() };
    let grpc_url = format!("grpc://{}:{}", host, grpc_port);
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
/// Uses get_blocks RPC which returns ALL blocks (chain + off-chain/anticone)
/// with correct is_chain_block flag from consensus
pub async fn get_blocks(
    State(state): State<AppState>,
    Path(node_id): Path<String>,
    Query(query): Query<GetBlocksQuery>,
) -> Result<Json<DagBlocksResponse>> {
    let limit = query.limit.min(MAX_BLOCKS);
    let client = get_node_client(&state, &node_id).await?;

    // Get DAG info to find tips and sink
    let dag_info = tokio::time::timeout(GRPC_TIMEOUT, client.get_block_dag_info())
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting DAG info".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    // Determine starting point for block retrieval
    let low_hash = if let Some(from_daa) = query.from_daa_score {
        // Find a block near the requested DAA score using virtual chain
        let chain = tokio::time::timeout(GRPC_TIMEOUT, client.get_virtual_chain_from_block(dag_info.pruning_point_hash, false, None))
            .await
            .map_err(|_| ControllerError::Grpc("Timeout getting virtual chain".to_string()))?
            .map_err(|e| ControllerError::Grpc(e.to_string()))?;

        // Find first block at or above requested DAA score
        let mut found_hash = dag_info.pruning_point_hash;
        for hash in chain.added_chain_block_hashes.iter() {
            match tokio::time::timeout(GRPC_TIMEOUT, client.get_block(*hash, false)).await {
                Ok(Ok(block)) => {
                    if block.header.daa_score >= from_daa {
                        found_hash = *hash;
                        break;
                    }
                }
                _ => continue,
            }
        }
        found_hash
    } else {
        dag_info.pruning_point_hash
    };

    // Use get_blocks RPC - returns ALL blocks (chain + anticone/off-chain)
    // with verbose_data containing correct is_chain_block from consensus
    let response = tokio::time::timeout(GRPC_TIMEOUT, client.get_blocks(Some(low_hash), true, false))
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting blocks".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    // Process blocks - take most recent ones (reverse order and limit)
    let mut blocks = Vec::with_capacity(limit);

    for rpc_block in response.blocks.iter().rev().take(limit) {
        let header = &rpc_block.header;
        let hash = header.hash;

        // Get verbose data which contains is_chain_block from consensus
        let verbose_data = rpc_block.verbose_data.as_ref();

        // Determine block type
        let block_type = if dag_info.tip_hashes.contains(&hash) {
            "tip"
        } else if hash == dag_info.sink {
            "sink"
        } else {
            "regular"
        };

        // is_chain_block comes from consensus via verbose_data
        let is_chain_block = verbose_data.map(|v| v.is_chain_block).unwrap_or(false);

        // selected_parent_hash from verbose_data (correct GHOSTDAG selected parent)
        let selected_parent_hash = verbose_data.map(|v| v.selected_parent_hash.to_string());

        // children_hashes from verbose_data
        let children_hashes: Vec<String> =
            verbose_data.map(|v| v.children_hashes.iter().map(|h| h.to_string()).collect()).unwrap_or_default();

        // merge sets from verbose_data
        let merge_set_blues: Vec<String> =
            verbose_data.map(|v| v.merge_set_blues_hashes.iter().map(|h| h.to_string()).collect()).unwrap_or_default();
        let merge_set_reds: Vec<String> =
            verbose_data.map(|v| v.merge_set_reds_hashes.iter().map(|h| h.to_string()).collect()).unwrap_or_default();

        // blue_score from verbose_data (more accurate than header)
        let blue_score = verbose_data.map(|v| v.blue_score).unwrap_or(header.blue_score);

        blocks.push(DagBlockResponse {
            hash: hash.to_string(),
            daa_score: header.daa_score,
            blue_score,
            blue_work: header.blue_work.to_string(),
            parent_hashes: header
                .parents_by_level
                .first()
                .map(|parents| parents.iter().map(|h| h.to_string()).collect())
                .unwrap_or_default(),
            children_hashes,
            selected_parent_hash,
            merge_set_blues,
            merge_set_reds,
            is_chain_block,
            timestamp: header.timestamp,
            block_type: block_type.to_string(),
        });
    }

    // Disconnect client
    let _ = client.disconnect().await;

    Ok(Json(DagBlocksResponse { blocks }))
}

/// GET /api/v1/nodes/:id/dag/blocks/:hash
/// Get a specific block by hash
/// Uses verbose_data for is_chain_block from consensus
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

    // Get block with verbose data (include_transactions=true to get verbose_data)
    let block = tokio::time::timeout(GRPC_TIMEOUT, client.get_block(block_hash, true))
        .await
        .map_err(|_| ControllerError::Grpc("Timeout getting block".to_string()))?
        .map_err(|e| ControllerError::Grpc(e.to_string()))?;

    let header = &block.header;
    let verbose_data = block.verbose_data.as_ref();

    // Determine block type
    let block_type = if dag_info.tip_hashes.contains(&block_hash) {
        "tip"
    } else if block_hash == dag_info.sink {
        "sink"
    } else {
        "regular"
    };

    // is_chain_block comes from consensus via verbose_data
    let is_chain_block = verbose_data.map(|v| v.is_chain_block).unwrap_or(false);

    // selected_parent_hash from verbose_data (correct GHOSTDAG selected parent)
    let selected_parent_hash = verbose_data.map(|v| v.selected_parent_hash.to_string());

    // children_hashes from verbose_data
    let children_hashes: Vec<String> =
        verbose_data.map(|v| v.children_hashes.iter().map(|h| h.to_string()).collect()).unwrap_or_default();

    // merge sets from verbose_data
    let merge_set_blues: Vec<String> =
        verbose_data.map(|v| v.merge_set_blues_hashes.iter().map(|h| h.to_string()).collect()).unwrap_or_default();
    let merge_set_reds: Vec<String> =
        verbose_data.map(|v| v.merge_set_reds_hashes.iter().map(|h| h.to_string()).collect()).unwrap_or_default();

    // blue_score from verbose_data
    let blue_score = verbose_data.map(|v| v.blue_score).unwrap_or(header.blue_score);

    // Disconnect client
    let _ = client.disconnect().await;

    Ok(Json(DagBlockResponse {
        hash: block_hash.to_string(),
        daa_score: header.daa_score,
        blue_score,
        blue_work: header.blue_work.to_string(),
        parent_hashes: header
            .parents_by_level
            .first()
            .map(|parents| parents.iter().map(|h| h.to_string()).collect())
            .unwrap_or_default(),
        children_hashes,
        selected_parent_hash,
        merge_set_blues,
        merge_set_reds,
        is_chain_block,
        timestamp: header.timestamp,
        block_type: block_type.to_string(),
    }))
}
