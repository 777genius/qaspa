use bollard::Docker;
use bollard::container::{
    Config, CreateContainerOptions, ListContainersOptions, LogOutput, LogsOptions, RemoveContainerOptions, StartContainerOptions,
    StopContainerOptions,
};
use bollard::network::CreateNetworkOptions;
use futures::StreamExt;
use regex::Regex;
use std::collections::HashMap;
use std::sync::{Arc, LazyLock};
use tokio::sync::broadcast;
use tracing::{debug, error, info};

/// Regex to strip ANSI escape codes from log output
static ANSI_REGEX: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\x1b\[[0-9;]*m").expect("Invalid ANSI regex"));

/// Strip ANSI escape codes from a string
fn strip_ansi_codes(s: &str) -> String {
    ANSI_REGEX.replace_all(s, "").to_string()
}

use crate::config::Config as AppConfig;
use crate::error::{ControllerError, Result};

use super::labels;

/// Safely truncate a string to at most `max_chars` characters.
/// Uses char boundaries to avoid UTF-8 panics.
/// Container ID display length - 16 chars for better uniqueness while remaining readable.
/// Docker short IDs are typically 12, but with many containers this can cause collisions.
const CONTAINER_ID_LENGTH: usize = 16;

fn safe_truncate(s: &str, max_chars: usize) -> String {
    s.chars().take(max_chars).collect()
}

/// Docker manager for testnet containers
pub struct DockerManager {
    docker: Docker,
    config: Arc<AppConfig>,
}

impl DockerManager {
    pub async fn new(config: Arc<AppConfig>) -> Result<Self> {
        let docker = Docker::connect_with_socket_defaults()?;

        // Verify connection
        let info = docker.info().await?;
        info!("Connected to Docker: {:?}", info.name);

        Ok(Self { docker, config })
    }

    /// Ensure the testnet network exists
    pub async fn ensure_network(&self) -> Result<()> {
        let networks = self.docker.list_networks::<String>(None).await?;

        let exists = networks.iter().any(|n| n.name.as_ref() == Some(&self.config.network_name));

        if !exists {
            info!("Creating network: {}", self.config.network_name);
            self.docker
                .create_network(CreateNetworkOptions {
                    name: self.config.network_name.clone(),
                    driver: "bridge".to_string(),
                    ..Default::default()
                })
                .await?;
        }

        Ok(())
    }

    /// List all containers in the cluster
    pub async fn list_containers(&self) -> Result<Vec<ContainerInfo>> {
        let filter = labels::cluster_filter(&self.config.cluster_label);

        let options = ListContainersOptions::<String> {
            all: true,
            filters: HashMap::from([("label".to_string(), vec![filter])]),
            ..Default::default()
        };

        let containers = self.docker.list_containers(Some(options)).await?;

        let mut result = Vec::new();
        for container in containers {
            if let Some(info) = ContainerInfo::from_bollard(&container) {
                result.push(info);
            }
        }

        Ok(result)
    }

    /// List containers by role
    pub async fn list_by_role(&self, role: &str) -> Result<Vec<ContainerInfo>> {
        let filters = labels::role_filter(&self.config.cluster_label, role);

        let options = ListContainersOptions::<String> {
            all: true,
            filters: HashMap::from([("label".to_string(), filters)]),
            ..Default::default()
        };

        let containers = self.docker.list_containers(Some(options)).await?;

        let mut result = Vec::new();
        for container in containers {
            if let Some(info) = ContainerInfo::from_bollard(&container) {
                result.push(info);
            }
        }

        Ok(result)
    }

    /// Create a new kaspad node container
    pub async fn create_node(
        &self,
        name: &str,
        p2p_port: u16,
        grpc_port: u16,
        connect_to: Option<&str>,
        utxoindex: bool,
    ) -> Result<ContainerInfo> {
        let mut cmd = vec![
            "--devnet".to_string(),
            format!("--listen=0.0.0.0:{}", p2p_port),
            format!("--rpclisten=0.0.0.0:{}", grpc_port),
            "--nodnsseed".to_string(),
            "--appdir=/app/data".to_string(),
            "--loglevel=info".to_string(),
        ];

        if let Some(peer) = connect_to {
            cmd.push(format!("--connect={}", peer));
        }

        if utxoindex {
            cmd.push("--utxoindex".to_string());
        }

        let role = if connect_to.is_some() { labels::ROLE_PEER } else { labels::ROLE_SEED };

        let mut labels = HashMap::new();
        labels.insert(labels::LABEL_CLUSTER.to_string(), self.config.cluster_label.clone());
        labels.insert(labels::LABEL_ROLE.to_string(), role.to_string());
        labels.insert(labels::LABEL_NAME.to_string(), name.to_string());
        labels.insert(labels::LABEL_P2P_PORT.to_string(), p2p_port.to_string());
        labels.insert(labels::LABEL_GRPC_PORT.to_string(), grpc_port.to_string());

        let container_name = format!("qaspa_{}", name.replace('-', "_"));

        let config = Config {
            image: Some(self.config.kaspad_image.clone()),
            cmd: Some(cmd),
            labels: Some(labels),
            host_config: Some(bollard::service::HostConfig {
                network_mode: Some(self.config.network_name.clone()),
                port_bindings: Some(HashMap::from([
                    (
                        format!("{}/tcp", p2p_port),
                        Some(vec![bollard::service::PortBinding {
                            host_ip: Some("127.0.0.1".to_string()),
                            host_port: Some(p2p_port.to_string()),
                        }]),
                    ),
                    (
                        format!("{}/tcp", grpc_port),
                        Some(vec![bollard::service::PortBinding {
                            host_ip: Some("127.0.0.1".to_string()),
                            host_port: Some(grpc_port.to_string()),
                        }]),
                    ),
                ])),
                restart_policy: Some(bollard::service::RestartPolicy {
                    name: Some(bollard::service::RestartPolicyNameEnum::UNLESS_STOPPED),
                    ..Default::default()
                }),
                // Security hardening - drop all capabilities and prevent privilege escalation
                cap_drop: Some(vec!["ALL".to_string()]),
                security_opt: Some(vec!["no-new-privileges:true".to_string()]),
                // Resource limits for security
                memory: Some(2 * 1024 * 1024 * 1024),      // 2GB max memory
                memory_swap: Some(2 * 1024 * 1024 * 1024), // No swap
                nano_cpus: Some(2_000_000_000),            // 2 CPU cores max
                pids_limit: Some(256),                     // Max 256 processes
                ..Default::default()
            }),
            ..Default::default()
        };

        let options = CreateContainerOptions { name: container_name.clone(), platform: None };

        let response = self.docker.create_container(Some(options), config).await?;
        info!("Created container: {} ({})", container_name, response.id);

        self.docker.start_container(&response.id, None::<StartContainerOptions<String>>).await?;

        Ok(ContainerInfo {
            id: safe_truncate(&response.id, CONTAINER_ID_LENGTH),
            name: name.to_string(),
            container_name: container_name.clone(),
            role: role.to_string(),
            status: "running".to_string(),
            p2p_port,
            grpc_port,
            stats_port: 0,
            target_node: String::new(),
        })
    }

    /// Create a new miner container
    pub async fn create_miner(
        &self,
        name: &str,
        target_node_grpc: &str,
        payout_address: &str,
        threads: u8,
        target_bps: Option<f64>,
    ) -> Result<ContainerInfo> {
        let mut cmd = vec![
            "/app/miner-agent".to_string(),
            format!("--node-url={}", target_node_grpc),
            format!("--payout-address={}", payout_address),
            format!("--threads={}", threads),
        ];

        if let Some(bps) = target_bps {
            cmd.push(format!("--target-bps={}", bps));
        }

        // Default stats port for miner agent
        const MINER_STATS_PORT: u16 = 9090;

        let mut labels = HashMap::new();
        labels.insert(labels::LABEL_CLUSTER.to_string(), self.config.cluster_label.clone());
        labels.insert(labels::LABEL_ROLE.to_string(), labels::ROLE_MINER.to_string());
        labels.insert(labels::LABEL_NAME.to_string(), name.to_string());
        labels.insert(labels::LABEL_TARGET_NODE.to_string(), target_node_grpc.to_string());
        labels.insert(labels::LABEL_STATS_PORT.to_string(), MINER_STATS_PORT.to_string());

        let container_name = format!("qaspa_miner_{}", name.replace('-', "_"));

        // Port bindings for stats port (exposed to random host port for local dev)
        let mut port_bindings = HashMap::new();
        port_bindings.insert(
            format!("{}/tcp", MINER_STATS_PORT),
            Some(vec![bollard::service::PortBinding {
                host_ip: Some("127.0.0.1".to_string()),
                host_port: None, // Let Docker assign a random port
            }]),
        );

        let config = Config {
            image: Some(self.config.miner_image.clone()),
            cmd: Some(cmd),
            labels: Some(labels),
            exposed_ports: Some([(format!("{}/tcp", MINER_STATS_PORT), HashMap::new())].into_iter().collect()),
            host_config: Some(bollard::service::HostConfig {
                network_mode: Some(self.config.network_name.clone()),
                port_bindings: Some(port_bindings),
                restart_policy: Some(bollard::service::RestartPolicy {
                    name: Some(bollard::service::RestartPolicyNameEnum::UNLESS_STOPPED),
                    ..Default::default()
                }),
                // Security hardening - drop all capabilities and prevent privilege escalation
                cap_drop: Some(vec!["ALL".to_string()]),
                security_opt: Some(vec!["no-new-privileges:true".to_string()]),
                // Resource limits for security
                memory: Some(1024 * 1024 * 1024),      // 1GB max memory for miner
                memory_swap: Some(1024 * 1024 * 1024), // No swap
                nano_cpus: Some(4_000_000_000),        // 4 CPU cores for mining
                pids_limit: Some(64),                  // Max 64 processes
                ..Default::default()
            }),
            ..Default::default()
        };

        let options = CreateContainerOptions { name: container_name.clone(), platform: None };

        let response = self.docker.create_container(Some(options), config).await?;
        info!("Created miner container: {} ({})", container_name, response.id);

        self.docker.start_container(&response.id, None::<StartContainerOptions<String>>).await?;

        Ok(ContainerInfo {
            id: safe_truncate(&response.id, CONTAINER_ID_LENGTH),
            name: name.to_string(),
            container_name: container_name.clone(),
            role: labels::ROLE_MINER.to_string(),
            status: "running".to_string(),
            p2p_port: 0,
            grpc_port: 0,
            stats_port: MINER_STATS_PORT,
            target_node: target_node_grpc.to_string(),
        })
    }

    /// Start a container
    pub async fn start_container(&self, container_id: &str) -> Result<()> {
        self.docker.start_container(container_id, None::<StartContainerOptions<String>>).await?;
        Ok(())
    }

    /// Stop a container
    pub async fn stop_container(&self, container_id: &str) -> Result<()> {
        self.docker.stop_container(container_id, Some(StopContainerOptions { t: 10 })).await?;
        Ok(())
    }

    /// Remove a container with graceful shutdown
    pub async fn remove_container(&self, container_id: &str) -> Result<()> {
        // First try to stop gracefully (10 second timeout)
        if let Err(e) = self.stop_container(container_id).await {
            // Container might already be stopped, log but continue
            tracing::debug!("Container {} stop failed during removal (may already be stopped): {}", container_id, e);
        }

        // Then remove without force
        self.docker
            .remove_container(
                container_id,
                Some(RemoveContainerOptions {
                    force: false, // Graceful removal after stop
                    v: true,
                    ..Default::default()
                }),
            )
            .await?;
        Ok(())
    }

    /// Stream logs from a container
    pub async fn stream_logs(&self, container_id: &str, tail: u64, tx: broadcast::Sender<String>) -> Result<()> {
        let options = LogsOptions::<String> { follow: true, stdout: true, stderr: true, tail: tail.to_string(), ..Default::default() };

        let mut stream = self.docker.logs(container_id, Some(options));

        while let Some(result) = stream.next().await {
            match result {
                Ok(output) => {
                    let line = match output {
                        LogOutput::StdOut { message } => strip_ansi_codes(&String::from_utf8_lossy(&message)),
                        LogOutput::StdErr { message } => strip_ansi_codes(&String::from_utf8_lossy(&message)),
                        _ => continue,
                    };

                    if tx.send(line).is_err() {
                        // All receivers dropped - log and exit gracefully
                        debug!("Log stream ended: no active receivers");
                        break;
                    }
                }
                Err(e) => {
                    error!("Log stream error: {}", e);
                    break;
                }
            }
        }

        Ok(())
    }

    /// Get container by ID or name
    pub async fn get_container(&self, id_or_name: &str) -> Result<ContainerInfo> {
        let containers = self.list_containers().await?;

        containers
            .into_iter()
            .find(|c| c.id == id_or_name || c.name == id_or_name)
            .ok_or_else(|| ControllerError::ContainerNotFound(id_or_name.to_string()))
    }
}

/// Container information
#[derive(Debug, Clone)]
pub struct ContainerInfo {
    pub id: String,
    pub name: String,
    /// Docker container name (for DNS resolution within Docker network)
    pub container_name: String,
    pub role: String,
    pub status: String,
    pub p2p_port: u16,
    pub grpc_port: u16,
    pub stats_port: u16,
    pub target_node: String,
}

impl ContainerInfo {
    fn from_bollard(container: &bollard::models::ContainerSummary) -> Option<Self> {
        let labels = container.labels.as_ref()?;

        let id = container.id.as_ref()?;
        let name = labels.get(labels::LABEL_NAME)?.clone();
        let role = labels.get(labels::LABEL_ROLE)?.clone();

        // Get Docker container name (strip leading '/' from names like "/qaspa_seed")
        let container_name = container
            .names
            .as_ref()
            .and_then(|names| names.first())
            .map(|n| n.trim_start_matches('/').to_string())
            .unwrap_or_else(|| format!("qaspa_{}", name.replace('-', "_")));

        let status = container.state.as_ref().map(|s| s.to_string()).unwrap_or_else(|| "unknown".to_string());

        // Parse and validate port numbers (must be in valid range 1-65535)
        let p2p_port = labels
            .get(labels::LABEL_P2P_PORT)
            .and_then(|s| s.parse::<u16>().ok())
            .filter(|&p| p > 0) // 0 is invalid, use for non-node containers
            .unwrap_or(0);

        let grpc_port = labels
            .get(labels::LABEL_GRPC_PORT)
            .and_then(|s| s.parse::<u16>().ok())
            .filter(|&p| p > 0) // 0 is invalid, use for non-node containers
            .unwrap_or(0);

        // For stats port, try to get the host port from Docker port mappings first
        // This is needed for local dev mode where we expose the stats port to a random host port
        let container_stats_port = labels.get(labels::LABEL_STATS_PORT).and_then(|s| s.parse::<u16>().ok()).unwrap_or(0);
        let stats_port = if container_stats_port > 0 {
            // Try to find the host port mapping for the stats port
            container
                .ports
                .as_ref()
                .and_then(|ports| ports.iter().find(|p| p.private_port == container_stats_port).and_then(|p| p.public_port))
                .unwrap_or(container_stats_port) // Fallback to container port (for Docker network access)
        } else {
            0
        };

        let target_node = labels.get(labels::LABEL_TARGET_NODE).cloned().unwrap_or_default();

        Some(Self {
            id: safe_truncate(id, CONTAINER_ID_LENGTH),
            name,
            container_name,
            role,
            status,
            p2p_port,
            grpc_port,
            stats_port,
            target_node,
        })
    }
}
