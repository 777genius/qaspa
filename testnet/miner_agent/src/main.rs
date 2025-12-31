use axum::{routing::get, Json, Router};
use serde::Serialize;
use std::sync::Arc;
use tracing::info;
use tracing_subscriber::EnvFilter;

mod config;
mod miner;
mod stratum;

use config::{Config, MiningMode};
use miner::{Miner, MiningStats};
use stratum::StratumMiner;

#[derive(Serialize)]
struct StatsResponse {
    blocks_found: u64,
    hashrate: f64,
    hashes_computed: u64,
}

/// Validate gRPC URL to prevent SSRF attacks.
/// Only allows:
/// - localhost / 127.0.0.1
/// - Valid Docker container names (alphanumeric, hyphen, underscore, max 63 chars)
fn validate_grpc_url(url: &str) -> anyhow::Result<()> {
    // Must start with grpc:// or grpcs://
    let host_part = url
        .strip_prefix("grpc://")
        .or_else(|| url.strip_prefix("grpcs://"))
        .ok_or_else(|| anyhow::anyhow!("Invalid gRPC URL: must start with grpc:// or grpcs://"))?;

    // Extract host (before port)
    let host = host_part.split(':').next().unwrap_or(host_part);

    // Check for allowed hosts
    let is_localhost = host == "localhost" || host == "127.0.0.1" || host == "::1";
    let is_valid_container_name = is_valid_docker_hostname(host);

    if !is_localhost && !is_valid_container_name {
        anyhow::bail!("Invalid gRPC URL host '{}': only localhost or valid Docker container names allowed", host);
    }

    Ok(())
}

/// Check if hostname is a valid Docker container name.
/// Docker container names: alphanumeric, hyphen, underscore, 1-63 chars.
fn is_valid_docker_hostname(name: &str) -> bool {
    if name.is_empty() || name.len() > 63 {
        return false;
    }
    // Must start with alphanumeric
    if !name.chars().next().map(|c| c.is_ascii_alphanumeric()).unwrap_or(false) {
        return false;
    }
    // All chars must be alphanumeric, hyphen, or underscore
    name.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

/// Mask gRPC URL for safe logging (shows host, hides credentials if any).
fn mask_grpc_url(url: &str) -> String {
    // Simple masking: just show scheme and host
    if let Some(host_part) = url.strip_prefix("grpc://").or_else(|| url.strip_prefix("grpcs://")) {
        let host = host_part.split(':').next().unwrap_or(host_part);
        let scheme = if url.starts_with("grpcs://") { "grpcs" } else { "grpc" };
        format!("{}://{}:***", scheme, host)
    } else {
        "grpc://***".to_string()
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt().with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"))).init();

    info!("Starting Miner Agent");

    // Load configuration
    let config = Config::load();

    // Validate payout address is not empty
    if config.payout_address.trim().is_empty() {
        anyhow::bail!("PAYOUT_ADDRESS cannot be empty. Please provide a valid address.");
    }

    // Mask payout address for security (show only first 8 and last 4 chars)
    let addr = &config.payout_address;
    let addr_chars: Vec<char> = addr.chars().collect();
    let masked_addr = if addr_chars.len() > 16 {
        let prefix: String = addr_chars.iter().take(8).collect();
        let suffix: String = addr_chars.iter().rev().take(4).collect::<Vec<_>>().into_iter().rev().collect();
        format!("{}...{}", prefix, suffix)
    } else {
        "***".to_string()
    };
    info!("Payout address: {}", masked_addr);
    info!("Threads: {}", config.threads);
    info!("Mining mode: {:?}", config.mining_mode);

    let stats_port = config.stats_port;

    match config.mining_mode {
        MiningMode::Solo => {
            // Solo mining via gRPC
            validate_grpc_url(&config.node_url)?;
            let masked_url = mask_grpc_url(&config.node_url);
            info!("Node URL: {}", masked_url);
            if let Some(bps) = config.target_bps {
                info!("Target BPS: {}", bps);
            }

            let miner = Miner::new(config).await?;
            let stats = miner.stats_arc();

            start_stats_server(stats_port, stats.clone());

            let miner_ref = &miner;
            tokio::select! {
                result = miner.run() => {
                    if let Err(e) = result {
                        tracing::error!("Miner error: {}", e);
                    }
                }
                _ = tokio::signal::ctrl_c() => {
                    info!("Received Ctrl+C, stopping miner...");
                    miner_ref.stop();
                }
            }

            info!(
                "Mining stopped. Blocks found: {}, Hashrate: {:.2} H/s",
                stats.blocks_found.load(std::sync::atomic::Ordering::Relaxed),
                stats.hashrate()
            );
        }
        MiningMode::Pool => {
            // Pool mining via Stratum
            info!("Stratum URL: {}", config.stratum_url);
            info!("Worker: {}", config.stratum_worker);

            let stratum_miner = StratumMiner::new(config);
            let stats = stratum_miner.stats_arc();

            start_stats_server(stats_port, stats.clone());

            let miner_ref = &stratum_miner;
            tokio::select! {
                result = stratum_miner.run() => {
                    if let Err(e) = result {
                        tracing::error!("Stratum miner error: {}", e);
                    }
                }
                _ = tokio::signal::ctrl_c() => {
                    info!("Received Ctrl+C, stopping miner...");
                    miner_ref.stop();
                }
            }

            info!(
                "Mining stopped. Shares found: {}, Hashrate: {:.2} H/s",
                stats.blocks_found.load(std::sync::atomic::Ordering::Relaxed),
                stats.hashrate()
            );
        }
    }

    Ok(())
}

/// Start the stats HTTP server
fn start_stats_server(stats_port: u16, stats: Arc<MiningStats>) {
    if stats_port > 0 {
        tokio::spawn(async move {
            let app = Router::new().route(
                "/stats",
                get(move || {
                    let stats = stats.clone();
                    async move {
                        Json(StatsResponse {
                            blocks_found: stats.blocks_found.load(std::sync::atomic::Ordering::Relaxed),
                            hashrate: stats.hashrate(),
                            hashes_computed: stats.hashes_computed.load(std::sync::atomic::Ordering::Relaxed),
                        })
                    }
                }),
            );
            let addr = format!("0.0.0.0:{}", stats_port);
            info!("Stats API listening on http://{}", addr);
            let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
            axum::serve(listener, app).await.unwrap();
        });
    }
}
