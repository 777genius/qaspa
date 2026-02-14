//!
//! Implements [`UtxoProcessor`], which is the main component
//! of the UTXO subsystem. It is responsible for managing and
//! coordinating multiple [`UtxoContext`] instances acting as
//! a hub for UTXO event dispersal and related processing.
//!

use crate::imports::*;
// use futures::pin_mut;
use kaspa_notify::{
    listener::ListenerId,
    scope::{Scope, StealthUtxosChangedScope, UtxosChangedScope, VirtualDaaScoreChangedScope},
};
use kaspa_rpc_core::{
    GetServerInfoResponse, RpcFeeEstimate,
    api::{
        ctl::{RpcCtl, RpcState},
        ops::{RPC_API_REVISION, RPC_API_VERSION},
    },
    message::{StealthUtxosChangedNotification, UtxosChangedNotification},
};
use kaspa_txscript::STEALTH_SCRIPT_VERSION;
use kaspa_wrpc_client::KaspaRpcClient;
use workflow_core::channel::{Channel, DuplexChannel, Sender};
use workflow_core::task::spawn;

use crate::deterministic::AccountId;
use crate::events::Events;
use crate::metrics::{MasterMetrics, MetricsUpdate, MetricsUpdateKind};
use crate::result::Result;
use crate::utxo::stealth_handler::DynStealthUtxoHandler;
use crate::utxo::{Maturity, OutgoingTransaction, PendingUtxoEntryReference, SyncMonitor, UtxoContext, UtxoEntryId};
use crate::wallet::WalletBusMessage;
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_rpc_core::{
    Notification,
    notify::connection::{ChannelConnection, ChannelType},
};

/// Stealth handler storage - separate struct to avoid lifetime issues with DashMap in async contexts
pub struct StealthHandlerStore {
    handlers: RwLock<HashMap<AccountId, DynStealthUtxoHandler>>,
    outpoint_index: RwLock<HashMap<TransactionOutpoint, AccountId>>,
}

impl StealthHandlerStore {
    pub fn new() -> Self {
        Self { handlers: RwLock::new(HashMap::new()), outpoint_index: RwLock::new(HashMap::new()) }
    }

    pub fn register(&self, account_id: AccountId, handler: DynStealthUtxoHandler) {
        self.handlers.write().unwrap().insert(account_id, handler);
    }

    pub fn unregister(&self, account_id: &AccountId) {
        self.handlers.write().unwrap().remove(account_id);
        self.outpoint_index.write().unwrap().retain(|_, id| id != account_id);
    }

    pub fn register_outpoint(&self, outpoint: TransactionOutpoint, account_id: AccountId) {
        self.outpoint_index.write().unwrap().insert(outpoint, account_id);
    }

    pub fn unregister_outpoint(&self, outpoint: &TransactionOutpoint) {
        self.outpoint_index.write().unwrap().remove(outpoint);
    }

    pub fn get_handler_for_outpoint(&self, outpoint: &TransactionOutpoint) -> Option<DynStealthUtxoHandler> {
        let index = self.outpoint_index.read().unwrap();
        let account_id = index.get(outpoint)?;
        let handlers = self.handlers.read().unwrap();
        handlers.get(account_id).cloned()
    }

    pub fn handlers(&self) -> Vec<DynStealthUtxoHandler> {
        self.handlers.read().unwrap().values().cloned().collect()
    }

    pub fn is_empty(&self) -> bool {
        self.handlers.read().unwrap().is_empty()
    }

    pub fn clear(&self) {
        self.handlers.write().unwrap().clear();
        self.outpoint_index.write().unwrap().clear();
    }
}

impl Default for StealthHandlerStore {
    fn default() -> Self {
        Self::new()
    }
}

pub struct Inner {
    /// Coinbase UTXOs in stasis
    stasis: DashMap<UtxoEntryId, PendingUtxoEntryReference>,
    /// UTXOs pending maturity
    pending: DashMap<UtxoEntryId, PendingUtxoEntryReference>,
    /// Outgoing Transactions
    outgoing: DashMap<TransactionId, OutgoingTransaction>,
    /// Address to UtxoContext map (maps all addresses used by
    /// all UtxoContexts to their respective UtxoContexts)
    address_to_utxo_context_map: DashMap<Arc<Address>, UtxoContext>,
    // ---
    current_daa_score: Arc<AtomicU64>,
    network_id: Arc<Mutex<Option<NetworkId>>>,
    rpc: Mutex<Option<Rpc>>,
    is_connected: AtomicBool,
    listener_id: Mutex<Option<ListenerId>>,
    task_ctl: DuplexChannel,
    task_is_running: AtomicBool,
    notification_channel: Channel<Notification>,
    sync_proc: SyncMonitor,
    multiplexer: Multiplexer<Box<Events>>,
    wallet_bus: Option<Channel<WalletBusMessage>>,
    notification_guard: AsyncRwLock<()>,
    connect_disconnect_guard: AsyncMutex<()>,
    metrics: Arc<Metrics>,
    metrics_kinds: Mutex<Vec<MetricsUpdateKind>>,
    connection_signaler: Mutex<Option<Sender<std::result::Result<(), String>>>>,
    fee_rate_task_ctl: DuplexChannel,
    fee_rate_task_is_running: AtomicBool,
    /// Stealth handler storage
    stealth_store: StealthHandlerStore,
}

impl Inner {
    pub fn new(
        rpc: Option<Rpc>,
        network_id: Option<NetworkId>,
        multiplexer: Multiplexer<Box<Events>>,
        wallet_bus: Option<Channel<WalletBusMessage>>,
    ) -> Self {
        Self {
            stasis: DashMap::new(),
            pending: DashMap::new(),
            outgoing: DashMap::new(),
            address_to_utxo_context_map: DashMap::new(),
            current_daa_score: Arc::new(AtomicU64::new(0)),
            network_id: Arc::new(Mutex::new(network_id)),
            rpc: Mutex::new(rpc.clone()),
            is_connected: AtomicBool::new(false),
            listener_id: Mutex::new(None),
            task_ctl: DuplexChannel::oneshot(),
            task_is_running: AtomicBool::new(false),
            notification_channel: Channel::<Notification>::unbounded(),
            sync_proc: SyncMonitor::new(rpc.clone(), &multiplexer),
            multiplexer,
            wallet_bus,
            notification_guard: Default::default(),
            connect_disconnect_guard: Default::default(),
            metrics: Arc::new(Metrics::default()),
            metrics_kinds: Mutex::new(vec![]),
            connection_signaler: Mutex::new(None),
            fee_rate_task_ctl: DuplexChannel::oneshot(),
            fee_rate_task_is_running: AtomicBool::new(false),
            stealth_store: StealthHandlerStore::new(),
        }
    }
}

#[derive(Clone)]
pub struct UtxoProcessor {
    inner: Arc<Inner>,
}

impl UtxoProcessor {
    pub fn new(
        rpc: Option<Rpc>,
        network_id: Option<NetworkId>,
        multiplexer: Option<Multiplexer<Box<Events>>>,
        wallet_bus: Option<Channel<WalletBusMessage>>,
    ) -> Self {
        let multiplexer = multiplexer.unwrap_or_default();
        UtxoProcessor { inner: Arc::new(Inner::new(rpc, network_id, multiplexer, wallet_bus)) }
    }

    pub fn rpc_api(&self) -> Arc<DynRpcApi> {
        self.inner.rpc.lock().unwrap().as_ref().expect("UtxoProcessor RPC not initialized").rpc_api().clone()
    }

    pub fn try_rpc_api(&self) -> Option<Arc<DynRpcApi>> {
        self.inner.rpc.lock().unwrap().as_ref().map(|rpc| rpc.rpc_api()).cloned()
    }

    pub fn rpc_ctl(&self) -> RpcCtl {
        self.inner.rpc.lock().unwrap().as_ref().expect("UtxoProcessor RPC not initialized").rpc_ctl().clone()
    }

    pub fn try_rpc_ctl(&self) -> Option<RpcCtl> {
        self.inner.rpc.lock().unwrap().as_ref().map(|rpc| rpc.rpc_ctl()).cloned()
    }

    pub fn rpc_url(&self) -> Option<String> {
        self.try_rpc_ctl().and_then(|ctl| ctl.descriptor())
    }

    pub fn rpc_client(&self) -> Option<Arc<KaspaRpcClient>> {
        self.try_rpc_api().and_then(|api| api.downcast_arc::<KaspaRpcClient>().ok())
    }

    pub async fn bind_rpc(&self, rpc: Option<Rpc>) -> Result<()> {
        self.inner.rpc.lock().unwrap().clone_from(&rpc);
        let rpc_api = rpc.as_ref().map(|rpc| rpc.rpc_api().clone());
        self.metrics().bind_rpc(rpc_api);
        self.sync_proc().bind_rpc(rpc).await?;
        Ok(())
    }

    pub fn metrics(&self) -> &Arc<Metrics> {
        &self.inner.metrics
    }

    pub fn wallet_bus(&self) -> &Option<Channel<WalletBusMessage>> {
        &self.inner.wallet_bus
    }

    pub fn has_rpc(&self) -> bool {
        self.inner.rpc.lock().unwrap().is_some()
    }

    pub fn multiplexer(&self) -> &Multiplexer<Box<Events>> {
        &self.inner.multiplexer
    }

    pub async fn notification_lock(&self) -> AsyncRwLockReadGuard<'_, ()> {
        self.inner.notification_guard.read().await
    }

    pub fn sync_proc(&self) -> &SyncMonitor {
        &self.inner.sync_proc
    }

    pub fn listener_id(&self) -> Result<ListenerId> {
        self.inner.listener_id.lock().unwrap().ok_or(Error::ListenerId)
    }

    pub fn set_network_id(&self, network_id: &NetworkId) {
        self.inner.network_id.lock().unwrap().replace(*network_id);
    }

    pub fn network_id(&self) -> Result<NetworkId> {
        (*self.inner.network_id.lock().unwrap()).ok_or(Error::MissingNetworkId)
    }

    pub fn network_params(&self) -> Result<&'static NetworkParams> {
        // pub fn network_params(&self) -> Result<NetworkParams> {
        let network_id = (*self.inner.network_id.lock().unwrap()).ok_or(Error::MissingNetworkId)?;
        Ok(NetworkParams::from(network_id))
        // Ok(network_id.into())
    }

    pub fn pending(&self) -> &DashMap<UtxoEntryId, PendingUtxoEntryReference> {
        &self.inner.pending
    }

    pub fn outgoing(&self) -> &DashMap<TransactionId, OutgoingTransaction> {
        &self.inner.outgoing
    }

    pub fn stasis(&self) -> &DashMap<UtxoEntryId, PendingUtxoEntryReference> {
        &self.inner.stasis
    }

    pub fn current_daa_score(&self) -> Option<u64> {
        self.is_connected().then_some(self.inner.current_daa_score.load(Ordering::SeqCst))
    }

    pub fn address_to_utxo_context_map(&self) -> &DashMap<Arc<Address>, UtxoContext> {
        &self.inner.address_to_utxo_context_map
    }

    pub fn address_to_utxo_context(&self, address: &Address) -> Option<UtxoContext> {
        self.inner.address_to_utxo_context_map.get(address).map(|v| v.clone())
    }

    pub async fn register_addresses(&self, addresses: Vec<Arc<Address>>, utxo_context: &UtxoContext) -> Result<()> {
        addresses.iter().for_each(|address| {
            self.inner.address_to_utxo_context_map.insert(address.clone(), utxo_context.clone());
        });

        if self.is_connected() {
            if !addresses.is_empty() {
                let addresses = addresses.into_iter().map(|address| (*address).clone()).collect::<Vec<_>>();
                let utxos_changed_scope = UtxosChangedScope::new(addresses);
                self.rpc_api().start_notify(self.listener_id()?, utxos_changed_scope.into()).await?;
            } else {
                log_error!("registering an empty address list!");
            }
        }
        Ok(())
    }

    pub async fn unregister_addresses(&self, addresses: Vec<Arc<Address>>) -> Result<()> {
        addresses.iter().for_each(|address| {
            self.inner.address_to_utxo_context_map.remove(address);
        });

        if self.is_connected() {
            if !addresses.is_empty() {
                let addresses = addresses.into_iter().map(|address| (*address).clone()).collect::<Vec<_>>();
                let utxos_changed_scope = UtxosChangedScope::new(addresses);
                self.rpc_api().stop_notify(self.listener_id()?, utxos_changed_scope.into()).await?;
            } else {
                log_error!("unregistering empty address list!");
            }
        }
        Ok(())
    }

    // ========================================================================
    // STEALTH HANDLER MANAGEMENT
    // ========================================================================

    /// Registers a stealth handler for receiving UTXO notifications.
    /// Stealth handlers are used to process stealth UTXOs which don't have
    /// a traditional address association.
    ///
    /// Automatically subscribes to stealth notifications when the first handler is registered.
    pub async fn register_stealth_handler(&self, handler: DynStealthUtxoHandler) -> Result<()> {
        let account_id = *handler.account_id();
        let was_empty = self.inner.stealth_store.is_empty();
        self.inner.stealth_store.register(account_id, handler);
        log_info!("Registered stealth handler for account {}", account_id.to_hex());

        // Subscribe to stealth notifications when first handler is registered
        if was_empty {
            self.register_stealth_notifications().await?;
        }
        Ok(())
    }

    /// Unregisters a stealth handler.
    ///
    /// Automatically unsubscribes from stealth notifications when the last handler is removed.
    pub async fn unregister_stealth_handler(&self, account_id: &AccountId) -> Result<()> {
        self.inner.stealth_store.unregister(account_id);
        log_info!("Unregistered stealth handler for account {}", account_id.to_hex());

        // Unsubscribe from stealth notifications when last handler is removed
        if self.inner.stealth_store.is_empty() {
            self.unregister_stealth_notifications().await?;
        }
        Ok(())
    }

    /// Registers an outpoint in the stealth reverse index
    pub fn register_stealth_outpoint(&self, outpoint: TransactionOutpoint, account_id: AccountId) {
        self.inner.stealth_store.register_outpoint(outpoint, account_id);
    }

    /// Unregisters an outpoint from the stealth reverse index
    pub fn unregister_stealth_outpoint(&self, outpoint: &TransactionOutpoint) {
        self.inner.stealth_store.unregister_outpoint(outpoint);
    }

    /// Gets the handler for an outpoint (if registered)
    fn get_handler_for_outpoint(&self, outpoint: &TransactionOutpoint) -> Option<DynStealthUtxoHandler> {
        self.inner.stealth_store.get_handler_for_outpoint(outpoint)
    }

    /// Returns true if there are any registered stealth handlers
    pub fn has_stealth_handlers(&self) -> bool {
        !self.inner.stealth_store.is_empty()
    }

    /// Returns all registered stealth handlers
    fn stealth_handlers(&self) -> Vec<DynStealthUtxoHandler> {
        self.inner.stealth_store.handlers()
    }

    /// Registers for stealth UTXO notifications with the RPC server.
    /// Should be called when the first stealth handler is registered.
    ///
    /// This method registers for both:
    /// 1. StealthUtxosChanged notifications (for wRPC which supports it natively)
    /// 2. Wildcard UtxosChanged notifications (for gRPC which doesn't support StealthUtxosChanged)
    ///
    /// The handle_utxo_changed method filters UtxosChanged for stealth UTXOs,
    /// so stealth UTXOs will be processed regardless of which notification type is used.
    pub async fn register_stealth_notifications(&self) -> Result<()> {
        if self.is_connected() {
            // Subscribe to StealthUtxosChanged (works with wRPC)
            let stealth_scope = StealthUtxosChangedScope::new(vec![STEALTH_SCRIPT_VERSION]);
            self.rpc_api().start_notify(self.listener_id()?, stealth_scope.into()).await?;
            log_info!("Registered for stealth UTXO notifications (script version {})", STEALTH_SCRIPT_VERSION);

            // Also subscribe to wildcard UtxosChanged (needed for gRPC fallback)
            // gRPC doesn't support StealthUtxosChanged, so it converts to UtxosChanged with empty addresses
            // But the notification type sent back is still UtxosChanged, so we need to listen for that too
            let utxos_scope = UtxosChangedScope::new(vec![]); // Empty = wildcard (all UTXOs)
            self.rpc_api().start_notify(self.listener_id()?, utxos_scope.into()).await?;
            log_info!("Also registered for wildcard UtxosChanged (gRPC fallback)");
        }
        Ok(())
    }

    /// Unregisters from stealth UTXO notifications.
    /// Should be called when the last stealth handler is unregistered.
    pub async fn unregister_stealth_notifications(&self) -> Result<()> {
        if self.is_connected() {
            // Unsubscribe from StealthUtxosChanged
            let stealth_scope = StealthUtxosChangedScope::new(vec![STEALTH_SCRIPT_VERSION]);
            self.rpc_api().stop_notify(self.listener_id()?, stealth_scope.into()).await?;
            log_info!("Unregistered from stealth UTXO notifications");

            // Unsubscribe from wildcard UtxosChanged
            let utxos_scope = UtxosChangedScope::new(vec![]);
            self.rpc_api().stop_notify(self.listener_id()?, utxos_scope.into()).await?;
            log_info!("Unregistered from wildcard UtxosChanged");
        }
        Ok(())
    }

    pub async fn notify(&self, event: Events) -> Result<()> {
        self.multiplexer()
            .try_broadcast(Box::new(event))
            .map_err(|_| Error::Custom("multiplexer channel error during notify".to_string()))?;
        Ok(())
    }

    pub fn try_notify(&self, event: Events) -> Result<()> {
        self.multiplexer()
            .try_broadcast(Box::new(event))
            .map_err(|_| Error::Custom("multiplexer channel error during try_notify".to_string()))?;
        Ok(())
    }

    pub async fn handle_daa_score_change(&self, current_daa_score: u64) -> Result<()> {
        self.inner.current_daa_score.store(current_daa_score, Ordering::SeqCst);
        self.notify(Events::DaaScoreChange { current_daa_score }).await?;
        self.handle_pending(current_daa_score).await?;
        self.handle_outgoing(current_daa_score).await?;

        // Stealth-specific DAA hooks
        for handler in self.inner.stealth_store.handlers() {
            handler.on_daa_score_changed(current_daa_score).await?;
        }
        Ok(())
    }

    #[allow(clippy::mutable_key_type)]
    pub async fn handle_pending(&self, current_daa_score: u64) -> Result<()> {
        let params = self.network_params()?;

        let (mature_entries, revived_entries) = {
            // scan and remove any pending entries that gained maturity
            let mut mature_entries = vec![];
            let pending_entries = &self.inner.pending;
            pending_entries.retain(|_id, pending_entry| {
                let maturity = pending_entry.maturity(params, current_daa_score);
                match maturity {
                    Maturity::Confirmed => {
                        mature_entries.push(pending_entry.clone());
                        false
                    }
                    _ => true,
                }
            });

            // scan and remove any stasis entries that can now become pending
            // or gained maturity
            let mut revived_entries = vec![];
            let stasis_entries = &self.inner.stasis;
            stasis_entries.retain(|_, stasis_entry| {
                match stasis_entry.maturity(params, current_daa_score) {
                    Maturity::Confirmed => {
                        mature_entries.push(stasis_entry.clone());
                        false
                    }
                    Maturity::Pending => {
                        revived_entries.push(stasis_entry.clone());
                        // relocate from stasis to pending ...
                        pending_entries.insert(stasis_entry.id(), stasis_entry.clone());
                        false
                    }
                    Maturity::Stasis => true,
                }
            });
            (mature_entries, revived_entries)
        };

        // ------

        let promotions =
            HashMap::group_from(mature_entries.into_iter().map(|utxo| (utxo.inner.utxo_context.clone(), utxo.inner.entry.clone())));
        let mut updated_contexts: HashSet<UtxoContext> = HashSet::from_iter(promotions.keys().cloned());

        for (context, utxos) in promotions.into_iter() {
            context.promote(utxos).await?;
        }

        // ------

        let revivals =
            HashMap::group_from(revived_entries.into_iter().map(|utxo| (utxo.inner.utxo_context.clone(), utxo.inner.entry.clone())));
        updated_contexts.extend(revivals.keys().cloned());

        for (context, utxos) in revivals.into_iter() {
            context.revive(utxos).await?;
        }

        for context in updated_contexts.into_iter() {
            context.update_balance().await?;
        }

        Ok(())
    }

    async fn handle_outgoing(&self, current_daa_score: u64) -> Result<()> {
        let longevity = self.network_params()?.user_transaction_maturity_period_daa();

        self.inner.outgoing.retain(|_, outgoing| {
            if outgoing.acceptance_daa_score() != 0 && (outgoing.acceptance_daa_score() + longevity) < current_daa_score {
                outgoing.originating_context().remove_outgoing_transaction(&outgoing.id());
                false
            } else {
                true
            }
        });

        Ok(())
    }

    pub fn register_outgoing_transaction(&self, outgoing_transaction: OutgoingTransaction) {
        self.inner.outgoing.insert(outgoing_transaction.id(), outgoing_transaction);
    }

    pub fn cancel_outgoing_transaction(&self, transaction_id: TransactionId) {
        self.inner.outgoing.remove(&transaction_id);
    }

    pub async fn handle_discovery(&self, record: TransactionRecord) -> Result<()> {
        if let Some(wallet_bus) = self.wallet_bus() {
            // if UtxoProcessor has an associated wallet_bus installed
            // by the wallet, cascade the discovery to the wallet so that
            // it can check if the record exists in its storage and handle
            // it in accordance to its policies.
            wallet_bus.sender.send(WalletBusMessage::Discovery { record }).await?;
        } else {
            // otherwise we fetch the unixtime and broadcast the discovery event
            let transaction_daa_score = record.block_daa_score();
            match self.rpc_api().get_daa_score_timestamp_estimate(vec![transaction_daa_score]).await {
                Ok(timestamps) => {
                    if let Some(timestamp) = timestamps.first() {
                        let mut record = record.clone();
                        record.set_unixtime(*timestamp);
                        self.notify(Events::Discovery { record }).await?;
                    } else {
                        self.notify(Events::Error {
                            message: format!(
                                "Unable to obtain DAA to unixtime for DAA {transaction_daa_score}, timestamp data is empty"
                            ),
                        })
                        .await?;
                    }
                }
                Err(err) => {
                    self.notify(Events::Error { message: format!("Unable to resolve DAA to unixtime: {err}") }).await?;
                }
            }
        }

        Ok(())
    }

    pub async fn handle_utxo_changed(&self, utxos: UtxosChangedNotification) -> Result<()> {
        use kaspa_txscript::STEALTH_SCRIPT_VERSION;

        let Some(current_daa_score) = self.current_daa_score() else {
            // Defensive: notifications can race with disconnect/shutdown and arrive after `is_connected` is cleared.
            // In that case we don't have a reliable DAA score to classify maturity, so we ignore the notification.
            log_warn!("Ignoring UTXO Changed notification while disconnected");
            return Ok(());
        };

        #[allow(clippy::mutable_key_type)]
        let mut updated_contexts: HashSet<UtxoContext> = HashSet::default();

        // ========================================================================
        // SPLIT: Entries with address vs without address (stealth)
        // ========================================================================

        let (added_with_address, added_without_address): (Vec<_>, Vec<_>) =
            (*utxos.added).clone().into_iter().partition(|entry| entry.address.is_some());

        let (removed_with_address, removed_without_address): (Vec<_>, Vec<_>) =
            (*utxos.removed).clone().into_iter().partition(|entry| entry.address.is_some());

        // ========================================================================
        // STEALTH UTXO PROCESSING (without address)
        // ========================================================================

        // Process added stealth UTXOs
        for entry in added_without_address {
            if entry.utxo_entry.script_public_key.version() != STEALTH_SCRIPT_VERSION {
                continue;
            }

            let outpoint = TransactionOutpoint::new(entry.outpoint.transaction_id, entry.outpoint.index);

            // First try: lookup in outpoint index (O(1))
            if let Some(handler) = self.get_handler_for_outpoint(&outpoint) {
                // Already known outpoint - just update context
                let context = handler.utxo_context();
                updated_contexts.insert(context.clone());

                let utxo_ref: UtxoEntryReference = (&entry).into();
                context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
                continue;
            }

            // Second try: iterate handlers and try to claim (rare case - first discovery)
            let handlers = self.stealth_handlers();
            for handler in handlers {
                if let Some(context) = handler.try_claim_utxo(&entry).await {
                    updated_contexts.insert(context.clone());

                    // Register in outpoint index for future lookups
                    self.register_stealth_outpoint(outpoint, *handler.account_id());

                    let utxo_ref: UtxoEntryReference = (&entry).into();
                    context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;

                    break;
                }
            }
        }

        // Process removed stealth UTXOs
        for entry in removed_without_address {
            if entry.utxo_entry.script_public_key.version() != STEALTH_SCRIPT_VERSION {
                continue;
            }

            let outpoint = TransactionOutpoint::new(entry.outpoint.transaction_id, entry.outpoint.index);

            // Lookup handler by outpoint
            if let Some(handler) = self.get_handler_for_outpoint(&outpoint) {
                let context = handler.utxo_context();
                updated_contexts.insert(context.clone());

                // Remove ephemeral key
                handler.handle_utxo_removed(&outpoint).await?;

                // Remove from outpoint index
                self.unregister_stealth_outpoint(&outpoint);

                // Remove from UTXO context
                let utxo_ref: UtxoEntryReference = (&entry).into();
                context.handle_utxo_removed(vec![utxo_ref], current_daa_score).await?;
            }
        }

        // ========================================================================
        // STANDARD UTXO PROCESSING (with address)
        // ========================================================================

        let added = added_with_address.into_iter().filter_map(|entry| entry.address.clone().map(|address| (address, entry)));
        let mut added = HashMap::group_from(added);

        let removed = removed_with_address.into_iter().filter_map(|entry| entry.address.clone().map(|address| (address, entry)));
        let mut removed = HashMap::group_from(removed);

        // Create separate lists for entries that appear in both added and removed
        let mut common_added = HashMap::new();
        //let mut common_removed = HashMap::new();

        // Find common entries and separate them
        for (address, removed_entries) in removed.clone().into_iter() {
            if let Some(added_entries) = added.get(&address) {
                //let mut common_entries_removed = Vec::new();
                let mut common_entries_added = Vec::new();

                for removed_entry in removed_entries.iter() {
                    if let Some(added_entry) = added_entries.iter().find(|added_entry| added_entry.outpoint == removed_entry.outpoint)
                    {
                        //common_entries_removed.push(removed_entry.clone());
                        common_entries_added.push(added_entry.clone());
                    }
                }

                if !common_entries_added.is_empty() {
                    //common_removed.insert(address.clone(), common_entries_removed.clone());
                    common_added.insert(address.clone(), common_entries_added.clone());

                    // Remove common entries from original lists
                    if let Some(entries) = removed.get_mut(&address) {
                        entries.retain(|entry| !common_entries_added.iter().any(|common| common.outpoint == entry.outpoint));
                    }
                    if let Some(entries) = added.get_mut(&address) {
                        entries.retain(|entry| !common_entries_added.iter().any(|common| common.outpoint == entry.outpoint));
                    }
                }
            }
        }

        // Clean up empty entries
        removed.retain(|_, entries| !entries.is_empty());
        added.retain(|_, entries| !entries.is_empty());

        // Process remaining removed entries
        for (address, entries) in removed.into_iter() {
            if let Some(utxo_context) = self.address_to_utxo_context(&address) {
                updated_contexts.insert(utxo_context.clone());
                let entries = entries.iter().map(|entry| entry.into()).collect::<Vec<_>>();
                if entries.is_not_empty() {
                    utxo_context.handle_utxo_removed(entries, current_daa_score).await?;
                }
            } else {
                log_error!("receiving UTXO Changed 'removed' notification for an unknown address: {}", address);
            }
        }

        // Process remaining added entries
        for (address, entries) in added.into_iter() {
            if let Some(utxo_context) = self.address_to_utxo_context(&address) {
                updated_contexts.insert(utxo_context.clone());
                let entries = entries.iter().map(|entry| entry.into()).collect::<Vec<_>>();
                if entries.is_not_empty() {
                    utxo_context.handle_utxo_added(entries, current_daa_score).await?;
                }
            } else {
                log_error!("receiving UTXO Changed 'added' notification for an unknown address: {}", address);
            }
        }

        for (address, entries_added) in common_added.into_iter() {
            if let Some(utxo_context) = self.address_to_utxo_context(&address) {
                updated_contexts.insert(utxo_context.clone());
                //let entries_removed = common_removed.get(&address).unwrap();

                let added_utxos = entries_added.iter().map(|entry| entry.into()).collect::<Vec<_>>();
                //let removed_utxos = entries_removed.iter().map(|entry| entry.into()).collect::<Vec<_>>();

                utxo_context.update_utxos(added_utxos, current_daa_score).await?;
            } else {
                log_error!("receiving UTXO Changed 'added' notification for an unknown address: {}", address);
            }
        }

        // Update balances for affected contexts
        for context in updated_contexts.iter() {
            context.update_balance().await?;
        }

        Ok(())
    }

    /// Handles StealthUtxosChanged notifications specifically for stealth UTXOs.
    /// This is called when we receive notifications filtered by script version.
    pub async fn handle_stealth_utxo_changed(&self, notification: StealthUtxosChangedNotification) -> Result<()> {
        let Some(current_daa_score) = self.current_daa_score() else {
            log_warn!("Ignoring StealthUtxosChanged notification while disconnected");
            return Ok(());
        };

        #[allow(clippy::mutable_key_type)]
        let mut updated_contexts: HashSet<UtxoContext> = HashSet::default();

        // Process added stealth UTXOs
        for entry in notification.added.iter() {
            let outpoint = TransactionOutpoint::new(entry.outpoint.transaction_id, entry.outpoint.index);

            // First try: lookup in outpoint index (O(1))
            if let Some(handler) = self.get_handler_for_outpoint(&outpoint) {
                let context = handler.utxo_context();
                updated_contexts.insert(context.clone());

                let utxo_ref: UtxoEntryReference = entry.into();
                context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
                continue;
            }

            // Second try: iterate handlers and try to claim (first discovery)
            for handler in self.stealth_handlers() {
                if let Some(context) = handler.try_claim_utxo(entry).await {
                    updated_contexts.insert(context.clone());

                    // Register in outpoint index for future lookups
                    self.register_stealth_outpoint(outpoint, *handler.account_id());

                    let utxo_ref: UtxoEntryReference = entry.into();
                    context.handle_utxo_added(vec![utxo_ref], current_daa_score).await?;
                    break;
                }
            }
        }

        // Process removed stealth UTXOs
        for entry in notification.removed.iter() {
            let outpoint = TransactionOutpoint::new(entry.outpoint.transaction_id, entry.outpoint.index);

            if let Some(handler) = self.get_handler_for_outpoint(&outpoint) {
                let context = handler.utxo_context();
                updated_contexts.insert(context.clone());

                // Remove ephemeral key
                handler.handle_utxo_removed(&outpoint).await?;

                // Remove from outpoint index
                self.unregister_stealth_outpoint(&outpoint);

                // Remove from UTXO context
                let utxo_ref: UtxoEntryReference = entry.into();
                context.handle_utxo_removed(vec![utxo_ref], current_daa_score).await?;
            }
        }

        // Update balances for affected contexts
        for context in updated_contexts.iter() {
            context.update_balance().await?;
        }

        Ok(())
    }

    pub fn is_connected(&self) -> bool {
        self.inner.is_connected.load(Ordering::SeqCst)
    }

    pub fn is_synced(&self) -> bool {
        self.sync_proc().is_synced()
    }

    pub fn is_running(&self) -> bool {
        self.inner.task_is_running.load(Ordering::SeqCst)
    }

    pub async fn init_state_from_server(&self) -> Result<bool> {
        let GetServerInfoResponse {
            rpc_api_version,
            rpc_api_revision,
            server_version,
            network_id: server_network_id,
            has_utxo_index,
            is_synced,
            virtual_daa_score,
            has_stealth_support: _,
            ..
        } = self.rpc_api().get_server_info().await?;

        if rpc_api_version > RPC_API_VERSION {
            let current = format!("{RPC_API_VERSION}.{RPC_API_REVISION}");
            let connected = format!("{rpc_api_version}.{rpc_api_revision}");
            return Err(Error::RpcApiVersion(current, connected));
        }

        if !has_utxo_index {
            self.notify(Events::UtxoIndexNotEnabled { url: self.rpc_url() }).await?;
            return Err(Error::MissingUtxoIndex);
        }

        let network_id = self.network_id()?;
        if network_id != server_network_id {
            return Err(Error::InvalidNetworkType(network_id.to_string(), server_network_id.to_string()));
        }

        self.inner.current_daa_score.store(virtual_daa_score, Ordering::SeqCst);

        log_trace!("Connected to kaspad: '{server_version}' on '{server_network_id}';  SYNC: {is_synced}  DAA: {virtual_daa_score}");
        self.notify(Events::ServerStatus { server_version, is_synced, network_id, url: self.rpc_url() }).await?;

        Ok(is_synced)
    }

    pub async fn handle_connect_impl(&self) -> Result<()> {
        let is_synced = self.init_state_from_server().await?;
        self.inner.is_connected.store(true, Ordering::SeqCst);
        self.register_notification_listener().await?;
        self.notify(Events::UtxoProcStart).await?;
        self.sync_proc().track(is_synced).await?;

        let this = self.clone();
        self.inner.metrics.register_sink(Arc::new(Box::new(move |snapshot: MetricsSnapshot| {
            if let Err(err) = this.deliver_metrics_snapshot(Box::new(snapshot)) {
                println!("Error ingesting metrics snapshot: {}", err);
            }
            None
        })));

        Ok(())
    }

    /// Allows use to supply a channel Sender that will
    /// receive the result of the wRPC connection attempt.
    pub fn set_connection_signaler(&self, signal: Sender<std::result::Result<(), String>>) {
        *self.inner.connection_signaler.lock().unwrap() = Some(signal);
    }

    fn signal_connection(&self, result: std::result::Result<(), String>) -> bool {
        let signal = self.inner.connection_signaler.lock().unwrap().take();
        if let Some(signal) = signal.as_ref() {
            let _ = signal.try_send(result);
            true
        } else {
            false
        }
    }

    pub async fn handle_connect(&self) -> Result<()> {
        let _ = self.inner.connect_disconnect_guard.lock().await;

        match self.handle_connect_impl().await {
            Err(err) => {
                if !self.signal_connection(Err(err.to_string())) {
                    log_error!("UtxoProcessor: error while connecting to node: {err}");
                }
                self.notify(Events::UtxoProcError { message: err.to_string() }).await?;
                if let Some(client) = self.rpc_client() {
                    // try force disconnect the client if we have failed
                    // to negotiate the connection to the node.
                    client.disconnect().await?;
                }
                Err(err)
            }
            Ok(_) => {
                self.signal_connection(Ok(()));
                Ok(())
            }
        }
    }

    pub async fn handle_disconnect(&self) -> Result<()> {
        let _ = self.inner.connect_disconnect_guard.lock().await;

        self.inner.is_connected.store(false, Ordering::SeqCst);
        // self.stop_metrics();

        self.inner.metrics.unregister_sink();

        self.unregister_notification_listener().await?;
        self.notify(Events::UtxoProcStop).await?;
        self.cleanup().await?;

        Ok(())
    }

    pub async fn cleanup(&self) -> Result<()> {
        self.inner.pending.clear();
        self.inner.stasis.clear();
        self.inner.outgoing.clear();
        self.inner.address_to_utxo_context_map.clear();
        // Clear stealth structures
        self.inner.stealth_store.clear();
        Ok(())
    }

    async fn register_notification_listener(&self) -> Result<()> {
        let listener_id = self.rpc_api().register_new_listener(ChannelConnection::new(
            "utxo processor",
            self.inner.notification_channel.sender.clone(),
            ChannelType::Persistent,
        ));
        *self.inner.listener_id.lock().unwrap() = Some(listener_id);
        self.rpc_api().start_notify(listener_id, Scope::VirtualDaaScoreChanged(VirtualDaaScoreChangedScope {})).await?;
        Ok(())
    }

    async fn unregister_notification_listener(&self) -> Result<()> {
        let listener_id = self.inner.listener_id.lock().unwrap().take();
        if let Some(id) = listener_id {
            // we do not need this as we are unregister the entire listener here...
            self.rpc_api().unregister_listener(id).await?;
        }
        Ok(())
    }

    async fn handle_notification(&self, notification: Notification) -> Result<()> {
        let _lock = self.inner.notification_guard.write().await;

        match notification {
            Notification::VirtualDaaScoreChanged(virtual_daa_score_changed_notification) => {
                self.handle_daa_score_change(virtual_daa_score_changed_notification.virtual_daa_score).await?;
            }

            Notification::UtxosChanged(utxos_changed_notification) => {
                if !self.is_synced() {
                    self.sync_proc().track(true).await?;
                }

                self.handle_utxo_changed(utxos_changed_notification).await?;
            }

            Notification::StealthUtxosChanged(stealth_notification) => {
                if !self.is_synced() {
                    self.sync_proc().track(true).await?;
                }

                self.handle_stealth_utxo_changed(stealth_notification).await?;
            }

            _ => {
                log_warn!("unknown notification: {:?}", notification);
            }
        }

        Ok(())
    }

    fn deliver_metrics_snapshot(&self, snapshot: Box<MetricsSnapshot>) -> Result<()> {
        let metrics_kinds = self.inner.metrics_kinds.lock().unwrap().clone();
        for kind in metrics_kinds.into_iter() {
            match kind {
                MetricsUpdateKind::WalletMetrics => {
                    let mempool_size = snapshot.get(&Metric::NetworkMempoolSize) as u64;
                    let metrics = MetricsUpdate::WalletMetrics { mempool_size };
                    self.try_notify(Events::Metrics { network_id: self.network_id()?, metrics })?;
                }
                MetricsUpdateKind::MasterMetrics => {
                    let master = MasterMetrics::global().snapshot();
                    let metrics = MetricsUpdate::MasterMetrics { metrics: master };
                    self.try_notify(Events::Metrics { network_id: self.network_id()?, metrics })?;
                }
            }
        }

        Ok(())
    }

    pub async fn start_metrics(&self) -> Result<()> {
        self.inner.metrics.start_task().await?;
        self.inner.metrics.bind_rpc(self.try_rpc_api());

        Ok(())
    }

    pub async fn stop_metrics(&self) -> Result<()> {
        self.inner.metrics.stop_task().await?;
        self.inner.metrics.bind_rpc(None);

        Ok(())
    }

    pub async fn start(&self) -> Result<()> {
        let this = self.clone();
        if this.inner.task_is_running.load(Ordering::SeqCst) {
            return Err(Error::custom("UtxoProcessor::start() called while task is already running"));
        }
        let Some(rpc_ctl) = this.try_rpc_ctl() else {
            return Err(Error::custom("UtxoProcessor RPC not initialized"));
        };
        this.inner.task_is_running.store(true, Ordering::SeqCst);
        let rpc_ctl_channel = rpc_ctl.multiplexer().channel();
        let task_ctl_receiver = self.inner.task_ctl.request.receiver.clone();
        let task_ctl_sender = self.inner.task_ctl.response.sender.clone();
        let notification_receiver = self.inner.notification_channel.receiver.clone();

        // handle power up on an already connected rpc channel
        // clients relying on UtxoProcessor state should monitor
        // for and handle `UtxoProcStart` and `UtxoProcStop` events.
        if rpc_ctl.is_connected() {
            this.handle_connect().await.unwrap_or_else(|err| log_error!("{err}"));
        }

        spawn(async move {
            loop {
                select_biased! {
                    msg = rpc_ctl_channel.receiver.recv().fuse() => {
                        match msg {
                            Ok(msg) => {

                                // handle RPC channel connection and disconnection events
                                match msg {
                                    RpcState::Connected => {
                                        if !this.is_connected() && this.handle_connect().await.is_ok() {
                                            if let Ok(network_id) = this.network_id() {
                                                this.inner
                                                    .multiplexer
                                                    .try_broadcast(Box::new(Events::Connect { network_id, url: this.rpc_url() }))
                                                    .unwrap_or_else(|err| log_error!("{err}"));
                                            } else {
                                                log_warn!("UtxoProcessor missing network id during connection; Connect event skipped");
                                            }
                                        }
                                    },
                                    RpcState::Disconnected => {
                                        if this.is_connected() {
                                            if let Ok(network_id) = this.network_id() {
                                                this.inner
                                                    .multiplexer
                                                    .try_broadcast(Box::new(Events::Disconnect { network_id, url: this.rpc_url() }))
                                                    .unwrap_or_else(|err| log_error!("{err}"));
                                            } else {
                                                log_warn!("UtxoProcessor missing network id during disconnect; Disconnect event skipped");
                                            }
                                            this.handle_disconnect().await.unwrap_or_else(|err| log_error!("{err}"));
                                        }
                                    }
                                }
                            }
                            Err(err) => {
                                log_error!("UtxoProcessor: error while receiving rpc_ctl_channel message: {err}");
                                log_error!("Suspending UTXO processor...");
                                break;
                            }
                        }
                    }
                    notification = notification_receiver.recv().fuse() => {
                        match notification {
                            Ok(notification) => {
                                if let Err(err) = this.handle_notification(notification).await {
                                    this.notify(Events::UtxoProcError { message: err.to_string() }).await.ok();
                                    log_error!("error while handling notification: {err}");
                                }
                            }
                            Err(err) => {
                                log_error!("RPC notification channel error: {err}");
                                log_error!("Suspending UTXO processor...");
                                break;
                            }
                        }
                    },

                    // we use select_biased to drain rpc_ctl
                    // and notifications before shutting down
                    // as such task_ctl is last in the poll order
                    _ = task_ctl_receiver.recv().fuse() => {
                        break;
                    },

                }
            }

            // handle power down on rpc channel that remains connected
            if this.is_connected() {
                this.handle_disconnect().await.unwrap_or_else(|err| log_error!("{err}"));
            }

            this.inner.task_is_running.store(false, Ordering::SeqCst);
            task_ctl_sender.send(()).await.ok();
        });
        Ok(())
    }

    pub async fn stop(&self) -> Result<()> {
        if self.inner.task_is_running.load(Ordering::SeqCst) {
            self.inner.sync_proc.stop().await?;
            if let Err(err) = self.inner.task_ctl.signal(()).await {
                log_warn!("UtxoProcessor::stop_task() `signal` error: {err}");
            }
        }
        Ok(())
    }

    pub fn enable_metrics_kinds(&self, metrics_kinds: &[MetricsUpdateKind]) {
        *self.inner.metrics_kinds.lock().unwrap() = metrics_kinds.to_vec();
    }

    pub fn add_metrics_kinds(&self, metrics_kinds: &[MetricsUpdateKind]) {
        let mut guard = self.inner.metrics_kinds.lock().unwrap();
        for kind in metrics_kinds {
            if !guard.contains(kind) {
                guard.push(kind.clone());
            }
        }
    }

    pub async fn start_fee_rate_poller(&self, poller_interval: Duration) -> Result<()> {
        self.stop_fee_rate_poller().await.ok();

        let this = self.clone();
        this.inner.fee_rate_task_is_running.store(true, Ordering::SeqCst);
        let fee_rate_task_ctl_receiver = self.inner.fee_rate_task_ctl.request.receiver.clone();
        let fee_rate_task_ctl_sender = self.inner.fee_rate_task_ctl.response.sender.clone();

        let mut interval = workflow_core::task::interval(poller_interval);

        spawn(async move {
            loop {
                select_biased! {
                    _ = interval.next().fuse() => {
                        let Some(rpc_api) = this.try_rpc_api() else {
                            log_warn!("Fee rate poller tick while RPC is not initialized");
                            continue;
                        };
                        if let Ok(fee_rate) = rpc_api.get_fee_estimate().await {
                            let RpcFeeEstimate { priority_bucket, normal_buckets, low_buckets } = fee_rate;
                            let Some(normal_bucket) = normal_buckets.first().copied() else {
                                log_warn!("Fee rate poller received empty normal_buckets");
                                continue;
                            };
                            let Some(low_bucket) = low_buckets.first().copied() else {
                                log_warn!("Fee rate poller received empty low_buckets");
                                continue;
                            };
                            this.notify(Events::FeeRate {
                                priority : priority_bucket.into(),
                                normal : normal_bucket.into(),
                                low : low_bucket.into()
                            }).await.ok();
                        }
                    },
                    _ = fee_rate_task_ctl_receiver.recv().fuse() => {
                        break;
                    },
                }
            }

            this.inner.fee_rate_task_is_running.store(false, Ordering::SeqCst);
            fee_rate_task_ctl_sender.send(()).await.ok();
        });

        Ok(())
    }

    pub async fn stop_fee_rate_poller(&self) -> Result<()> {
        if self.inner.fee_rate_task_is_running.load(Ordering::SeqCst)
            && let Err(err) = self.inner.fee_rate_task_ctl.signal(()).await
        {
            log_warn!("UtxoProcessor::stop_fee_rate_poller() `signal` error: {err}");
        }
        Ok(())
    }
}

#[cfg(test)]
pub(crate) mod mock {
    use super::*;

    impl UtxoProcessor {
        pub fn mock_set_connected(&self, connected: bool) {
            self.inner.is_connected.store(connected, Ordering::SeqCst);
        }

        // pub fn mock_set_daa_score(&self, connected : bool) {
        //     self.inner.is_connected.store(connected, Ordering::SeqCst);
        // }
    }
}
