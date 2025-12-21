use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::response::Response;
use futures::{SinkExt, StreamExt};
use std::time::Duration;
use tokio::sync::broadcast::{self, error::RecvError};
use tracing::{debug, error, info, warn};

use crate::api::AppState;
use crate::monitoring::WsEvent;

/// Timeout for WebSocket send operations (disconnect slow clients to prevent resource leak)
const WS_SEND_TIMEOUT: Duration = Duration::from_secs(30);

/// GET /ws/events
/// WebSocket endpoint for cluster events
pub async fn handler(State(state): State<AppState>, ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(move |socket| handle_socket(socket, state.event_tx.subscribe()))
}

async fn handle_socket(socket: WebSocket, mut rx: broadcast::Receiver<WsEvent>) {
    let (mut sender, mut receiver) = socket.split();

    info!("WebSocket client connected to /ws/events");

    // Spawn task to forward events to the client
    let send_task = tokio::spawn(async move {
        loop {
            match rx.recv().await {
                Ok(event) => {
                    match serde_json::to_string(&event) {
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
                            error!("Failed to serialize event: {}", e);
                        }
                    }
                }
                Err(RecvError::Lagged(n)) => {
                    // Receiver was too slow, n messages were dropped
                    warn!("WebSocket client lagging, {} events dropped due to backpressure", n);
                    // Continue receiving - don't disconnect slow clients
                }
                Err(RecvError::Closed) => {
                    // Channel closed, monitoring aggregator stopped
                    info!("Event broadcast channel closed, stopping WebSocket sender");
                    break;
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
            Ok(Message::Ping(_data)) => {
                // Pong is handled automatically by axum
                debug!("Received ping");
            }
            Err(e) => {
                error!("WebSocket error: {}", e);
                break;
            }
            _ => {}
        }
    }

    // Abort the send task and wait for it to finish to ensure cleanup
    send_task.abort();
    // Await to ensure the task is fully terminated and resources (like broadcast::Receiver) are dropped
    let _ = send_task.await;

    info!("WebSocket client disconnected from /ws/events");
}
