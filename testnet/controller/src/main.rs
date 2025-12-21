use std::sync::Arc;
use tokio::sync::{broadcast, watch};
use tracing::info;
use tracing_subscriber::EnvFilter;

use testnet_controller::api::{create_router, AppState};
use testnet_controller::config::Config;
use testnet_controller::db::{self, MetricsWriter};
use testnet_controller::docker::DockerManager;
use testnet_controller::monitoring::{MonitoringAggregator, WsEvent};
use testnet_controller::ports::PortAllocator;
use testnet_controller::state::new_shared_state;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt().with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"))).init();

    info!("Starting Testnet Controller");

    // Load configuration
    let config = Arc::new(Config::load());
    info!("HTTP bind: {}", config.http_bind);
    info!("Static dir: {:?}", config.static_dir);

    // Initialize Docker manager
    let docker = Arc::new(DockerManager::new(config.clone()).await?);
    docker.ensure_network().await?;
    info!("Docker connection established");

    // Initialize port allocator
    let port_allocator = Arc::new(PortAllocator::new(config.grpc_port_start, config.p2p_port_start)?);

    // Restore allocated ports from existing containers
    let containers = docker.list_containers().await?;
    port_allocator.restore_from_containers(&containers);
    info!("Found {} existing containers, {} port pairs allocated", containers.len(), port_allocator.allocated_count());

    // Initialize cluster state
    let cluster_state = new_shared_state();
    {
        let mut state = cluster_state.write();
        state.update_from_containers(&containers);
    }

    // Initialize database
    let db_conn = db::connect(&config.database_url).await?;
    db::run_migrations(&db_conn).await?;

    // Create metrics writer
    let metrics_writer = Arc::new(MetricsWriter::new(db_conn.clone(), config.metrics_flush_interval_ms, config.metrics_batch_size));

    // Create event broadcast channel with larger capacity for high-load scenarios
    // This prevents event loss when many nodes are being monitored simultaneously
    const EVENT_CHANNEL_CAPACITY: usize = 10_000;
    let (event_tx, _) = broadcast::channel::<WsEvent>(EVENT_CHANNEL_CAPACITY);

    // Create app state
    let app_state = AppState {
        config: config.clone(),
        docker: docker.clone(),
        port_allocator,
        cluster_state: cluster_state.clone(),
        event_tx: event_tx.clone(),
        db_conn: db_conn.clone(),
    };

    // Create router
    let router = create_router(app_state, config.static_dir.clone());

    // Create shutdown channel for graceful shutdown of all components
    let (shutdown_tx, shutdown_rx) = watch::channel(false);

    // Start metrics writer flush task
    let flush_shutdown_rx = shutdown_rx.clone();
    metrics_writer.clone().start_flush_task(flush_shutdown_rx);

    // Spawn monitoring task
    let monitoring_docker = docker.clone();
    let monitoring_state = cluster_state.clone();
    let monitoring_tx = event_tx.clone();
    let monitoring_config = config.clone();
    let monitoring_writer = metrics_writer.clone();
    let monitoring_handle = tokio::spawn(async move {
        let mut aggregator = MonitoringAggregator::new(
            monitoring_docker,
            monitoring_state,
            monitoring_config.poll_interval_ms,
            monitoring_config.grpc_timeout_ms,
            monitoring_tx,
            shutdown_rx,
            Some(monitoring_writer),
        );
        aggregator.run().await;
    });

    // Start HTTP server
    let listener = tokio::net::TcpListener::bind(&config.http_bind).await?;
    info!("Listening on http://{}", config.http_bind);

    // Run server with graceful shutdown
    axum::serve(listener, router).with_graceful_shutdown(shutdown_signal()).await?;

    // Signal monitoring task to stop
    info!("Signaling monitoring task to stop...");
    let _ = shutdown_tx.send(true);

    // Wait for monitoring task to complete (with timeout)
    match tokio::time::timeout(std::time::Duration::from_secs(5), monitoring_handle).await {
        Ok(Ok(())) => info!("Monitoring task stopped gracefully"),
        Ok(Err(e)) => tracing::warn!("Monitoring task panicked: {}", e),
        Err(_) => tracing::warn!("Monitoring task did not stop within timeout"),
    }

    info!("Testnet Controller stopped");
    Ok(())
}

async fn shutdown_signal() {
    use tracing::{error, warn};

    let ctrl_c = async {
        match tokio::signal::ctrl_c().await {
            Ok(()) => {}
            Err(e) => {
                error!("Failed to install Ctrl+C handler: {}", e);
                // Fall back to pending - will rely on SIGTERM or other signals
                std::future::pending::<()>().await;
            }
        }
    };

    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut signal) => {
                signal.recv().await;
            }
            Err(e) => {
                warn!("Failed to install SIGTERM handler: {}", e);
                // Fall back to pending - will rely on Ctrl+C
                std::future::pending::<()>().await;
            }
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {
            info!("Received Ctrl+C, shutting down...");
        }
        _ = terminate => {
            info!("Received SIGTERM, shutting down...");
        }
    }
}
