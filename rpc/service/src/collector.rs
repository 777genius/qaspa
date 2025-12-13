use crate::converter::{consensus::ConsensusConverter, index::IndexConverter};
use async_trait::async_trait;
use kaspa_consensus_notify::notification::Notification as ConsensusNotification;
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
use kaspa_utils::hex::FromHex;
use kaspa_utils::triggers::SingleTrigger;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

/// A consensus collector that additionally emits wallet-level
/// `MasterDelegationExpiringSoon` notifications based on virtual DAA ticks.
///
/// This avoids registering multiple subscribers for `VirtualDaaScoreChanged`.
pub struct MasterAwareConsensusCollector {
    name: &'static str,
    recv_channel: CollectorNotificationReceiver<ConsensusNotification>,
    converter: Arc<ConsensusConverter>,
    mldsa_anchor_keys: Arc<Mutex<std::collections::HashSet<[u8; 32]>>>,
    delegation_provider: Arc<Mutex<Option<Arc<dyn crate::service::DelegationProvider>>>>,
    warn_window_daa: u64,
    check_in_progress: Arc<AtomicBool>,
    is_started: Arc<AtomicBool>,
    collect_shutdown: Arc<SingleTrigger>,
    last_emitted: Arc<Mutex<std::collections::HashMap<([u8; 32], u64), u64>>>,
}

impl std::fmt::Debug for MasterAwareConsensusCollector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("MasterAwareConsensusCollector")
            .field("name", &self.name)
            .field("warn_window_daa", &self.warn_window_daa)
            .finish()
    }
}

impl MasterAwareConsensusCollector {
    pub fn new(
        name: &'static str,
        recv_channel: CollectorNotificationReceiver<ConsensusNotification>,
        converter: Arc<ConsensusConverter>,
        mldsa_anchor_keys: Arc<Mutex<std::collections::HashSet<[u8; 32]>>>,
        delegation_provider: Arc<Mutex<Option<Arc<dyn crate::service::DelegationProvider>>>>,
        warn_window_daa: u64,
    ) -> Self {
        Self {
            name,
            recv_channel,
            converter,
            mldsa_anchor_keys,
            delegation_provider,
            warn_window_daa,
            collect_shutdown: Arc::new(SingleTrigger::new()),
            is_started: Arc::new(AtomicBool::new(false)),
            check_in_progress: Arc::new(AtomicBool::new(false)),
            last_emitted: Arc::new(Mutex::new(std::collections::HashMap::new())),
        }
    }

    fn should_emit(&self, anchor: [u8; 32], delegation_id: u64, current_daa: u64) -> bool {
        let mut guard = self.last_emitted.lock().unwrap();
        let key = (anchor, delegation_id);
        match guard.get(&key).copied() {
            None => {
                guard.insert(key, current_daa);
                true
            }
            Some(prev) => {
                if current_daa.saturating_sub(prev) >= self.warn_window_daa {
                    guard.insert(key, current_daa);
                    true
                } else {
                    false
                }
            }
        }
    }

    fn parse_account_id_hex(&self, bytes: &[u8]) -> Option<[u8; 32]> {
        let s = std::str::from_utf8(bytes).ok()?;
        let s = s.strip_prefix("0x").unwrap_or(s);
        if s.len() != 64 {
            return None;
        }
        let decoded = Vec::<u8>::from_hex(s).ok()?;
        if decoded.len() != 32 {
            return None;
        }
        let mut out = [0u8; 32];
        out.copy_from_slice(&decoded);
        Some(out)
    }

    async fn emit_for_current_daa(&self, notifier: &DynNotify<Notification>, current_daa: u64) {
        let anchors: Vec<[u8; 32]> = {
            let guard = self.mldsa_anchor_keys.lock().unwrap();
            guard.iter().copied().collect()
        };
        if anchors.is_empty() {
            return;
        }

        let provider = { self.delegation_provider.lock().unwrap().clone() };
        let Some(provider) = provider else {
            return;
        };

        for anchor in anchors {
            let list = match provider.list_by_anchor(anchor).await {
                Ok(v) => v,
                Err(_) => continue,
            };
            for rec in list {
                let Some(valid_until) = rec.valid_until_daa else { continue };
                if rec.status != "active" {
                    continue;
                }
                if current_daa >= valid_until {
                    continue;
                }
                if current_daa + self.warn_window_daa < valid_until {
                    continue;
                }
                let Some(account_id) = self.parse_account_id_hex(&rec.account_id) else {
                    continue;
                };
                if !self.should_emit(anchor, rec.delegation_id, current_daa) {
                    continue;
                }

                let notification =
                    Notification::MasterDelegationExpiringSoon(kaspa_rpc_core::MasterDelegationExpiringSoonNotification {
                        account_id,
                        delegation_id: rec.delegation_id,
                        anchor,
                        valid_until_daa: valid_until,
                        current_daa_score: current_daa,
                        warn_window_daa: self.warn_window_daa,
                    });
                if let Err(err) = notifier.notify(notification) {
                    trace!("[Collector {}] master delegation expiring soon notify error: {}", self.name, err);
                }
            }
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
            trace!("[Collector {}] master-aware consensus collecting task starting", self.name);

            while let Ok(notification) = recv_channel.recv().await {
                let converted = converter.convert(notification).await;
                if let Notification::VirtualDaaScoreChanged(ref payload) = converted {
                    let current_daa = payload.virtual_daa_score;
                    if self.check_in_progress.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_ok() {
                        let this = self.clone();
                        let notifier = notifier.clone();
                        tokio::spawn(async move {
                            this.emit_for_current_daa(&notifier, current_daa).await;
                            this.check_in_progress.store(false, Ordering::SeqCst);
                        });
                    }
                }
                if let Err(err) = notifier.notify(converted) {
                    trace!("[Collector {}] notification sender error: {}", self.name, err);
                }
            }

            debug!("[Collector {}] notification stream ended", self.name);
            collect_shutdown.trigger.trigger();
            trace!("[Collector {}] master-aware consensus collecting task ended", self.name);
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
impl Collector<Notification> for MasterAwareConsensusCollector {
    fn start(self: Arc<Self>, notifier: DynNotify<Notification>) {
        self.spawn_collecting_task(notifier);
    }

    async fn join(self: Arc<Self>) -> Result<()> {
        self.join_collecting_task().await
    }
}

/// A lightweight collector which listens to VirtualDaaScoreChanged consensus notifications
/// and emits `MasterDelegationExpiringSoon` notifications (wRPC-only) when a registered
/// MLDSA delegation is approaching expiry.
///
/// This collector is intentionally best-effort and only active when:
/// - at least one MLDSA anchor has been registered via `register_mldsa_anchor`
/// - a `DelegationProvider` has been installed (wallet hook)
pub struct MasterDelegationExpiringSoonCollector {
    name: &'static str,
    recv_channel: CollectorNotificationReceiver<ConsensusNotification>,
    converter: Arc<ConsensusConverter>,
    mldsa_anchor_keys: Arc<Mutex<std::collections::HashSet<[u8; 32]>>>,
    delegation_provider: Arc<Mutex<Option<Arc<dyn crate::service::DelegationProvider>>>>,
    warn_window_daa: u64,
    is_started: Arc<AtomicBool>,
    collect_shutdown: Arc<SingleTrigger>,
    last_emitted: Arc<Mutex<std::collections::HashMap<([u8; 32], u64), u64>>>,
}

impl std::fmt::Debug for MasterDelegationExpiringSoonCollector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("MasterDelegationExpiringSoonCollector")
            .field("name", &self.name)
            .field("warn_window_daa", &self.warn_window_daa)
            .finish()
    }
}

impl MasterDelegationExpiringSoonCollector {
    pub fn new(
        name: &'static str,
        recv_channel: CollectorNotificationReceiver<ConsensusNotification>,
        converter: Arc<ConsensusConverter>,
        mldsa_anchor_keys: Arc<Mutex<std::collections::HashSet<[u8; 32]>>>,
        delegation_provider: Arc<Mutex<Option<Arc<dyn crate::service::DelegationProvider>>>>,
        warn_window_daa: u64,
    ) -> Self {
        Self {
            name,
            recv_channel,
            converter,
            mldsa_anchor_keys,
            delegation_provider,
            warn_window_daa,
            collect_shutdown: Arc::new(SingleTrigger::new()),
            is_started: Arc::new(AtomicBool::new(false)),
            last_emitted: Arc::new(Mutex::new(std::collections::HashMap::new())),
        }
    }

    fn should_emit(&self, anchor: [u8; 32], delegation_id: u64, current_daa: u64) -> bool {
        let mut guard = self.last_emitted.lock().unwrap();
        let key = (anchor, delegation_id);
        match guard.get(&key).copied() {
            None => {
                guard.insert(key, current_daa);
                true
            }
            Some(prev) => {
                if current_daa.saturating_sub(prev) >= self.warn_window_daa {
                    guard.insert(key, current_daa);
                    true
                } else {
                    false
                }
            }
        }
    }

    fn parse_account_id_hex(&self, bytes: &[u8]) -> Option<[u8; 32]> {
        let s = std::str::from_utf8(bytes).ok()?;
        let s = s.strip_prefix("0x").unwrap_or(s);
        if s.len() != 64 {
            return None;
        }
        let decoded = Vec::<u8>::from_hex(s).ok()?;
        if decoded.len() != 32 {
            return None;
        }
        let mut out = [0u8; 32];
        out.copy_from_slice(&decoded);
        Some(out)
    }

    async fn emit_for_current_daa(&self, notifier: &DynNotify<Notification>, current_daa: u64) {
        let anchors: Vec<[u8; 32]> = {
            let guard = self.mldsa_anchor_keys.lock().unwrap();
            guard.iter().copied().collect()
        };
        if anchors.is_empty() {
            return;
        }

        let provider = { self.delegation_provider.lock().unwrap().clone() };
        let Some(provider) = provider else {
            return;
        };

        for anchor in anchors {
            let list = match provider.list_by_anchor(anchor).await {
                Ok(v) => v,
                Err(_) => continue,
            };
            for rec in list {
                let Some(valid_until) = rec.valid_until_daa else { continue };
                if rec.status != "active" {
                    continue;
                }
                if current_daa >= valid_until {
                    continue;
                }
                if current_daa + self.warn_window_daa < valid_until {
                    continue;
                }
                let Some(account_id) = self.parse_account_id_hex(&rec.account_id) else {
                    continue;
                };
                if !self.should_emit(anchor, rec.delegation_id, current_daa) {
                    continue;
                }

                let notification =
                    Notification::MasterDelegationExpiringSoon(kaspa_rpc_core::MasterDelegationExpiringSoonNotification {
                        account_id,
                        delegation_id: rec.delegation_id,
                        anchor,
                        valid_until_daa: valid_until,
                        current_daa_score: current_daa,
                        warn_window_daa: self.warn_window_daa,
                    });
                if let Err(err) = notifier.notify(notification) {
                    trace!("[Collector {}] master delegation expiring soon notify error: {}", self.name, err);
                }
            }
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
            trace!("[Collector {}] master-delegation-expiring-soon collecting task starting", self.name);

            while let Ok(notification) = recv_channel.recv().await {
                // Convert consensus notification -> rpc notification to extract the virtual daa score consistently.
                let converted = converter.convert(notification).await;
                if let Notification::VirtualDaaScoreChanged(ref payload) = converted {
                    self.emit_for_current_daa(&notifier, payload.virtual_daa_score).await;
                }
            }

            debug!("[Collector {}] notification stream ended", self.name);
            collect_shutdown.trigger.trigger();
            trace!("[Collector {}] master-delegation-expiring-soon collecting task ended", self.name);
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
impl Collector<Notification> for MasterDelegationExpiringSoonCollector {
    fn start(self: Arc<Self>, notifier: DynNotify<Notification>) {
        self.spawn_collecting_task(notifier);
    }

    async fn join(self: Arc<Self>) -> Result<()> {
        self.join_collecting_task().await
    }
}

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
