use axum::Json;
use axum::extract::{Path, Query, State};
use chrono::{TimeZone, Utc};
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder, QuerySelect};

use crate::api::AppState;
use crate::api::dto::{
    AggregateMetricsHistoryResponse, AggregateMetricsPoint, MetricsHistoryQuery, MinerMetricsHistoryResponse, MinerMetricsPoint,
    NodeMetricsHistoryResponse, NodeMetricsPoint,
};
use crate::db::entities::{aggregate_metrics_history, miner_metrics_history, node_metrics_history};
use crate::error::Result;

/// GET /api/v1/metrics/history
/// Returns aggregate cluster metrics history
pub async fn get_aggregate_history(
    State(state): State<AppState>,
    Query(query): Query<MetricsHistoryQuery>,
) -> Result<Json<AggregateMetricsHistoryResponse>> {
    let mut q = aggregate_metrics_history::Entity::find().order_by_desc(aggregate_metrics_history::Column::RecordedAt);

    // Apply time filters
    if let Some(from_dt) = query.from.and_then(|from_ts| Utc.timestamp_opt(from_ts, 0).single()) {
        q = q.filter(aggregate_metrics_history::Column::RecordedAt.gte(from_dt));
    }
    if let Some(to_dt) = query.to.and_then(|to_ts| Utc.timestamp_opt(to_ts, 0).single()) {
        q = q.filter(aggregate_metrics_history::Column::RecordedAt.lte(to_dt));
    }

    // Apply limit
    let limit = query.limit.clamp(1, 10000) as u64;
    q = q.limit(limit);

    let records =
        q.all(&state.db_conn).await.map_err(|e| crate::error::ControllerError::Internal(format!("Database error: {}", e)))?;

    let data: Vec<AggregateMetricsPoint> = records
        .into_iter()
        .map(|r| AggregateMetricsPoint {
            timestamp: r.recorded_at.timestamp(),
            total_nodes: r.total_nodes,
            running_nodes: r.running_nodes,
            synced_nodes: r.synced_nodes,
            total_miners: r.total_miners,
            running_miners: r.running_miners,
            total_block_count: r.total_block_count,
            virtual_daa_score: r.virtual_daa_score,
            total_hashrate: r.total_hashrate,
        })
        .collect();

    Ok(Json(AggregateMetricsHistoryResponse { data }))
}

/// GET /api/v1/metrics/history/nodes/:id
/// Returns metrics history for a specific node
pub async fn get_node_history(
    State(state): State<AppState>,
    Path(node_id): Path<String>,
    Query(query): Query<MetricsHistoryQuery>,
) -> Result<Json<NodeMetricsHistoryResponse>> {
    let mut q = node_metrics_history::Entity::find()
        .filter(node_metrics_history::Column::NodeId.eq(&node_id))
        .order_by_desc(node_metrics_history::Column::RecordedAt);

    // Apply time filters
    if let Some(from_dt) = query.from.and_then(|from_ts| Utc.timestamp_opt(from_ts, 0).single()) {
        q = q.filter(node_metrics_history::Column::RecordedAt.gte(from_dt));
    }
    if let Some(to_dt) = query.to.and_then(|to_ts| Utc.timestamp_opt(to_ts, 0).single()) {
        q = q.filter(node_metrics_history::Column::RecordedAt.lte(to_dt));
    }

    // Apply limit
    let limit = query.limit.clamp(1, 10000) as u64;
    q = q.limit(limit);

    let records =
        q.all(&state.db_conn).await.map_err(|e| crate::error::ControllerError::Internal(format!("Database error: {}", e)))?;

    let data: Vec<NodeMetricsPoint> = records
        .into_iter()
        .map(|r| NodeMetricsPoint {
            timestamp: r.recorded_at.timestamp(),
            block_count: r.block_count,
            header_count: r.header_count,
            virtual_daa_score: r.virtual_daa_score,
            peer_count: r.peer_count,
            mempool_size: r.mempool_size,
            is_synced: r.is_synced,
        })
        .collect();

    Ok(Json(NodeMetricsHistoryResponse { data }))
}

/// GET /api/v1/metrics/history/miners/:id
/// Returns metrics history for a specific miner
pub async fn get_miner_history(
    State(state): State<AppState>,
    Path(miner_id): Path<String>,
    Query(query): Query<MetricsHistoryQuery>,
) -> Result<Json<MinerMetricsHistoryResponse>> {
    let mut q = miner_metrics_history::Entity::find()
        .filter(miner_metrics_history::Column::MinerId.eq(&miner_id))
        .order_by_desc(miner_metrics_history::Column::RecordedAt);

    // Apply time filters
    if let Some(from_dt) = query.from.and_then(|from_ts| Utc.timestamp_opt(from_ts, 0).single()) {
        q = q.filter(miner_metrics_history::Column::RecordedAt.gte(from_dt));
    }
    if let Some(to_dt) = query.to.and_then(|to_ts| Utc.timestamp_opt(to_ts, 0).single()) {
        q = q.filter(miner_metrics_history::Column::RecordedAt.lte(to_dt));
    }

    // Apply limit
    let limit = query.limit.clamp(1, 10000) as u64;
    q = q.limit(limit);

    let records =
        q.all(&state.db_conn).await.map_err(|e| crate::error::ControllerError::Internal(format!("Database error: {}", e)))?;

    let data: Vec<MinerMetricsPoint> = records
        .into_iter()
        .map(|r| MinerMetricsPoint { timestamp: r.recorded_at.timestamp(), hashrate: r.hashrate, blocks_found: r.blocks_found })
        .collect();

    Ok(Json(MinerMetricsHistoryResponse { data }))
}
