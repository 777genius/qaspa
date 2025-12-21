use clap::Parser;
use std::net::SocketAddr;
use std::path::PathBuf;

/// Testnet Controller - manages devnet cluster via HTTP/WS API
#[derive(Parser, Debug, Clone)]
#[command(author, version, about)]
pub struct Config {
    /// HTTP server bind address (default localhost for security)
    #[arg(long, env = "HTTP_BIND", default_value = "127.0.0.1:8080")]
    pub http_bind: SocketAddr,

    /// Directory for serving static files (Flutter web build)
    #[arg(long, env = "STATIC_DIR", default_value = "/static")]
    pub static_dir: PathBuf,

    /// Docker socket path
    #[arg(long, env = "DOCKER_SOCKET", default_value = "unix:///var/run/docker.sock")]
    pub docker_socket: String,

    /// Docker network name for testnet
    #[arg(long, env = "NETWORK_NAME", default_value = "qaspa_testnet_net")]
    pub network_name: String,

    /// Cluster label for filtering containers
    #[arg(long, env = "CLUSTER_LABEL", default_value = "testnet_local")]
    pub cluster_label: String,

    /// Seed node gRPC URL
    #[arg(long, env = "SEED_GRPC_URL", default_value = "grpc://localhost:16210")]
    pub seed_grpc_url: String,

    /// Kaspad Docker image
    #[arg(long, env = "KASPAD_IMAGE", default_value = "qaspa/kaspad:latest")]
    pub kaspad_image: String,

    /// Rothschild Docker image
    #[arg(long, env = "ROTHSCHILD_IMAGE", default_value = "qaspa/rothschild:latest")]
    pub rothschild_image: String,

    /// Miner agent Docker image
    #[arg(long, env = "MINER_IMAGE", default_value = "qaspa/miner_agent:latest")]
    pub miner_image: String,

    /// Monitoring poll interval in milliseconds
    #[arg(long, env = "POLL_INTERVAL_MS", default_value = "2000")]
    pub poll_interval_ms: u64,

    /// gRPC request timeout in milliseconds
    #[arg(long, env = "GRPC_TIMEOUT_MS", default_value = "5000")]
    pub grpc_timeout_ms: u64,

    /// Database URL for metrics storage
    #[arg(long, env = "DATABASE_URL", default_value = "postgres://qaspa:qaspa_dev@localhost:5432/qaspa_testnet")]
    pub database_url: String,

    /// Metrics flush interval in milliseconds
    #[arg(long, env = "METRICS_FLUSH_INTERVAL_MS", default_value = "10000")]
    pub metrics_flush_interval_ms: u64,

    /// Metrics batch size for database writes
    #[arg(long, env = "METRICS_BATCH_SIZE", default_value = "100")]
    pub metrics_batch_size: usize,

    /// Starting port for P2P connections
    #[arg(long, env = "P2P_PORT_START", default_value = "16211")]
    pub p2p_port_start: u16,

    /// Starting port for gRPC connections
    #[arg(long, env = "GRPC_PORT_START", default_value = "16210")]
    pub grpc_port_start: u16,
}

impl Config {
    pub fn load() -> Self {
        Config::parse()
    }
}
