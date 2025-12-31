//! Stratum Protocol Client for Pool Mining
//!
//! Implements Stratum protocol (JSON-RPC over TCP) for connecting to mining pools.
//! Protocol flow:
//! 1. Connect to pool
//! 2. mining.subscribe -> get subscription ID and extranonce
//! 3. mining.authorize -> authenticate with worker name and address
//! 4. Receive mining.set_difficulty and mining.notify
//! 5. Submit shares via mining.submit

use kaspa_hashes::{Hash, PowHash};
use kaspa_math::Uint256;
use kaspa_pow::matrix::Matrix;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};

use crate::config::Config;
use crate::miner::MiningStats;

/// Stratum job received from pool
#[derive(Debug, Clone)]
pub struct StratumJob {
    pub job_id: String,
    pub pre_pow_hash: String,
    pub timestamp: u64,
    #[allow(dead_code)]
    pub target: String,
    pub clean_jobs: bool,
}

/// Stratum mining client
pub struct StratumMiner {
    config: Config,
    stats: Arc<MiningStats>,
    should_stop: Arc<AtomicBool>,
    current_difficulty: AtomicU64,
}

/// JSON-RPC request
#[derive(Serialize)]
struct JsonRpcRequest {
    id: u64,
    method: &'static str,
    params: Vec<Value>,
}

/// JSON-RPC response/notification
#[derive(Deserialize, Debug)]
#[allow(dead_code)]
struct JsonRpcMessage {
    id: Option<u64>,
    method: Option<String>,
    params: Option<Vec<Value>>,
    result: Option<Value>,
    error: Option<Value>,
}

impl StratumMiner {
    pub fn new(config: Config) -> Self {
        Self {
            config,
            stats: Arc::new(MiningStats::new()),
            should_stop: Arc::new(AtomicBool::new(false)),
            current_difficulty: AtomicU64::new(512), // Default difficulty
        }
    }

    /// Run the Stratum mining loop
    pub async fn run(&self) -> anyhow::Result<()> {
        info!("Connecting to Stratum pool at {}", self.config.stratum_url);

        // Sequential mining mode - no thread pool needed for low memory usage

        loop {
            if self.should_stop.load(Ordering::Acquire) {
                break;
            }

            match self.connect_and_mine().await {
                Ok(()) => {
                    if self.should_stop.load(Ordering::Acquire) {
                        break;
                    }
                    warn!("Stratum connection closed, reconnecting...");
                }
                Err(e) => {
                    error!("Stratum error: {}", e);
                }
            }

            // Wait before reconnecting
            tokio::time::sleep(Duration::from_secs(5)).await;
        }

        Ok(())
    }

    /// Connect to pool and start mining
    async fn connect_and_mine(&self) -> anyhow::Result<()> {
        let stream = TcpStream::connect(&self.config.stratum_url).await?;
        let (reader, mut writer) = stream.into_split();
        let mut reader = BufReader::new(reader);

        info!("Connected to Stratum pool");

        // Channel for receiving jobs
        let (job_tx, mut job_rx) = mpsc::channel::<StratumJob>(10);
        let should_stop = self.should_stop.clone();
        let difficulty = Arc::new(AtomicU64::new(512));
        let difficulty_clone = difficulty.clone();

        // Message ID counter
        let mut msg_id: u64 = 1;

        // Subscribe
        let subscribe_req = JsonRpcRequest { id: msg_id, method: "mining.subscribe", params: vec![json!("miner-agent/1.0")] };
        msg_id += 1;

        let line = serde_json::to_string(&subscribe_req)? + "\n";
        writer.write_all(line.as_bytes()).await?;
        debug!("Sent: mining.subscribe");

        // Read subscribe response
        let mut buf = String::new();
        reader.read_line(&mut buf).await?;
        let subscribe_resp: JsonRpcMessage = serde_json::from_str(&buf)?;
        debug!("Subscribe response: {:?}", subscribe_resp);

        let extranonce1 = if let Some(Value::Array(arr)) = subscribe_resp.result {
            if arr.len() >= 2 {
                arr[1].as_str().unwrap_or("00000000").to_string()
            } else {
                "00000000".to_string()
            }
        } else {
            "00000000".to_string()
        };
        info!("Subscribed, extranonce1: {}", extranonce1);

        // Authorize
        let worker_name = format!("{}.{}", self.config.stratum_worker, self.config.payout_address);
        let authorize_req = JsonRpcRequest {
            id: msg_id,
            method: "mining.authorize",
            params: vec![json!(worker_name), json!("x")], // password is ignored
        };
        msg_id += 1;

        let line = serde_json::to_string(&authorize_req)? + "\n";
        writer.write_all(line.as_bytes()).await?;
        debug!("Sent: mining.authorize");

        // Read authorize response, skipping any notifications (set_difficulty, etc.)
        let expected_id = msg_id - 1; // The authorize request id
        loop {
            buf.clear();
            reader.read_line(&mut buf).await?;
            let msg: JsonRpcMessage = serde_json::from_str(&buf)?;

            // Check if this is a response (has id) vs notification (id is null)
            if let Some(id) = msg.id {
                if id == expected_id {
                    // This is our authorize response
                    if msg.result != Some(Value::Bool(true)) {
                        anyhow::bail!("Authorization failed: {:?}", msg.error);
                    }
                    break;
                }
            } else {
                // This is a notification (set_difficulty, notify, etc.) - skip it
                debug!("Skipping notification during auth: {:?}", msg.method);
            }
        }
        info!("Authorized as {}", self.config.stratum_worker);

        // Spawn reader task to handle incoming messages
        let reader_stop = should_stop.clone();
        let reader_handle = tokio::spawn(async move {
            let mut buf = String::new();
            loop {
                if reader_stop.load(Ordering::Acquire) {
                    break;
                }

                buf.clear();
                match reader.read_line(&mut buf).await {
                    Ok(0) => {
                        debug!("Connection closed by pool");
                        break;
                    }
                    Ok(_) => {
                        if let Ok(msg) = serde_json::from_str::<JsonRpcMessage>(&buf) {
                            match msg.method.as_deref() {
                                Some("mining.set_difficulty") => {
                                    if let Some(params) = msg.params {
                                        if let Some(diff) = params.first().and_then(|v| v.as_f64()) {
                                            let diff_u64 = diff as u64;
                                            difficulty_clone.store(diff_u64, Ordering::Release);
                                            info!("Difficulty set to {}", diff_u64);
                                        }
                                    }
                                }
                                Some("mining.notify") => {
                                    if let Some(params) = msg.params {
                                        if let Some(job) = parse_notify_params(&params) {
                                            debug!("New job: {}", job.job_id);
                                            let _ = job_tx.try_send(job);
                                        }
                                    }
                                }
                                _ => {
                                    debug!("Received: {:?}", msg);
                                }
                            }
                        }
                    }
                    Err(e) => {
                        error!("Read error: {}", e);
                        break;
                    }
                }
            }
        });

        // Mining loop
        let mut current_job: Option<StratumJob> = None;

        loop {
            if self.should_stop.load(Ordering::Acquire) {
                break;
            }

            // Check for new jobs (non-blocking)
            while let Ok(job) = job_rx.try_recv() {
                if job.clean_jobs {
                    debug!("Clean jobs flag, abandoning current work");
                }
                current_job = Some(job);
            }

            if let Some(ref job) = current_job {
                let diff = difficulty.load(Ordering::Acquire);
                self.current_difficulty.store(diff, Ordering::Release);

                // Mine the job
                if let Some((nonce, extranonce2)) = self.mine_job(job, &extranonce1, diff, &mut job_rx).await {
                    // Submit share
                    let submit_req = JsonRpcRequest {
                        id: msg_id,
                        method: "mining.submit",
                        params: vec![
                            json!(format!("{}.{}", self.config.stratum_worker, self.config.payout_address)),
                            json!(job.job_id),
                            json!(extranonce2),
                            json!(job.timestamp.to_string()),
                            json!(nonce),
                        ],
                    };
                    msg_id += 1;

                    let line = serde_json::to_string(&submit_req)? + "\n";
                    if let Err(e) = writer.write_all(line.as_bytes()).await {
                        error!("Failed to submit share: {}", e);
                        break;
                    }
                    debug!("Submitted share for job {}", job.job_id);
                }
            } else {
                // Wait for a job
                tokio::select! {
                    job = job_rx.recv() => {
                        if let Some(j) = job {
                            current_job = Some(j);
                        } else {
                            break; // Channel closed
                        }
                    }
                    _ = tokio::time::sleep(Duration::from_millis(100)) => {}
                }
            }
        }

        reader_handle.abort();
        Ok(())
    }

    /// Mine a Stratum job, returns (nonce_hex, extranonce2_hex) if share found
    async fn mine_job(
        &self,
        job: &StratumJob,
        extranonce1: &str,
        difficulty: u64,
        job_rx: &mut mpsc::Receiver<StratumJob>,
    ) -> Option<(String, String)> {
        // Parse pre_pow_hash
        let pre_pow_hash = match hex::decode(&job.pre_pow_hash) {
            Ok(bytes) if bytes.len() == 32 => {
                let mut arr = [0u8; 32];
                arr.copy_from_slice(&bytes);
                Hash::from_bytes(arr)
            }
            _ => {
                error!("Invalid pre_pow_hash: {}", job.pre_pow_hash);
                return None;
            }
        };

        // Calculate target from difficulty
        // Target = MaxTarget / Difficulty, where MaxTarget = 0xffff << 208
        let target = difficulty_to_target(difficulty);
        debug!(
            "Mining job: prePoWHash={}, timestamp={}, difficulty={}, target={}",
            job.pre_pow_hash, job.timestamp, difficulty, target
        );

        // Generate Matrix for kHeavyHash (derived from prePoWHash)
        let matrix = Matrix::generate(pre_pow_hash);

        // Prepare PowHash hasher with prePoWHash and timestamp
        let base_hasher = PowHash::new(pre_pow_hash, job.timestamp);

        let stats = self.stats.clone();
        let should_stop = self.should_stop.clone();

        // Generate random extranonce2 (8 bytes = 16 hex chars)
        let extranonce2: u64 = rand::random();
        let extranonce2_hex = format!("{:016x}", extranonce2);

        // Combine extranonces for full nonce space
        let _full_extranonce = format!("{}{}", extranonce1, extranonce2_hex);

        // Smaller batch size for lower memory usage
        let batch_size = 10_000u64;
        let mut start_nonce: u64 = rand::random();

        loop {
            if should_stop.load(Ordering::Acquire) {
                return None;
            }

            // Check for new jobs
            if let Ok(new_job) = job_rx.try_recv() {
                if new_job.clean_jobs || new_job.job_id != job.job_id {
                    debug!("New job received, abandoning current work");
                    return None;
                }
            }

            let end_nonce = start_nonce.wrapping_add(batch_size);

            // Sequential nonce search using real kHeavyHash (low memory mode)
            let result = (start_nonce..end_nonce).find(|&nonce| {
                // Step 1: Finalize PowHash with nonce (cSHAKE256 "ProofOfWorkHash")
                let hash = base_hasher.clone().finalize_with_nonce(nonce);
                // Step 2: Apply kHeavyHash (matrix multiplication + cSHAKE256 "HeavyHash")
                let pow_hash = matrix.heavy_hash(hash);
                // Convert to Uint256 for proper comparison (little-endian)
                let pow_value = Uint256::from_le_bytes(*pow_hash.as_bytes());
                pow_value <= target
            });

            stats.hashes_computed.fetch_add(batch_size, Ordering::Release);

            if let Some(nonce) = result {
                // Debug: recompute hash for logging
                let hash = base_hasher.clone().finalize_with_nonce(nonce);
                let pow_hash = matrix.heavy_hash(hash);
                let _pow_value = Uint256::from_le_bytes(*pow_hash.as_bytes());
                debug!("Share details: nonce={:016x}, hash_le={}, target={}", nonce, hex::encode(pow_hash.as_bytes()), target);

                stats.blocks_found.fetch_add(1, Ordering::Release);
                info!("Share found! Nonce: {:016x}, Total shares: {}", nonce, stats.blocks_found.load(Ordering::Acquire));
                return Some((format!("{:016x}", nonce), extranonce2_hex));
            }

            start_nonce = end_nonce;

            // Yield periodically
            if start_nonce.is_multiple_of(batch_size * 10) {
                tokio::task::yield_now().await;
            }
        }
    }

    pub fn stop(&self) {
        self.should_stop.store(true, Ordering::Release);
    }

    pub fn stats_arc(&self) -> Arc<MiningStats> {
        self.stats.clone()
    }
}

/// Parse mining.notify params into StratumJob
fn parse_notify_params(params: &[Value]) -> Option<StratumJob> {
    if params.len() < 5 {
        return None;
    }

    Some(StratumJob {
        job_id: params[0].as_str()?.to_string(),
        pre_pow_hash: params[1].as_str()?.to_string(),
        timestamp: params[2].as_str()?.parse().ok()?,
        target: params[3].as_str()?.to_string(),
        clean_jobs: params[4].as_bool().unwrap_or(false),
    })
}

/// Convert difficulty to target using custom formula for testing.
/// Target = MaxTarget / Difficulty
/// For testing: MaxTarget = 2^256 - 1 (easy shares)
/// Production should use: 0xffff << 208 (standard Stratum)
fn difficulty_to_target(difficulty: u64) -> Uint256 {
    // For testing: use MAX target for easy share finding
    // This matches the modified pool validation
    let max_target = Uint256::MAX;
    max_target / Uint256::from_u64(difficulty.max(1))
}
