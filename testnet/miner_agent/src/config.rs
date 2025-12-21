use clap::Parser;

/// Miner Agent - PoW miner for testnet
#[derive(Parser, Debug, Clone)]
#[command(author, version, about)]
pub struct Config {
    /// Node gRPC URL to connect to
    #[arg(long, env = "NODE_GRPC_URL", default_value = "grpc://localhost:16210")]
    pub node_url: String,

    /// Payout address for mining rewards
    #[arg(long, env = "PAYOUT_ADDRESS")]
    pub payout_address: String,

    /// Number of mining threads
    #[arg(long, env = "THREADS", default_value = "1")]
    pub threads: u8,

    /// Target blocks per second (rate limiting)
    #[arg(long, env = "TARGET_BPS")]
    pub target_bps: Option<f64>,

    /// Extra data to include in mined blocks
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
