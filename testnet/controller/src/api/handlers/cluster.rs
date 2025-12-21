use axum::extract::State;
use axum::Json;

use crate::api::dto::{ClusterSummaryResponse, MinerSummaryResponse, NodeSummaryResponse};
use crate::api::AppState;
use crate::error::Result;

/// GET /api/v1/cluster
/// Returns cluster summary with all nodes and miners
pub async fn get_cluster(State(state): State<AppState>) -> Result<Json<ClusterSummaryResponse>> {
    let cluster_state = state.cluster_state.read();

    let nodes: Vec<NodeSummaryResponse> = cluster_state.nodes.values().cloned().map(NodeSummaryResponse::from).collect();

    let miners: Vec<MinerSummaryResponse> = cluster_state.miners.values().cloned().map(MinerSummaryResponse::from).collect();

    let aggregate = cluster_state.get_aggregate_metrics();

    Ok(Json(ClusterSummaryResponse {
        status: cluster_state.status,
        nodes,
        miners,
        txgen_running: cluster_state.txgen_running,
        aggregate,
    }))
}
