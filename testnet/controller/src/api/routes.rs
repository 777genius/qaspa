use axum::Router;
use axum::extract::DefaultBodyLimit;
use axum::http::{Method, header};
use axum::routing::{delete, get, post};
use std::path::PathBuf;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
use tower_http::trace::TraceLayer;

/// Maximum request body size (1 MB) - prevents OOM from large payloads
const MAX_REQUEST_SIZE: usize = 1024 * 1024;

use super::AppState;
use super::handlers::{cluster, dag, metrics_history, miners, nodes, txgen};
use super::ws;

/// Create the main API router
pub fn create_router(state: AppState, static_dir: PathBuf) -> Router {
    // CORS configuration - allow all origins for development
    // In production, this should be restricted via environment variables
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::DELETE, Method::OPTIONS])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION, header::ACCEPT]);

    // API routes
    let api = Router::new()
        // Cluster
        .route("/cluster", get(cluster::get_cluster))
        // Nodes
        .route("/nodes", get(nodes::list_nodes))
        .route("/nodes", post(nodes::create_node))
        .route("/nodes/{id}", get(nodes::get_node))
        .route("/nodes/{id}", delete(nodes::delete_node))
        .route("/nodes/{id}/start", post(nodes::start_node))
        .route("/nodes/{id}/stop", post(nodes::stop_node))
        .route("/nodes/{id}/restart", post(nodes::restart_node))
        // Miners
        .route("/miners", get(miners::list_miners))
        .route("/miners", post(miners::create_miner))
        .route("/miners/{id}", get(miners::get_miner))
        .route("/miners/{id}", delete(miners::delete_miner))
        .route("/miners/{id}/start", post(miners::start_miner))
        .route("/miners/{id}/stop", post(miners::stop_miner))
        // TxGen
        .route("/txgen/status", get(txgen::get_status))
        .route("/txgen/start", post(txgen::start_txgen))
        .route("/txgen/stop", post(txgen::stop_txgen))
        // DAG
        .route("/nodes/{id}/dag", get(dag::get_dag_info))
        .route("/nodes/{id}/dag/blocks", get(dag::get_blocks))
        .route("/nodes/{id}/dag/blocks/{hash}", get(dag::get_block))
        // Metrics History
        .route("/metrics/history", get(metrics_history::get_aggregate_history))
        .route("/metrics/history/nodes/{id}", get(metrics_history::get_node_history))
        .route("/metrics/history/miners/{id}", get(metrics_history::get_miner_history));

    // WebSocket routes
    let ws_routes = Router::new()
        .route("/events", get(ws::events::handler))
        .route("/logs", get(ws::logs::handler))
        .route("/dag", get(ws::dag::handler));

    // Static files for Flutter web
    let static_service = ServeDir::new(static_dir);

    Router::new()
        .nest("/api/v1", api)
        .nest("/ws", ws_routes)
        .fallback_service(static_service)
        .layer(DefaultBodyLimit::max(MAX_REQUEST_SIZE))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
