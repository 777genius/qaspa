use axum::Json;
use axum::extract::{Path, State};
use tracing::info;
use uuid::Uuid;

use crate::api::AppState;
use crate::api::dto::{CreateNodeRequest, CreateNodeResponse, NodePortsResponse, NodeSummaryResponse, SuccessResponse};
use crate::error::{ControllerError, Result};

const MAX_NAME_LENGTH: usize = 64;
/// Maximum number of nodes to prevent resource exhaustion
const MAX_NODES: usize = 100;

/// GET /api/v1/nodes
/// Returns list of all nodes
pub async fn list_nodes(State(state): State<AppState>) -> Result<Json<Vec<NodeSummaryResponse>>> {
    let cluster_state = state.cluster_state.read();

    let nodes: Vec<NodeSummaryResponse> = cluster_state.nodes.values().cloned().map(NodeSummaryResponse::from).collect();

    Ok(Json(nodes))
}

/// GET /api/v1/nodes/:id
/// Returns a single node by ID
pub async fn get_node(State(state): State<AppState>, Path(node_id): Path<String>) -> Result<Json<NodeSummaryResponse>> {
    let cluster_state = state.cluster_state.read();

    let node = cluster_state.nodes.get(&node_id).cloned().ok_or_else(|| ControllerError::NodeNotFound(node_id))?;

    Ok(Json(NodeSummaryResponse::from(node)))
}

/// POST /api/v1/nodes
/// Create a new node
pub async fn create_node(State(state): State<AppState>, Json(request): Json<CreateNodeRequest>) -> Result<Json<CreateNodeResponse>> {
    // Check node limit to prevent resource exhaustion
    {
        let cluster_state = state.cluster_state.read();
        if cluster_state.nodes.len() >= MAX_NODES {
            return Err(ControllerError::InvalidConfig(format!("Maximum number of nodes ({}) reached", MAX_NODES)));
        }
    }

    // Generate name if not provided
    let name = request.name.unwrap_or_else(|| {
        let suffix = Uuid::new_v4().to_string()[..8].to_string();
        format!("peer-{}", suffix)
    });

    // Validate name length
    if name.len() > MAX_NAME_LENGTH {
        return Err(ControllerError::InvalidConfig(format!("Name must be {} characters or less", MAX_NAME_LENGTH)));
    }

    // Validate name characters (alphanumeric and hyphens only)
    if !name.chars().all(|c| c.is_alphanumeric() || c == '-') {
        return Err(ControllerError::InvalidConfig("Name must contain only alphanumeric characters and hyphens".to_string()));
    }

    // Validate connect_to if provided
    if let Some(ref connect_to) = request.connect_to {
        if connect_to.is_empty() {
            return Err(ControllerError::InvalidConfig("connect_to cannot be empty string".to_string()));
        }
        // Validate connect_to characters to prevent command injection
        // Only allow alphanumeric, hyphens, and underscores (safe for Docker commands)
        if !connect_to.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_') {
            return Err(ControllerError::InvalidConfig(
                "connect_to must contain only alphanumeric characters, hyphens, and underscores".to_string(),
            ));
        }
        // Verify the target node exists
        let cluster_state = state.cluster_state.read();
        if !cluster_state.nodes.contains_key(connect_to) {
            return Err(ControllerError::NodeNotFound(connect_to.clone()));
        }
    }

    // Allocate ports
    let ports = state.port_allocator.allocate()?;

    // Determine connection target
    let connect_to = request.connect_to.as_deref();

    info!("Creating node {} with ports p2p={}, grpc={}", name, ports.p2p, ports.grpc);

    // Create container - release ports on failure to prevent port leak
    let container = match state.docker.create_node(&name, ports.p2p, ports.grpc, connect_to, request.utxoindex).await {
        Ok(c) => c,
        Err(e) => {
            // Release allocated ports on container creation failure
            state.port_allocator.release(ports);
            return Err(e);
        }
    };

    // Add node to cluster state immediately for responsive UI
    // (polling will update status/metrics when container starts)
    {
        let mut cluster_state = state.cluster_state.write();
        cluster_state.nodes.insert(
            container.id.clone(),
            crate::state::NodeState {
                id: container.id.clone(),
                name: container.name.clone(),
                container_name: container.container_name.clone(),
                role: "peer".to_string(),
                status: "created".to_string(),
                p2p_port: ports.p2p,
                grpc_port: ports.grpc,
                metrics: None,
            },
        );
    }

    Ok(Json(CreateNodeResponse {
        id: container.id,
        name: container.name,
        ports: NodePortsResponse { p2p: ports.p2p, grpc: ports.grpc },
    }))
}

/// DELETE /api/v1/nodes/:id
/// Remove a node
pub async fn delete_node(State(state): State<AppState>, Path(node_id): Path<String>) -> Result<Json<SuccessResponse>> {
    // Get container info first (for port release later)
    let container = state.docker.get_container(&node_id).await?;
    // Only release ports for node roles (seed/peer) - miners don't allocate ports
    // Check role first, then validate port values to handle edge cases
    let ports_to_release =
        if (container.role == "seed" || container.role == "peer") && container.p2p_port > 0 && container.grpc_port > 0 {
            Some(crate::ports::PortPair { p2p: container.p2p_port, grpc: container.grpc_port })
        } else {
            None
        };

    // Remove container - handle port release based on container state
    let removal_result = state.docker.remove_container(&node_id).await;

    // Determine if we should update state and release ports
    let should_remove_from_state = match &removal_result {
        Ok(_) => true,
        Err(_) => {
            // On error, check if container still exists
            // If not (e.g., timeout after actual removal), still update state
            state.docker.get_container(&node_id).await.is_err()
        }
    };

    // Release ports if container no longer exists
    if let Some(ports) = ports_to_release.filter(|_| should_remove_from_state) {
        state.port_allocator.release(ports);
    }

    // Update cluster state to prevent stale nodes in UI
    if should_remove_from_state {
        let mut cluster_state = state.cluster_state.write();
        cluster_state.nodes.remove(&node_id);
    }

    // Propagate any removal error after state cleanup
    removal_result?;

    info!("Removed node {}", node_id);

    Ok(Json(SuccessResponse::ok(format!("Node {} removed", node_id))))
}

/// POST /api/v1/nodes/:id/start
/// Start a node
pub async fn start_node(State(state): State<AppState>, Path(node_id): Path<String>) -> Result<Json<SuccessResponse>> {
    state.docker.start_container(&node_id).await?;
    info!("Started node {}", node_id);
    Ok(Json(SuccessResponse::ok(format!("Node {} started", node_id))))
}

/// POST /api/v1/nodes/:id/stop
/// Stop a node
pub async fn stop_node(State(state): State<AppState>, Path(node_id): Path<String>) -> Result<Json<SuccessResponse>> {
    state.docker.stop_container(&node_id).await?;
    info!("Stopped node {}", node_id);
    Ok(Json(SuccessResponse::ok(format!("Node {} stopped", node_id))))
}

/// POST /api/v1/nodes/:id/restart
/// Restart a node
pub async fn restart_node(State(state): State<AppState>, Path(node_id): Path<String>) -> Result<Json<SuccessResponse>> {
    state.docker.stop_container(&node_id).await?;
    state.docker.start_container(&node_id).await?;
    info!("Restarted node {}", node_id);
    Ok(Json(SuccessResponse::ok(format!("Node {} restarted", node_id))))
}
