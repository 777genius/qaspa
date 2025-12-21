use axum::extract::State;
use axum::Json;
use tracing::info;

use crate::api::dto::{SuccessResponse, TxGenStatusResponse};
use crate::api::AppState;
use crate::error::{ControllerError, Result};

/// GET /api/v1/txgen/status
/// Returns tx generator status
pub async fn get_status(State(state): State<AppState>) -> Result<Json<TxGenStatusResponse>> {
    let cluster_state = state.cluster_state.read();
    Ok(Json(TxGenStatusResponse { running: cluster_state.txgen_running }))
}

/// POST /api/v1/txgen/start
/// Start tx generator (rothschild)
/// Note: There's a small race window between listing containers and starting.
/// If container is removed between check and action, start_container will fail
/// gracefully and return an appropriate error.
pub async fn start_txgen(State(state): State<AppState>) -> Result<Json<SuccessResponse>> {
    // Find rothschild container
    let containers = state.docker.list_by_role("txgen").await?;

    if let Some(container) = containers.first() {
        if container.status != "running" {
            // Handle race condition: container might be removed between check and start
            state.docker.start_container(&container.id).await?;
            info!("Started tx generator {}", container.name);
        }
        Ok(Json(SuccessResponse::ok("Transaction generator started")))
    } else {
        // No rothschild container exists, it should be started via docker-compose
        Err(ControllerError::ContainerNotFound("Transaction generator container not found. Start with --profile txgen".to_string()))
    }
}

/// POST /api/v1/txgen/stop
/// Stop tx generator
/// Note: Same race window consideration as start_txgen.
pub async fn stop_txgen(State(state): State<AppState>) -> Result<Json<SuccessResponse>> {
    let containers = state.docker.list_by_role("txgen").await?;

    if let Some(container) = containers.first() {
        if container.status == "running" {
            // Handle race condition: container might be removed between check and stop
            match state.docker.stop_container(&container.id).await {
                Ok(()) => {
                    info!("Stopped tx generator {}", container.name);
                }
                Err(e) => {
                    // Container was likely removed - treat as already stopped
                    info!("Tx generator stop failed (possibly already removed): {}", e);
                }
            }
        }
        Ok(Json(SuccessResponse::ok("Transaction generator stopped")))
    } else {
        Ok(Json(SuccessResponse::ok("Transaction generator not running")))
    }
}
