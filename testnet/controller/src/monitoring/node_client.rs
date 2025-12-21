use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::api::rpc::RpcApi;
use std::time::Duration;
use tracing::{debug, error, warn};

use crate::error::{ControllerError, Result};
use crate::state::NodeMetrics;

/// gRPC client for monitoring a single node
pub struct NodeMonitor {
    node_id: String,
    grpc_url: String,
    client: Option<GrpcClient>,
    timeout: Duration,
}

impl NodeMonitor {
    pub fn new(node_id: String, grpc_url: String, timeout_ms: u64) -> Self {
        Self { node_id, grpc_url, client: None, timeout: Duration::from_millis(timeout_ms) }
    }

    /// Ensure client is connected
    async fn ensure_connected(&mut self) -> Result<&GrpcClient> {
        if self.client.is_none() {
            debug!("Connecting to node {} at {}", self.node_id, self.grpc_url);

            // Use timeout to prevent indefinite blocking on unreachable nodes
            let connect_timeout = Duration::from_secs(10);
            match tokio::time::timeout(connect_timeout, GrpcClient::connect(self.grpc_url.clone())).await {
                Ok(Ok(client)) => {
                    self.client = Some(client);
                }
                Ok(Err(e)) => {
                    error!("Failed to connect to {}: {}", self.grpc_url, e);
                    return Err(ControllerError::Grpc(e.to_string()));
                }
                Err(_) => {
                    warn!("Connection timeout to {}", self.grpc_url);
                    return Err(ControllerError::Grpc(format!("Connection timeout to {}", self.grpc_url)));
                }
            }
        }

        // Client should be set after successful connection above
        self.client.as_ref().ok_or_else(|| ControllerError::Grpc("Client not initialized after connection".to_string()))
    }

    /// Get current metrics from the node
    pub async fn get_metrics(&mut self) -> Result<NodeMetrics> {
        // Extract timeout before mutable borrow of self
        let timeout = self.timeout;
        let client = self.ensure_connected().await?;

        // Get block DAG info
        let dag_info = tokio::time::timeout(timeout, client.get_block_dag_info())
            .await
            .map_err(|_| ControllerError::Grpc("Timeout getting DAG info".to_string()))?
            .map_err(|e| ControllerError::Grpc(e.to_string()))?;

        // Get connected peers
        let peer_info = tokio::time::timeout(timeout, client.get_connected_peer_info())
            .await
            .map_err(|_| ControllerError::Grpc("Timeout getting peer info".to_string()))?
            .map_err(|e| ControllerError::Grpc(e.to_string()))?;

        // Get server info for sync status
        let server_info = tokio::time::timeout(timeout, client.get_server_info())
            .await
            .map_err(|_| ControllerError::Grpc("Timeout getting server info".to_string()))?
            .map_err(|e| ControllerError::Grpc(e.to_string()))?;

        // Get mempool entries count (with error logging)
        let mempool_size = match tokio::time::timeout(timeout, client.get_mempool_entries(false, false)).await {
            Ok(Ok(entries)) => entries.len() as u64,
            Ok(Err(e)) => {
                warn!("Failed to get mempool entries for node {}: {}", self.node_id, e);
                0
            }
            Err(_) => {
                warn!("Timeout getting mempool entries for node {}", self.node_id);
                0
            }
        };

        Ok(NodeMetrics {
            block_count: dag_info.block_count,
            header_count: dag_info.header_count,
            virtual_daa_score: dag_info.virtual_daa_score,
            peer_count: peer_info.peer_info.len(),
            mempool_size,
            is_synced: server_info.is_synced,
        })
    }

    /// Disconnect the client with retry and timeout
    pub async fn disconnect(&mut self) {
        if let Some(client) = self.client.take() {
            // Use a reasonable timeout for disconnect operations
            let disconnect_timeout = Duration::from_secs(2);

            // Try disconnect with retries to ensure cleanup
            for attempt in 1..=3 {
                match tokio::time::timeout(disconnect_timeout, client.disconnect()).await {
                    Ok(Ok(_)) => {
                        debug!("Disconnected from {} on attempt {}", self.grpc_url, attempt);
                        return;
                    }
                    Ok(Err(e)) => {
                        if attempt < 3 {
                            warn!("Error disconnecting from {} (attempt {}): {}, retrying...", self.grpc_url, attempt, e);
                            tokio::time::sleep(Duration::from_millis(100)).await;
                        } else {
                            // After all retries failed, force drop the client to release resources.
                            error!("Failed to disconnect from {} after {} attempts: {}, forcing drop", self.grpc_url, attempt, e);
                            drop(client);
                            return;
                        }
                    }
                    Err(_) => {
                        // Timeout - force drop and return
                        warn!("Timeout disconnecting from {} (attempt {}), forcing drop", self.grpc_url, attempt);
                        drop(client);
                        return;
                    }
                }
            }
        }
    }

    pub fn node_id(&self) -> &str {
        &self.node_id
    }
}
