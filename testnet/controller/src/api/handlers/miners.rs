use axum::extract::{Path, State};
use axum::Json;
use kaspa_addresses::Address;
use tracing::info;
use uuid::Uuid;

use crate::api::dto::{CreateMinerRequest, CreateMinerResponse, MinerSummaryResponse, SuccessResponse};
use crate::api::AppState;
use crate::error::{ControllerError, Result};

const MAX_NAME_LENGTH: usize = 64;
const MAX_THREADS: u8 = 128;
const MIN_TARGET_BPS: f64 = 0.1;
const MAX_TARGET_BPS: f64 = 100.0;
/// Maximum number of miners to prevent resource exhaustion
const MAX_MINERS: usize = 100;

/// GET /api/v1/miners
/// Returns list of all miners
pub async fn list_miners(State(state): State<AppState>) -> Result<Json<Vec<MinerSummaryResponse>>> {
    let cluster_state = state.cluster_state.read();

    let miners: Vec<MinerSummaryResponse> = cluster_state.miners.values().cloned().map(MinerSummaryResponse::from).collect();

    Ok(Json(miners))
}

/// GET /api/v1/miners/:id
/// Returns a single miner by ID
pub async fn get_miner(State(state): State<AppState>, Path(miner_id): Path<String>) -> Result<Json<MinerSummaryResponse>> {
    let cluster_state = state.cluster_state.read();

    let miner = cluster_state.miners.get(&miner_id).cloned().ok_or_else(|| ControllerError::MinerNotFound(miner_id))?;

    Ok(Json(MinerSummaryResponse::from(miner)))
}

/// POST /api/v1/miners
/// Create a new miner
pub async fn create_miner(
    State(state): State<AppState>,
    Json(request): Json<CreateMinerRequest>,
) -> Result<Json<CreateMinerResponse>> {
    // Check miner limit to prevent resource exhaustion
    {
        let cluster_state = state.cluster_state.read();
        if cluster_state.miners.len() >= MAX_MINERS {
            return Err(ControllerError::InvalidConfig(format!("Maximum number of miners ({}) reached", MAX_MINERS)));
        }
    }

    // Validate payout address (mask in error for security)
    let _address: Address = request.payout_address.as_str().try_into().map_err(|_| {
        let addr = &request.payout_address;
        // Use chars() for UTF-8 safe slicing to prevent panic on multibyte characters
        let masked = if addr.chars().count() > 16 {
            let prefix: String = addr.chars().take(8).collect();
            let suffix: String = addr.chars().rev().take(4).collect::<String>().chars().rev().collect();
            format!("{}...{}", prefix, suffix)
        } else {
            "***".to_string()
        };
        ControllerError::InvalidConfig(format!("Invalid payout address: {}", masked))
    })?;

    // Validate threads
    if request.threads == 0 || request.threads > MAX_THREADS {
        return Err(ControllerError::InvalidConfig(format!("Threads must be between 1 and {}", MAX_THREADS)));
    }

    // Validate target_bps (check for NaN/Infinity which bypass normal comparisons)
    if let Some(bps) = request.target_bps {
        if !bps.is_finite() {
            return Err(ControllerError::InvalidConfig("Target BPS must be a finite number".to_string()));
        }
        if !(MIN_TARGET_BPS..=MAX_TARGET_BPS).contains(&bps) {
            return Err(ControllerError::InvalidConfig(format!(
                "Target BPS must be between {} and {}",
                MIN_TARGET_BPS, MAX_TARGET_BPS
            )));
        }
    }

    // Generate name if not provided
    let name = request.name.unwrap_or_else(|| {
        let suffix = Uuid::new_v4().to_string()[..8].to_string();
        format!("miner-{}", suffix)
    });

    // Validate name length
    if name.len() > MAX_NAME_LENGTH {
        return Err(ControllerError::InvalidConfig(format!("Name must be {} characters or less", MAX_NAME_LENGTH)));
    }

    // Validate name characters (alphanumeric and hyphens only)
    if !name.chars().all(|c| c.is_alphanumeric() || c == '-') {
        return Err(ControllerError::InvalidConfig("Name must contain only alphanumeric characters and hyphens".to_string()));
    }

    // Get target node gRPC URL
    // Note: There's a small race window between reading the node info and creating
    // the miner container. If the node is deleted in this window, the miner will
    // be created but fail to connect. This is acceptable as the miner will report
    // connection errors and admin can take appropriate action.
    let target_grpc = {
        let cluster_state = state.cluster_state.read();
        let node =
            cluster_state.nodes.get(&request.target_node).ok_or_else(|| ControllerError::NodeNotFound(request.target_node.clone()))?;

        // Validate node.name is safe for URL construction (prevents URL injection)
        // Node names should only contain alphanumeric chars and hyphens
        if !node.name.chars().all(|c| c.is_alphanumeric() || c == '-') {
            return Err(ControllerError::InvalidConfig(format!("Node name contains invalid characters: {}", node.name)));
        }

        format!("grpc://{}:{}", node.name, node.grpc_port)
    };

    info!("Creating miner {} targeting {} with {} threads", name, target_grpc, request.threads);

    // Create container
    let container =
        state.docker.create_miner(&name, &target_grpc, &request.payout_address, request.threads, request.target_bps).await?;

    // Add miner to cluster state immediately for responsive UI
    // (polling will update status/hashrate when container starts)
    {
        let mut cluster_state = state.cluster_state.write();
        cluster_state.miners.insert(
            container.id.clone(),
            crate::state::MinerState {
                id: container.id.clone(),
                name: container.name.clone(),
                container_name: container.container_name.clone(),
                status: "created".to_string(),
                target_node: container.target_node.clone(),
                stats_port: container.stats_port,
                hashrate: 0.0,
                blocks_found: 0,
            },
        );
    }

    Ok(Json(CreateMinerResponse { id: container.id, name: container.name }))
}

/// DELETE /api/v1/miners/:id
/// Remove a miner
pub async fn delete_miner(State(state): State<AppState>, Path(miner_id): Path<String>) -> Result<Json<SuccessResponse>> {
    // Remove container from Docker
    let removal_result = state.docker.remove_container(&miner_id).await;

    // Update cluster state regardless of removal result if container no longer exists
    // This prevents stale miners from appearing in UI after deletion
    let should_remove_from_state = match &removal_result {
        Ok(_) => true,
        Err(_) => {
            // On error, check if container still exists
            state.docker.get_container(&miner_id).await.is_err()
        }
    };

    if should_remove_from_state {
        let mut cluster_state = state.cluster_state.write();
        cluster_state.miners.remove(&miner_id);
    }

    // Propagate any removal error after state cleanup
    removal_result?;

    info!("Removed miner {}", miner_id);
    Ok(Json(SuccessResponse::ok(format!("Miner {} removed", miner_id))))
}

/// POST /api/v1/miners/:id/start
/// Start a miner
pub async fn start_miner(State(state): State<AppState>, Path(miner_id): Path<String>) -> Result<Json<SuccessResponse>> {
    state.docker.start_container(&miner_id).await?;
    info!("Started miner {}", miner_id);
    Ok(Json(SuccessResponse::ok(format!("Miner {} started", miner_id))))
}

/// POST /api/v1/miners/:id/stop
/// Stop a miner
pub async fn stop_miner(State(state): State<AppState>, Path(miner_id): Path<String>) -> Result<Json<SuccessResponse>> {
    state.docker.stop_container(&miner_id).await?;
    info!("Stopped miner {}", miner_id);
    Ok(Json(SuccessResponse::ok(format!("Miner {} stopped", miner_id))))
}
