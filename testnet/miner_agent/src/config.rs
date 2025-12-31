use clap::{Parser, ValueEnum};

/// Mining mode selection
#[derive(Debug, Clone, Copy, PartialEq, Eq, ValueEnum, Default)]
pub enum MiningMode {
    /// Solo mining via gRPC directly to node
    #[default]
    Solo,
    /// Pool mining via Stratum protocol
    Pool,
}

/// Miner Agent - PoW miner for testnet
#[derive(Parser, Debug, Clone)]
#[command(author, version, about)]
pub struct Config {
    /// Mining mode: solo (gRPC to node) or pool (Stratum)
    #[arg(long, env = "MINING_MODE", value_enum, default_value = "solo")]
    pub mining_mode: MiningMode,

    /// Node gRPC URL to connect to (for solo mode)
    #[arg(long, env = "NODE_GRPC_URL", default_value = "grpc://localhost:16210")]
    pub node_url: String,

    /// Stratum server URL (for pool mode), e.g. localhost:3333
    #[arg(long, env = "STRATUM_URL", default_value = "localhost:3333")]
    pub stratum_url: String,

    /// Worker name for Stratum (for pool mode)
    #[arg(long, env = "STRATUM_WORKER", default_value = "worker1")]
    pub stratum_worker: String,

    /// Payout address for mining rewards
    #[arg(long, env = "PAYOUT_ADDRESS")]
    pub payout_address: String,

    /// Number of mining threads
    #[arg(long, env = "THREADS", default_value = "1")]
    pub threads: u8,

    /// Target blocks per second (rate limiting, solo mode only)
    #[arg(long, env = "TARGET_BPS")]
    pub target_bps: Option<f64>,

    /// Extra data to include in mined blocks (solo mode only)
    #[arg(long, env = "EXTRA_DATA", default_value = "miner-agent")]
    pub extra_data: String,

    /// Port for stats HTTP API (0 to disable)
    #[arg(long, env = "STATS_PORT", default_value = "9090")]
    pub stats_port: u16,
}

impl Config {
    pub fn load() -> Self {
        Config::parse()
    }
}
