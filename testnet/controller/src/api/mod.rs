pub mod dto;
pub mod handlers;
pub mod routes;
pub mod ws;

use std::sync::Arc;
use tokio::sync::broadcast;

use crate::config::Config;
use crate::docker::DockerManager;
use crate::monitoring::WsEvent;
use crate::ports::PortAllocator;
use crate::state::SharedClusterState;
use sea_orm::DatabaseConnection;

/// Application state shared across handlers
#[derive(Clone)]
pub struct AppState {
    pub config: Arc<Config>,
    pub docker: Arc<DockerManager>,
    pub port_allocator: Arc<PortAllocator>,
    pub cluster_state: SharedClusterState,
    pub event_tx: broadcast::Sender<WsEvent>,
    pub db_conn: DatabaseConnection,
}

pub use routes::create_router;
