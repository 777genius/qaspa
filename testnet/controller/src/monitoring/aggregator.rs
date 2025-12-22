use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{broadcast, watch};
use tokio::time::interval;
use tracing::{debug, error, info, trace, warn};

use crate::db::MetricsWriter;
use crate::docker::DockerManager;
use crate::error::Result;
use crate::state::{NodeMetrics, SharedClusterState};

use super::node_client::NodeMonitor;

/// Miner stats response from miner-agent HTTP API
#[derive(Debug, serde::Deserialize)]
struct MinerStatsResponse {
    blocks_found: u64,
    hashrate: f64,
}

/// WebSocket event types
#[derive(Debug, Clone, serde::Serialize)]
#[serde(tag = "type", content = "data")]
pub enum WsEvent {
    ClusterUpdated(crate::state::ClusterState),
    NodeMetricsUpdated { node_id: String, metrics: NodeMetrics },
    ContainerStarted { id: String, name: String, role: String },
    ContainerStopped { id: String, name: String },
    Error { message: String },
}

/// Monitoring aggregator that polls nodes and broadcasts updates
pub struct MonitoringAggregator {
    docker: Arc<DockerManager>,
    state: SharedClusterState,
    monitors: HashMap<String, NodeMonitor>,
    poll_interval: Duration,
    grpc_timeout: u64,
    event_tx: broadcast::Sender<WsEvent>,
    shutdown_rx: watch::Receiver<bool>,
    metrics_writer: Option<Arc<MetricsWriter>>,
    local_mode: bool,
}

impl MonitoringAggregator {
    pub fn new(
        docker: Arc<DockerManager>,
        state: SharedClusterState,
        poll_interval_ms: u64,
        grpc_timeout_ms: u64,
        event_tx: broadcast::Sender<WsEvent>,
        shutdown_rx: watch::Receiver<bool>,
        metrics_writer: Option<Arc<MetricsWriter>>,
        local_mode: bool,
    ) -> Self {
        Self {
            docker,
            state,
            monitors: HashMap::new(),
            poll_interval: Duration::from_millis(poll_interval_ms),
            grpc_timeout: grpc_timeout_ms,
            event_tx,
            shutdown_rx,
            metrics_writer,
            local_mode,
        }
    }

    /// Run the monitoring loop
    pub async fn run(&mut self) {
        info!("Starting monitoring aggregator");
        let mut interval = interval(self.poll_interval);

        loop {
            tokio::select! {
                _ = interval.tick() => {
                    if let Err(e) = self.poll_once().await {
                        error!("Monitoring poll error: {}", e);
                        if let Err(send_err) = self.event_tx.send(WsEvent::Error {
                            message: e.to_string(),
                        }) {
                            debug!("No WebSocket receivers for error event: {}", send_err);
                        }
                    }
                }
                _ = self.shutdown_rx.changed() => {
                    if *self.shutdown_rx.borrow() {
                        info!("Monitoring aggregator received shutdown signal");
                        break;
                    }
                }
            }
        }

        // Graceful cleanup: disconnect all monitors
        info!("Disconnecting {} node monitors...", self.monitors.len());
        for (id, mut monitor) in self.monitors.drain() {
            debug!("Disconnecting monitor for node {}", id);
            monitor.disconnect().await;
        }
        info!("Monitoring aggregator stopped");
    }

    /// Single poll iteration
    async fn poll_once(&mut self) -> Result<()> {
        // Get current containers
        let containers = self.docker.list_containers().await?;

        // Update cluster state
        {
            let mut state = self.state.write();
            state.update_from_containers(&containers);
        }

        // Update monitors for nodes
        let current_node_ids: Vec<String> = containers
            .iter()
            .filter(|c| c.role == "seed" || c.role == "peer")
            .filter(|c| c.status == "running")
            .map(|c| c.id.clone())
            .collect();

        // Remove monitors for nodes that no longer exist
        // First disconnect monitors that will be removed to prevent connection leak
        let ids_to_remove: Vec<String> = self.monitors.keys().filter(|id| !current_node_ids.contains(*id)).cloned().collect();

        for id in ids_to_remove {
            if let Some(mut monitor) = self.monitors.remove(&id) {
                debug!("Disconnecting monitor for removed node {}", id);
                monitor.disconnect().await;
            }
        }

        // Add monitors for new nodes (using entry API to avoid TOCTOU race)
        for container in &containers {
            if (container.role == "seed" || container.role == "peer") && container.status == "running" {
                let grpc_timeout = self.grpc_timeout;
                let container_name = container.name.clone();
                let local_mode = self.local_mode;
                self.monitors.entry(container.id.clone()).or_insert_with(|| {
                    // Use localhost in local mode, Docker container name otherwise
                    let host = if local_mode { "localhost" } else { container.container_name.as_str() };
                    let grpc_url = format!("grpc://{}:{}", host, container.grpc_port);
                    debug!("Added monitor for node {} at {}", container_name, grpc_url);
                    NodeMonitor::new(container.id.clone(), grpc_url, grpc_timeout)
                });
            }
        }

        // Poll each node for metrics (collect first, then update state to minimize lock contention)
        let mut metrics_updates: Vec<(String, NodeMetrics)> = Vec::new();
        for (node_id, monitor) in &mut self.monitors {
            match monitor.get_metrics().await {
                Ok(metrics) => {
                    metrics_updates.push((node_id.clone(), metrics));
                }
                Err(e) => {
                    warn!("Failed to get metrics for node {}: {}", node_id, e);
                }
            }
        }

        // Update state with all collected metrics in a single critical section
        if !metrics_updates.is_empty() {
            {
                let mut state = self.state.write();
                for (node_id, metrics) in &metrics_updates {
                    state.update_node_metrics(node_id, metrics.clone());
                }
            }

            // Record node metrics to database
            if let Some(writer) = &self.metrics_writer {
                for (node_id, metrics) in &metrics_updates {
                    writer.record_node_metrics(node_id, metrics).await;
                }
            }

            // Broadcast events outside the lock
            for (node_id, metrics) in metrics_updates {
                if let Err(e) = self.event_tx.send(WsEvent::NodeMetricsUpdated { node_id, metrics }) {
                    // Use trace! since no receivers is a normal state, not worth debug logging
                    trace!("No WebSocket receivers for metrics update: {}", e);
                }
            }
        }

        // Poll miner stats
        let running_miners: Vec<(String, String, u16)> = {
            let state = self.state.read();
            state
                .miners
                .values()
                .filter(|m| m.status == "running" && m.stats_port > 0)
                .map(|m| (m.id.clone(), m.container_name.clone(), m.stats_port))
                .collect()
        };

        let http_client = reqwest::Client::builder().timeout(Duration::from_secs(5)).build().ok();

        if let Some(client) = http_client {
            for (miner_id, container_name, stats_port) in running_miners {
                let host = if self.local_mode { "localhost" } else { container_name.as_str() };
                let url = format!("http://{}:{}/stats", host, stats_port);
                match client.get(&url).send().await {
                    Ok(response) => {
                        if let Ok(stats) = response.json::<MinerStatsResponse>().await {
                            {
                                let mut state = self.state.write();
                                if let Some(miner) = state.miners.get_mut(&miner_id) {
                                    miner.hashrate = stats.hashrate;
                                    miner.blocks_found = stats.blocks_found;
                                }
                            }
                            // Record miner metrics to database
                            if let Some(writer) = &self.metrics_writer {
                                writer.record_miner_metrics(&miner_id, stats.hashrate, stats.blocks_found).await;
                            }
                        }
                    }
                    Err(e) => {
                        debug!("Failed to get stats for miner {}: {}", miner_id, e);
                    }
                }
            }
        }

        // Record aggregate metrics to database
        if let Some(writer) = &self.metrics_writer {
            let aggregate = {
                let state = self.state.read();
                state.get_aggregate_metrics()
            };
            writer.record_aggregate_metrics(&aggregate).await;
        }

        // Broadcast cluster state update
        let state = self.state.read().clone();
        if let Err(e) = self.event_tx.send(WsEvent::ClusterUpdated(state)) {
            // Use trace! since no receivers is a normal state
            trace!("No WebSocket receivers for cluster update: {}", e);
        }

        Ok(())
    }
}
