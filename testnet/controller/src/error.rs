use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde::Serialize;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ControllerError {
    #[error("Docker error: {0}")]
    Docker(#[from] bollard::errors::Error),

    #[error("gRPC error: {0}")]
    Grpc(String),

    #[error("Container not found: {0}")]
    ContainerNotFound(String),

    #[error("Node not found: {0}")]
    NodeNotFound(String),

    #[error("Miner not found: {0}")]
    MinerNotFound(String),

    #[error("No ports available")]
    NoPortsAvailable,

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("Operation failed: {0}")]
    OperationFailed(String),

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    #[error("Internal error: {0}")]
    Internal(String),
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
    message: String,
}

impl IntoResponse for ControllerError {
    fn into_response(self) -> Response {
        let (status, error_type, message) = match &self {
            // Mask internal details for sensitive errors (may contain paths, addresses, etc.)
            ControllerError::Docker(_) => {
                tracing::error!("Docker error: {}", self);
                (StatusCode::INTERNAL_SERVER_ERROR, "docker_error", "Docker operation failed".to_string())
            }
            ControllerError::Grpc(_) => {
                tracing::error!("gRPC error: {}", self);
                (StatusCode::BAD_GATEWAY, "grpc_error", "gRPC communication failed".to_string())
            }
            ControllerError::Serialization(_) => {
                tracing::error!("Serialization error: {}", self);
                (StatusCode::INTERNAL_SERVER_ERROR, "serialization_error", "Data processing failed".to_string())
            }
            ControllerError::Internal(_) => {
                tracing::error!("Internal error: {}", self);
                (StatusCode::INTERNAL_SERVER_ERROR, "internal_error", "Internal server error".to_string())
            }
            // Safe to expose these user-facing errors
            ControllerError::ContainerNotFound(id) => {
                (StatusCode::NOT_FOUND, "container_not_found", format!("Container not found: {}", id))
            }
            ControllerError::NodeNotFound(id) => (StatusCode::NOT_FOUND, "node_not_found", format!("Node not found: {}", id)),
            ControllerError::MinerNotFound(id) => (StatusCode::NOT_FOUND, "miner_not_found", format!("Miner not found: {}", id)),
            ControllerError::NoPortsAvailable => (StatusCode::SERVICE_UNAVAILABLE, "no_ports", "No ports available".to_string()),
            ControllerError::InvalidConfig(msg) => {
                (StatusCode::BAD_REQUEST, "invalid_config", format!("Invalid configuration: {}", msg))
            }
            ControllerError::OperationFailed(msg) => {
                (StatusCode::INTERNAL_SERVER_ERROR, "operation_failed", format!("Operation failed: {}", msg))
            }
        };

        let body = ErrorResponse { error: error_type.to_string(), message };

        (status, Json(body)).into_response()
    }
}

pub type Result<T> = std::result::Result<T, ControllerError>;
