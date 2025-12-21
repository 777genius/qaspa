use super::entities::{aggregate_metrics_history, miner_metrics_history, node_metrics_history};
use crate::state::{AggregateMetrics, NodeMetrics};
use chrono::Utc;
use sea_orm::{ActiveModelTrait, DatabaseConnection, Set};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use tracing::{debug, error};

pub struct MetricsWriter {
    db: DatabaseConnection,
    node_buffer: Arc<Mutex<Vec<NodeMetricsRecord>>>,
    miner_buffer: Arc<Mutex<Vec<MinerMetricsRecord>>>,
    aggregate_buffer: Arc<Mutex<Vec<AggregateMetricsRecord>>>,
    flush_interval: Duration,
    batch_size: usize,
    last_flush: Arc<Mutex<Instant>>,
}

#[derive(Clone)]
struct NodeMetricsRecord {
    node_id: String,
    block_count: i64,
    header_count: i64,
    virtual_daa_score: i64,
    peer_count: i32,
    mempool_size: i64,
    is_synced: bool,
}

#[derive(Clone)]
struct MinerMetricsRecord {
    miner_id: String,
    hashrate: f64,
    blocks_found: i64,
}

#[derive(Clone)]
struct AggregateMetricsRecord {
    total_nodes: i32,
    running_nodes: i32,
    synced_nodes: i32,
    total_miners: i32,
    running_miners: i32,
    total_block_count: i64,
    virtual_daa_score: i64,
    total_hashrate: f64,
}

impl MetricsWriter {
    pub fn new(db: DatabaseConnection, flush_interval_ms: u64, batch_size: usize) -> Self {
        Self {
            db,
            node_buffer: Arc::new(Mutex::new(Vec::with_capacity(batch_size))),
            miner_buffer: Arc::new(Mutex::new(Vec::with_capacity(batch_size))),
            aggregate_buffer: Arc::new(Mutex::new(Vec::with_capacity(batch_size))),
            flush_interval: Duration::from_millis(flush_interval_ms),
            batch_size,
            last_flush: Arc::new(Mutex::new(Instant::now())),
        }
    }

    pub async fn record_node_metrics(&self, node_id: &str, metrics: &NodeMetrics) {
        let record = NodeMetricsRecord {
            node_id: node_id.to_string(),
            block_count: metrics.block_count as i64,
            header_count: metrics.header_count as i64,
            virtual_daa_score: metrics.virtual_daa_score as i64,
            peer_count: metrics.peer_count as i32,
            mempool_size: metrics.mempool_size as i64,
            is_synced: metrics.is_synced,
        };

        let mut buffer = self.node_buffer.lock().await;
        buffer.push(record);
        drop(buffer);

        self.maybe_flush().await;
    }

    pub async fn record_miner_metrics(&self, miner_id: &str, hashrate: f64, blocks_found: u64) {
        let record = MinerMetricsRecord { miner_id: miner_id.to_string(), hashrate, blocks_found: blocks_found as i64 };

        let mut buffer = self.miner_buffer.lock().await;
        buffer.push(record);
        drop(buffer);

        self.maybe_flush().await;
    }

    pub async fn record_aggregate_metrics(&self, metrics: &AggregateMetrics) {
        let record = AggregateMetricsRecord {
            total_nodes: metrics.total_nodes as i32,
            running_nodes: metrics.running_nodes as i32,
            synced_nodes: metrics.synced_nodes as i32,
            total_miners: metrics.total_miners as i32,
            running_miners: metrics.running_miners as i32,
            total_block_count: metrics.total_block_count as i64,
            virtual_daa_score: metrics.virtual_daa_score as i64,
            total_hashrate: metrics.total_hashrate,
        };

        let mut buffer = self.aggregate_buffer.lock().await;
        buffer.push(record);
        drop(buffer);

        self.maybe_flush().await;
    }

    async fn maybe_flush(&self) {
        let should_flush = {
            let node_len = self.node_buffer.lock().await.len();
            let miner_len = self.miner_buffer.lock().await.len();
            let aggregate_len = self.aggregate_buffer.lock().await.len();
            let last_flush = self.last_flush.lock().await;

            let total_records = node_len + miner_len + aggregate_len;
            let time_elapsed = last_flush.elapsed() >= self.flush_interval;

            total_records >= self.batch_size || (time_elapsed && total_records > 0)
        };

        if should_flush {
            self.flush().await;
        }
    }

    pub async fn flush(&self) {
        let node_records: Vec<_> = {
            let mut buffer = self.node_buffer.lock().await;
            std::mem::take(&mut *buffer)
        };

        let miner_records: Vec<_> = {
            let mut buffer = self.miner_buffer.lock().await;
            std::mem::take(&mut *buffer)
        };

        let aggregate_records: Vec<_> = {
            let mut buffer = self.aggregate_buffer.lock().await;
            std::mem::take(&mut *buffer)
        };

        *self.last_flush.lock().await = Instant::now();

        let total = node_records.len() + miner_records.len() + aggregate_records.len();
        if total == 0 {
            return;
        }

        debug!(
            "Flushing {} metrics records ({} node, {} miner, {} aggregate)",
            total,
            node_records.len(),
            miner_records.len(),
            aggregate_records.len()
        );

        // Insert node metrics
        for record in node_records {
            let model = node_metrics_history::ActiveModel {
                node_id: Set(record.node_id),
                block_count: Set(record.block_count),
                header_count: Set(record.header_count),
                virtual_daa_score: Set(record.virtual_daa_score),
                peer_count: Set(record.peer_count),
                mempool_size: Set(record.mempool_size),
                is_synced: Set(record.is_synced),
                recorded_at: Set(Utc::now().into()),
                ..Default::default()
            };
            if let Err(e) = model.insert(&self.db).await {
                error!("Failed to insert node metrics: {}", e);
            }
        }

        // Insert miner metrics
        for record in miner_records {
            let model = miner_metrics_history::ActiveModel {
                miner_id: Set(record.miner_id),
                hashrate: Set(record.hashrate),
                blocks_found: Set(record.blocks_found),
                recorded_at: Set(Utc::now().into()),
                ..Default::default()
            };
            if let Err(e) = model.insert(&self.db).await {
                error!("Failed to insert miner metrics: {}", e);
            }
        }

        // Insert aggregate metrics
        for record in aggregate_records {
            let model = aggregate_metrics_history::ActiveModel {
                total_nodes: Set(record.total_nodes),
                running_nodes: Set(record.running_nodes),
                synced_nodes: Set(record.synced_nodes),
                total_miners: Set(record.total_miners),
                running_miners: Set(record.running_miners),
                total_block_count: Set(record.total_block_count),
                virtual_daa_score: Set(record.virtual_daa_score),
                total_hashrate: Set(record.total_hashrate),
                recorded_at: Set(Utc::now().into()),
                ..Default::default()
            };
            if let Err(e) = model.insert(&self.db).await {
                error!("Failed to insert aggregate metrics: {}", e);
            }
        }
    }

    /// Start a background task to periodically flush the buffers
    pub fn start_flush_task(self: Arc<Self>, mut shutdown_rx: tokio::sync::watch::Receiver<bool>) {
        let writer = self.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(writer.flush_interval);
            loop {
                tokio::select! {
                    _ = interval.tick() => {
                        writer.flush().await;
                    }
                    _ = shutdown_rx.changed() => {
                        if *shutdown_rx.borrow() {
                            // Final flush before shutdown
                            writer.flush().await;
                            break;
                        }
                    }
                }
            }
        });
    }
}
