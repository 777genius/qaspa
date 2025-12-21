use parking_lot::RwLock;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;

use crate::docker::ContainerInfo;

/// Cluster state
#[derive(Debug, Clone, Serialize)]
pub struct ClusterState {
    pub status: ClusterStatus,
    pub nodes: HashMap<String, NodeState>,
    pub miners: HashMap<String, MinerState>,
    pub txgen_running: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ClusterStatus {
    Starting,
    Running,
    Degraded,
    Stopping,
    Stopped,
}

#[derive(Debug, Clone, Serialize)]
pub struct NodeState {
    pub id: String,
    pub name: String,
    pub container_name: String,
    pub role: String,
    pub status: String,
    pub p2p_port: u16,
    pub grpc_port: u16,
    pub metrics: Option<NodeMetrics>,
}

#[derive(Debug, Clone, Serialize)]
pub struct NodeMetrics {
    pub block_count: u64,
    pub header_count: u64,
    pub virtual_daa_score: u64,
    pub peer_count: usize,
    pub mempool_size: u64,
    pub is_synced: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct MinerState {
    pub id: String,
    pub name: String,
    pub container_name: String,
    pub status: String,
    pub target_node: String,
    pub stats_port: u16,
    pub hashrate: f64,
    pub blocks_found: u64,
}

impl ClusterState {
    pub fn new() -> Self {
        Self { status: ClusterStatus::Stopped, nodes: HashMap::new(), miners: HashMap::new(), txgen_running: false }
    }

    pub fn update_from_containers(&mut self, containers: &[ContainerInfo]) {
        // Build sets of current container IDs to enable selective update instead of clear()
        // This preserves metrics for existing nodes and is more efficient
        let mut new_node_ids = std::collections::HashSet::new();
        let mut new_miner_ids = std::collections::HashSet::new();
        self.txgen_running = false;

        let mut running_nodes = 0;
        let mut total_nodes = 0;

        for container in containers {
            match container.role.as_str() {
                "seed" | "peer" => {
                    total_nodes += 1;
                    if container.status == "running" {
                        running_nodes += 1;
                    }
                    new_node_ids.insert(container.id.clone());

                    // Update existing node or insert new one, preserving metrics
                    if let Some(existing) = self.nodes.get_mut(&container.id) {
                        existing.name = container.name.clone();
                        existing.container_name = container.container_name.clone();
                        existing.role = container.role.clone();
                        existing.status = container.status.clone();
                        existing.p2p_port = container.p2p_port;
                        existing.grpc_port = container.grpc_port;
                        // Preserve existing metrics
                    } else {
                        self.nodes.insert(
                            container.id.clone(),
                            NodeState {
                                id: container.id.clone(),
                                name: container.name.clone(),
                                container_name: container.container_name.clone(),
                                role: container.role.clone(),
                                status: container.status.clone(),
                                p2p_port: container.p2p_port,
                                grpc_port: container.grpc_port,
                                metrics: None,
                            },
                        );
                    }
                }
                "miner" => {
                    new_miner_ids.insert(container.id.clone());

                    // Update existing miner or insert new one, preserving hashrate/blocks
                    if let Some(existing) = self.miners.get_mut(&container.id) {
                        existing.name = container.name.clone();
                        existing.container_name = container.container_name.clone();
                        existing.status = container.status.clone();
                        existing.target_node = container.target_node.clone();
                        existing.stats_port = container.stats_port;
                        // Preserve existing hashrate and blocks_found
                    } else {
                        self.miners.insert(
                            container.id.clone(),
                            MinerState {
                                id: container.id.clone(),
                                name: container.name.clone(),
                                container_name: container.container_name.clone(),
                                status: container.status.clone(),
                                target_node: container.target_node.clone(),
                                stats_port: container.stats_port,
                                hashrate: 0.0,
                                blocks_found: 0,
                            },
                        );
                    }
                }
                "txgen" => {
                    self.txgen_running = container.status == "running";
                }
                _ => {}
            }
        }

        // Remove nodes/miners that no longer exist (selective delete instead of clear())
        self.nodes.retain(|id, _| new_node_ids.contains(id));
        self.miners.retain(|id, _| new_miner_ids.contains(id));

        // Update cluster status
        self.status = if total_nodes == 0 {
            ClusterStatus::Stopped
        } else if running_nodes == total_nodes {
            ClusterStatus::Running
        } else if running_nodes > 0 {
            ClusterStatus::Degraded
        } else {
            ClusterStatus::Stopped
        };
    }

    pub fn update_node_metrics(&mut self, node_id: &str, metrics: NodeMetrics) {
        if let Some(node) = self.nodes.get_mut(node_id) {
            node.metrics = Some(metrics);
        }
    }

    pub fn get_aggregate_metrics(&self) -> AggregateMetrics {
        let mut total_block_count = 0u64;
        let mut total_peers = 0usize;
        let mut total_mempool_size = 0u64;
        let mut max_daa_score = 0u64;
        let mut synced_nodes = 0usize;

        for node in self.nodes.values() {
            if let Some(metrics) = &node.metrics {
                total_block_count = total_block_count.max(metrics.block_count);
                // Use saturating_add to prevent integer overflow
                total_peers = total_peers.saturating_add(metrics.peer_count);
                total_mempool_size = total_mempool_size.saturating_add(metrics.mempool_size);
                max_daa_score = max_daa_score.max(metrics.virtual_daa_score);
                if metrics.is_synced {
                    synced_nodes = synced_nodes.saturating_add(1);
                }
            }
        }

        // Filter invalid hashrates (NaN/Infinity would corrupt the sum for JSON serialization)
        let total_hashrate: f64 =
            self.miners.values().map(|m| if m.hashrate.is_finite() && m.hashrate >= 0.0 { m.hashrate } else { 0.0 }).sum();

        AggregateMetrics {
            total_nodes: self.nodes.len(),
            running_nodes: self.nodes.values().filter(|n| n.status == "running").count(),
            synced_nodes,
            total_miners: self.miners.len(),
            running_miners: self.miners.values().filter(|m| m.status == "running").count(),
            total_block_count,
            virtual_daa_score: max_daa_score,
            total_peers,
            total_mempool_size,
            total_hashrate,
        }
    }
}

impl Default for ClusterState {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct AggregateMetrics {
    pub total_nodes: usize,
    pub running_nodes: usize,
    pub synced_nodes: usize,
    pub total_miners: usize,
    pub running_miners: usize,
    pub total_block_count: u64,
    pub virtual_daa_score: u64,
    pub total_peers: usize,
    pub total_mempool_size: u64,
    pub total_hashrate: f64,
}

/// Thread-safe cluster state wrapper
pub type SharedClusterState = Arc<RwLock<ClusterState>>;

pub fn new_shared_state() -> SharedClusterState {
    Arc::new(RwLock::new(ClusterState::new()))
}
