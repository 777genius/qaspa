use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::response::Response;
use futures::{SinkExt, StreamExt};
use serde::Deserialize;
use std::time::Duration;
use tokio::sync::broadcast;
use tracing::{debug, error, info, warn};

use crate::api::AppState;

/// Maximum number of log lines to fetch (prevents DoS via tail=u64::MAX)
const MAX_TAIL_LINES: u64 = 10_000;

/// Maximum size of a single log message in bytes (1MB)
const MAX_LOG_MESSAGE_SIZE: usize = 1024 * 1024;

/// Broadcast channel capacity for log streaming
const LOG_CHANNEL_CAPACITY: usize = 10_000;

/// Timeout for WebSocket send operations (disconnect slow clients to prevent resource leak)
const WS_SEND_TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Debug, Deserialize)]
pub struct LogsQuery {
    /// Container ID or name to stream logs from. If not specified, streams from all containers.
    pub container: Option<String>,
    #[serde(default = "default_tail")]
    pub tail: u64,
}

fn default_tail() -> u64 {
    100
}

/// GET /ws/logs?container={id}&tail={n}
/// WebSocket endpoint for container logs
pub async fn handler(State(state): State<AppState>, Query(query): Query<LogsQuery>, ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(move |socket| handle_socket(socket, state, query))
}

async fn handle_socket(socket: WebSocket, state: AppState, query: LogsQuery) {
    let (mut sender, mut receiver) = socket.split();

    // Get list of containers to stream from
    let containers: Vec<String> = if let Some(ref container) = query.container {
        // Validate container belongs to this cluster
        let container_valid = {
            let cluster_state = state.cluster_state.read();
            cluster_state.nodes.values().any(|n| n.id == *container || n.name == *container)
                || cluster_state.miners.values().any(|m| m.id == *container || m.name == *container)
        };

        if !container_valid {
            error!("Rejected logs request for unknown container: {}", container);
            let _ = sender
                .send(Message::Text(
                    serde_json::json!({
                        "type": "error",
                        "data": { "message": "Container not found in cluster" }
                    })
                    .to_string()
                    .into(),
                ))
                .await;
            let _ = sender.send(Message::Close(None)).await;
            return;
        }
        vec![container.clone()]
    } else {
        // Stream from all containers
        let cluster_state = state.cluster_state.read();
        let mut all_containers: Vec<String> = cluster_state.nodes.keys().cloned().collect();
        all_containers.extend(cluster_state.miners.keys().cloned());
        all_containers
    };

    if containers.is_empty() {
        info!("No containers to stream logs from");
        let _ = sender
            .send(Message::Text(
                serde_json::json!({
                    "type": "info",
                    "data": { "message": "No containers available" }
                })
                .to_string()
                .into(),
            ))
            .await;
        return;
    }

    // Clamp tail to prevent DoS (requesting billions of log lines)
    let tail = query.tail.min(MAX_TAIL_LINES);
    if query.tail > MAX_TAIL_LINES {
        warn!("Clamped tail from {} to {} for containers {:?}", query.tail, MAX_TAIL_LINES, containers);
    }

    let container_display = query.container.clone().unwrap_or_else(|| "all".to_string());
    info!("WebSocket client connected to /ws/logs for {} (tail={})", container_display, tail);

    // Create broadcast channel for logs with larger capacity
    let (tx, mut rx) = broadcast::channel::<String>(LOG_CHANNEL_CAPACITY);

    // Spawn tasks to stream logs from all containers
    let mut log_tasks = Vec::new();
    for container_id in containers {
        let docker = state.docker.clone();
        let tx = tx.clone();
        let container_id_clone = container_id.clone();
        let task = tokio::spawn(async move {
            if let Err(e) = docker.stream_logs(&container_id_clone, tail, tx).await {
                error!("Log streaming error for {}: {}", container_id_clone, e);
            }
        });
        log_tasks.push(task);
    }
    drop(tx); // Drop original sender so channel closes when all tasks complete

    // Spawn task to forward logs to the client
    let send_task = tokio::spawn(async move {
        while let Ok(line) = rx.recv().await {
            // Truncate oversized log messages to prevent memory issues
            // Use floor_char_boundary to safely truncate at UTF-8 char boundaries
            let truncated_line = if line.len() > MAX_LOG_MESSAGE_SIZE {
                warn!("Truncating oversized log message ({} bytes)", line.len());
                // Find safe truncation point at char boundary
                let safe_end = line
                    .char_indices()
                    .take_while(|(i, _)| *i < MAX_LOG_MESSAGE_SIZE)
                    .last()
                    .map(|(i, c)| i + c.len_utf8())
                    .unwrap_or(0);
                format!("{}... [truncated]", &line[..safe_end])
            } else {
                line
            };

            let msg = serde_json::json!({
                "type": "log",
                "data": {
                    "message": truncated_line,
                    "timestamp": chrono::Utc::now().to_rfc3339()
                }
            });

            match serde_json::to_string(&msg) {
                Ok(json) => {
                    // Use timeout to disconnect slow/unresponsive clients
                    // This prevents resource leaks from blocked sends
                    match tokio::time::timeout(WS_SEND_TIMEOUT, sender.send(Message::Text(json.into()))).await {
                        Ok(Ok(_)) => {}
                        Ok(Err(_)) => {
                            // Send error - client disconnected
                            break;
                        }
                        Err(_) => {
                            // Timeout - client is too slow
                            warn!("WebSocket send timeout, disconnecting slow client");
                            break;
                        }
                    }
                }
                Err(e) => {
                    error!("Failed to serialize log: {}", e);
                }
            }
        }
    });

    // Wait for client to disconnect
    while let Some(msg) = receiver.next().await {
        match msg {
            Ok(Message::Close(_)) => {
                debug!("Client sent close");
                break;
            }
            Ok(Message::Ping(_)) => {
                debug!("Received ping");
            }
            Err(e) => {
                error!("WebSocket error: {}", e);
                break;
            }
            _ => {}
        }
    }

    // Abort tasks and wait for cleanup to ensure resources are released
    for task in &log_tasks {
        task.abort();
    }
    send_task.abort();
    // Await to ensure tasks are fully terminated and resources are dropped
    for task in log_tasks {
        let _ = task.await;
    }
    let _ = send_task.await;

    let container_display = query.container.unwrap_or_else(|| "all".to_string());
    info!("WebSocket client disconnected from /ws/logs for {}", container_display);
}
