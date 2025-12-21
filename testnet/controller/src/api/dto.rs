use serde::{Deserialize, Serialize};

use crate::state::{AggregateMetrics, ClusterStatus, MinerState, NodeMetrics, NodeState};

// ==================== Cluster ====================

#[derive(Debug, Serialize)]
pub struct ClusterSummaryResponse {
    pub status: ClusterStatus,
    pub nodes: Vec<NodeSummaryResponse>,
    pub miners: Vec<MinerSummaryResponse>,
    pub txgen_running: bool,
    pub aggregate: AggregateMetrics,
}

// ==================== Node ====================

#[derive(Debug, Serialize)]
pub struct NodeSummaryResponse {
    pub id: String,
    pub name: String,
    pub role: String,
    pub status: String,
    pub ports: NodePortsResponse,
    pub metrics: Option<NodeMetrics>,
}

#[derive(Debug, Serialize)]
pub struct NodePortsResponse {
    pub p2p: u16,
    pub grpc: u16,
}

impl From<NodeState> for NodeSummaryResponse {
    fn from(node: NodeState) -> Self {
        Self {
            id: node.id,
            name: node.name,
            role: node.role,
            status: node.status,
            ports: NodePortsResponse { p2p: node.p2p_port, grpc: node.grpc_port },
            metrics: node.metrics,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateNodeRequest {
    pub name: Option<String>,
    pub connect_to: Option<String>,
    #[serde(default)]
    pub utxoindex: bool,
}

#[derive(Debug, Serialize)]
pub struct CreateNodeResponse {
    pub id: String,
    pub name: String,
    pub ports: NodePortsResponse,
}

// ==================== Miner ====================

#[derive(Debug, Serialize)]
pub struct MinerSummaryResponse {
    pub id: String,
    pub name: String,
    pub status: String,
    pub target_node: String,
    pub hashrate: f64,
    pub blocks_found: u64,
}

impl From<MinerState> for MinerSummaryResponse {
    fn from(miner: MinerState) -> Self {
        Self {
            id: miner.id,
            name: miner.name,
            status: miner.status,
            target_node: miner.target_node,
            hashrate: miner.hashrate,
            blocks_found: miner.blocks_found,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateMinerRequest {
    pub name: Option<String>,
    pub target_node: String,
    pub payout_address: String,
    #[serde(default = "default_threads")]
    pub threads: u8,
    pub target_bps: Option<f64>,
}

fn default_threads() -> u8 {
    1
}

#[derive(Debug, Serialize)]
pub struct CreateMinerResponse {
    pub id: String,
    pub name: String,
}

// ==================== TxGen ====================

#[derive(Debug, Serialize)]
pub struct TxGenStatusResponse {
    pub running: bool,
}

#[derive(Debug, Deserialize)]
pub struct StartTxGenRequest {
    pub target_node: Option<String>,
    #[serde(default = "default_tps")]
    pub tps: u64,
}

fn default_tps() -> u64 {
    1
}

// ==================== DAG ====================

#[derive(Debug, Serialize)]
pub struct DagInfoResponse {
    pub tip_hashes: Vec<String>,
    pub sink_hash: String,
    pub pruning_point_hash: String,
    pub virtual_daa_score: u64,
    pub block_count: u64,
    pub difficulty: f64,
}

#[derive(Debug, Serialize)]
pub struct DagBlockResponse {
    pub hash: String,
    pub daa_score: u64,
    pub blue_score: u64,
    pub blue_work: String,
    pub parent_hashes: Vec<String>,
    pub children_hashes: Vec<String>,
    pub selected_parent_hash: Option<String>,
    pub merge_set_blues: Vec<String>,
    pub merge_set_reds: Vec<String>,
    pub is_chain_block: bool,
    pub timestamp: u64,
    pub block_type: String,
}

#[derive(Debug, Serialize)]
pub struct DagBlocksResponse {
    pub blocks: Vec<DagBlockResponse>,
}

// ==================== Metrics History ====================

#[derive(Debug, Deserialize)]
pub struct MetricsHistoryQuery {
    pub from: Option<i64>,
    pub to: Option<i64>,
    #[serde(default = "default_limit")]
    pub limit: i64,
}

fn default_limit() -> i64 {
    1000
}

#[derive(Debug, Serialize)]
pub struct NodeMetricsHistoryResponse {
    pub data: Vec<NodeMetricsPoint>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NodeMetricsPoint {
    pub timestamp: i64,
    pub block_count: i64,
    pub header_count: i64,
    pub virtual_daa_score: i64,
    pub peer_count: i32,
    pub mempool_size: i64,
    pub is_synced: bool,
}

#[derive(Debug, Serialize)]
pub struct MinerMetricsHistoryResponse {
    pub data: Vec<MinerMetricsPoint>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MinerMetricsPoint {
    pub timestamp: i64,
    pub hashrate: f64,
    pub blocks_found: i64,
}

#[derive(Debug, Serialize)]
pub struct AggregateMetricsHistoryResponse {
    pub data: Vec<AggregateMetricsPoint>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AggregateMetricsPoint {
    pub timestamp: i64,
    pub total_nodes: i32,
    pub running_nodes: i32,
    pub synced_nodes: i32,
    pub total_miners: i32,
    pub running_miners: i32,
    pub total_block_count: i64,
    pub virtual_daa_score: i64,
    pub total_hashrate: f64,
}

// ==================== Common ====================

#[derive(Debug, Serialize)]
pub struct SuccessResponse {
    pub success: bool,
    pub message: String,
}

impl SuccessResponse {
    pub fn ok(message: impl Into<String>) -> Self {
        Self { success: true, message: message.into() }
    }
}
