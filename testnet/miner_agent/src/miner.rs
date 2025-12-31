use kaspa_addresses::Address;
use kaspa_consensus_core::header::Header;
use kaspa_grpc_client::GrpcClient;
use kaspa_pow::State as PowState;
use kaspa_rpc_core::api::rpc::RpcApi;
use kaspa_rpc_core::RpcExtraData;
use rayon::prelude::*;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::time::sleep;
use tracing::{debug, error, info, warn};

use crate::config::Config;

/// Mining statistics
#[derive(Debug, Default)]
pub struct MiningStats {
    pub blocks_found: AtomicU64,
    pub hashes_computed: AtomicU64,
    pub start_time: Option<Instant>,
}

impl MiningStats {
    pub fn new() -> Self {
        Self { blocks_found: AtomicU64::new(0), hashes_computed: AtomicU64::new(0), start_time: Some(Instant::now()) }
    }

    pub fn hashrate(&self) -> f64 {
        if let Some(start) = self.start_time {
            let elapsed = start.elapsed().as_secs_f64();
            // Require minimum 0.1 seconds for accurate measurement (prevents Infinity)
            if elapsed >= 0.1 {
                let hashes = self.hashes_computed.load(Ordering::Acquire) as f64;
                let rate = hashes / elapsed;
                // Ensure result is valid for JSON serialization
                if rate.is_finite() && rate >= 0.0 {
                    return rate;
                }
            }
        }
        0.0
    }
}

/// Miner instance
pub struct Miner {
    config: Config,
    client: GrpcClient,
    payout_address: Address,
    stats: Arc<MiningStats>,
    should_stop: Arc<AtomicBool>,
}

impl Miner {
    pub async fn new(config: Config) -> anyhow::Result<Self> {
        info!("Connecting to node at {}", config.node_url);
        let client = GrpcClient::connect(config.node_url.clone()).await?;

        // Verify connection
        let server_info = client.get_server_info().await?;
        info!(
            "Connected to {} (network: {:?}, synced: {})",
            server_info.server_version, server_info.network_id, server_info.is_synced
        );

        // Parse payout address
        let payout_address: Address = config.payout_address.as_str().try_into()?;
        info!("Payout address: {}", payout_address);

        Ok(Self { config, client, payout_address, stats: Arc::new(MiningStats::new()), should_stop: Arc::new(AtomicBool::new(false)) })
    }

    /// Run the mining loop
    pub async fn run(&self) -> anyhow::Result<()> {
        info!("Starting mining with {} threads", self.config.threads);

        // Configure rayon thread pool
        if let Err(e) = rayon::ThreadPoolBuilder::new().num_threads(self.config.threads as usize).build_global() {
            // This is expected if the pool was already initialized (e.g., from previous run)
            debug!("Thread pool already initialized or error: {}", e);
        }

        let extra_data: RpcExtraData = self.config.extra_data.as_bytes().to_vec();

        loop {
            if self.should_stop.load(Ordering::Acquire) {
                break;
            }

            // Get block template
            let template = match self.client.get_block_template(self.payout_address.clone().into(), extra_data.clone()).await {
                Ok(t) => t,
                Err(e) => {
                    error!("Failed to get block template: {}", e);
                    sleep(Duration::from_secs(1)).await;
                    continue;
                }
            };

            // Note: On devnet with --enable-unsynced-mining, we can mine even if node reports not synced
            // The node will accept our blocks anyway. Skipping sync check for devnet.
            if !template.is_synced {
                debug!("Node reports not synced, but continuing with mining (devnet mode)");
            }

            // Extract header for PoW
            let header: Header = template.block.header.clone().try_into()?;
            let block_hash = header.hash;

            debug!("Got template with DAA score {}", header.daa_score);

            // Mine the block
            match self.mine_block(&header).await {
                Some(nonce) => {
                    // Found a valid nonce, submit the block
                    let mut block = template.block;
                    block.header.nonce = nonce;

                    match self.client.submit_block(block, false).await {
                        Ok(response) => {
                            if response.report.is_success() {
                                self.stats.blocks_found.fetch_add(1, Ordering::Release);
                                info!(
                                    "Block submitted successfully! Total blocks: {}",
                                    self.stats.blocks_found.load(Ordering::Acquire)
                                );
                            } else {
                                warn!("Block rejected: {:?}", response.report);
                            }
                        }
                        Err(e) => {
                            error!("Failed to submit block: {}", e);
                        }
                    }
                }
                None => {
                    // Template became stale or mining was cancelled
                    debug!("Mining cancelled for block {:?}", block_hash);
                }
            }

            // Rate limiting (skip if target_bps is invalid to avoid division issues)
            if let Some(target_bps) = self.config.target_bps {
                if target_bps > 0.0 && target_bps.is_finite() {
                    // Clamp to safe range: 0.001..1000 BPS to prevent Duration overflow
                    let safe_bps = target_bps.clamp(0.001, 1000.0);
                    let delay = Duration::from_secs_f64(1.0 / safe_bps);
                    sleep(delay).await;
                }
            }
        }

        Ok(())
    }

    /// Mine a single block, returns the nonce if found
    async fn mine_block(&self, header: &Header) -> Option<u64> {
        let pow_state = PowState::new(header);

        let should_stop = self.should_stop.clone();
        let stats = self.stats.clone();

        // Use rayon for parallel nonce search
        let batch_size = 100_000u64;
        let mut start_nonce = rand::random::<u64>();

        loop {
            if should_stop.load(Ordering::Acquire) {
                return None;
            }

            let end_nonce = start_nonce.wrapping_add(batch_size);

            // Parallel search within the batch
            let result = (start_nonce..end_nonce).into_par_iter().find_any(|&nonce| {
                let (valid, _) = pow_state.check_pow(nonce);
                valid
            });

            stats.hashes_computed.fetch_add(batch_size, Ordering::Release);

            if let Some(nonce) = result {
                return Some(nonce);
            }

            start_nonce = end_nonce;

            // Yield to allow checking for new templates
            tokio::task::yield_now().await;
        }
    }

    /// Stop the miner
    pub fn stop(&self) {
        self.should_stop.store(true, Ordering::Release);
    }

    /// Get mining statistics
    #[allow(dead_code)]
    pub fn stats(&self) -> &MiningStats {
        &self.stats
    }

    /// Get mining statistics as Arc (for sharing with HTTP server)
    pub fn stats_arc(&self) -> Arc<MiningStats> {
        self.stats.clone()
    }
}
