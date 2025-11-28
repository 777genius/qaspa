use crate::converter::{consensus::ConsensusConverter, index::IndexConverter};
use async_trait::async_trait;
use kaspa_core::{debug, info, trace};
use kaspa_index_core::notification::Notification as IndexNotification;
use kaspa_notify::{
    collector::{Collector, CollectorNotificationReceiver},
    converter::Converter,
    error::Result,
    notifier::DynNotify,
};
use kaspa_rpc_core::{Notification, RpcUtxosByAddressesEntry, StealthUtxosChangedNotification};
use kaspa_txscript::STEALTH_SCRIPT_VERSION;
use kaspa_utils::triggers::SingleTrigger;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

pub(crate) type CollectorFromConsensus = kaspa_notify::collector::CollectorFrom<ConsensusConverter>;

/// A specialized collector that generates both UtxosChanged and StealthUtxosChanged notifications.
/// When an UtxosChanged notification contains UTXOs with STEALTH_SCRIPT_VERSION (16),
/// it also generates a StealthUtxosChanged notification for those UTXOs.
#[derive(Debug)]
pub struct StealthAwareIndexCollector {
    name: &'static str,
    recv_channel: CollectorNotificationReceiver<IndexNotification>,
    converter: Arc<IndexConverter>,
    is_started: Arc<AtomicBool>,
    collect_shutdown: Arc<SingleTrigger>,
}

impl StealthAwareIndexCollector {
    pub fn new(
        name: &'static str,
        recv_channel: CollectorNotificationReceiver<IndexNotification>,
        converter: Arc<IndexConverter>,
    ) -> Self {
        Self {
            name,
            recv_channel,
            converter,
            collect_shutdown: Arc::new(SingleTrigger::new()),
            is_started: Arc::new(AtomicBool::new(false)),
        }
    }

    fn spawn_collecting_task(self: Arc<Self>, notifier: DynNotify<Notification>) {
        if self.is_started.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_err() {
            return;
        }
        let collect_shutdown = self.collect_shutdown.clone();
        let recv_channel = self.recv_channel.clone();
        let converter = self.converter.clone();

        tokio::spawn(async move {
            trace!("[Collector {}] stealth-aware collecting task starting", self.name);

            while let Ok(notification) = recv_channel.recv().await {
                // Check if this is a UtxosChanged notification
                let is_utxos_changed = matches!(notification, IndexNotification::UtxosChanged(_));

                // Convert the notification using the standard converter
                let converted = converter.convert(notification).await;

                // If it was UtxosChanged, also generate StealthUtxosChanged
                if is_utxos_changed {
                    if let Notification::UtxosChanged(ref utxos_notification) = converted {
                        // Debug: log script versions of all added UTXOs
                        for entry in utxos_notification.added.iter() {
                            info!(
                                "[Collector {}] UTXO added: script version = {}, has_address = {}",
                                self.name,
                                entry.utxo_entry.script_public_key.version(),
                                entry.address.is_some()
                            );
                        }

                        // Filter for stealth UTXOs (script version 16)
                        let stealth_added: Vec<RpcUtxosByAddressesEntry> = utxos_notification
                            .added
                            .iter()
                            .filter(|entry| entry.utxo_entry.script_public_key.version() == STEALTH_SCRIPT_VERSION)
                            .cloned()
                            .collect();

                        let stealth_removed: Vec<RpcUtxosByAddressesEntry> = utxos_notification
                            .removed
                            .iter()
                            .filter(|entry| entry.utxo_entry.script_public_key.version() == STEALTH_SCRIPT_VERSION)
                            .cloned()
                            .collect();

                        // Only send StealthUtxosChanged if there are stealth UTXOs
                        if !stealth_added.is_empty() || !stealth_removed.is_empty() {
                            debug!(
                                "[Collector {}] generated StealthUtxosChanged: {} added, {} removed",
                                self.name,
                                stealth_added.len(),
                                stealth_removed.len(),
                            );

                            let stealth_notification = Notification::StealthUtxosChanged(StealthUtxosChangedNotification {
                                added: Arc::new(stealth_added),
                                removed: Arc::new(stealth_removed),
                            });

                            if let Err(err) = notifier.notify(stealth_notification) {
                                trace!("[Collector {}] stealth notification sender error: {}", self.name, err);
                            }
                        }
                    }
                }

                // Send the original converted notification
                if let Err(err) = notifier.notify(converted) {
                    trace!("[Collector {}] notification sender error: {}", self.name, err);
                }
            }

            debug!("[Collector {}] notification stream ended", self.name);
            collect_shutdown.trigger.trigger();
            trace!("[Collector {}] stealth-aware collecting task ended", self.name);
        });
    }

    async fn join_collecting_task(self: &Arc<Self>) -> Result<()> {
        trace!("[Collector {}] joining", self.name);
        self.collect_shutdown.listener.clone().await;
        debug!("[Collector {}] terminated", self.name);
        Ok(())
    }
}

#[async_trait]
impl Collector<Notification> for StealthAwareIndexCollector {
    fn start(self: Arc<Self>, notifier: DynNotify<Notification>) {
        self.spawn_collecting_task(notifier);
    }

    async fn join(self: Arc<Self>) -> Result<()> {
        self.join_collecting_task().await
    }
}

// Keep the old type alias for backward compatibility if needed elsewhere
pub(crate) type CollectorFromIndex = kaspa_notify::collector::CollectorFrom<IndexConverter>;
