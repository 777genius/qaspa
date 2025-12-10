import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_rust_bridge/wallet_rust_bridge.dart';

import '../datasources/local_datasource.dart';
import '../datasources/rust_datasource.dart';

final _log = Logger('TransactionRepository');

/// Implementation of [TransactionRepository] using Rust bridge and local DB.
///
/// This implementation:
/// - Fetches transactions from Rust and stores in local DB
/// - Watches for new transactions and persists them
/// - Provides reactive streams from local DB for UI
@modularityExportEnv
@LazySingleton(as: TransactionRepository)
class TransactionRepositoryImpl implements TransactionRepository {
  final RustDatasource _rust;
  final LocalDatasource _local;

  final _accountSubscriptions = <String, StreamSubscription<Transaction>>{};
  StreamSubscription<dynamic>? _eventsSubscription;

  /// In-progress sync futures. Key: accountId, Value: Future that completes when sync setup is done.
  /// Entries are only removed when subscription is created or setup fails.
  final _syncInProgress = <String, Future<void>>{};

  TransactionRepositoryImpl(this._rust, this._local);

  @override
  void startSync(String accountId) {
    // Use atomic version internally
    _startSyncAtomic(accountId);
  }

  /// Atomic sync start that prevents race conditions.
  /// Returns a Future that completes when sync setup is done.
  Future<void> _startSyncAtomic(String accountId) {
    // Fast path: if already has subscription, no sync needed
    if (_accountSubscriptions.containsKey(accountId)) {
      return Future.value();
    }

    // Check for in-progress sync and return existing future if found
    final existingFuture = _syncInProgress[accountId];
    if (existingFuture != null) {
      return existingFuture;
    }

    // Create the sync future and store it immediately (before any async gap)
    final syncFuture = _doStartSync(accountId);
    _syncInProgress[accountId] = syncFuture;

    // Chain cleanup to happen after sync completes (success or failure)
    syncFuture.whenComplete(() {
      _syncInProgress.remove(accountId);
    });

    return syncFuture;
  }

  /// Internal method that actually sets up the sync.
  Future<void> _doStartSync(String accountId) async {
    // Double-check: subscription might have been created while we were waiting
    if (_accountSubscriptions.containsKey(accountId)) {
      return;
    }

    // Explicit capture of accountId to prevent closure capture issues
    final capturedAccountId = accountId;

    // Listen to new transactions from Rust and store locally
    _accountSubscriptions[accountId] =
        _rust.watchTransactions(accountId: capturedAccountId).listen(
      (tx) async {
        await _local.saveTransactionForAccount(capturedAccountId, tx);
      },
      onError: (Object error, StackTrace stack) {
        // Log sync error and clean up subscription
        _log.warning(
          'Transaction sync error for $capturedAccountId',
          error,
          stack,
        );
        // Remove dead subscription to allow re-sync
        _accountSubscriptions.remove(capturedAccountId);
      },
      onDone: () {
        // Stream completed, clean up subscription
        _log.info('Transaction sync stream completed for $capturedAccountId');
        _accountSubscriptions.remove(capturedAccountId);
      },
    );

    // Start global events subscription (only once)
    _eventsSubscription ??= _rust.events.listen(
      (event) async {
        if (event is DaaScoreEvent) {
          // Could update pending transactions here
        }
      },
      onError: (Object error, StackTrace stack) {
        // Log error and clean up - allows re-subscribe on next sync
        _log.warning('Events subscription error', error, stack);
        _eventsSubscription = null;
      },
      onDone: () {
        // Stream completed, allow re-subscribe on next sync
        _log.info('Events stream completed');
        _eventsSubscription = null;
      },
    );
  }

  @override
  void stopSync(String accountId) {
    // Remove in-progress sync to prevent re-setup
    _syncInProgress.remove(accountId);
    // Cancel and remove subscription
    _accountSubscriptions[accountId]?.cancel();
    _accountSubscriptions.remove(accountId);
  }

  @override
  Future<Transaction?> getTransaction({required TransactionId id}) =>
      _local.getTransaction(id: id);

  @override
  Future<List<Transaction>> listTransactions({
    required String accountId,
    int? limit,
    int? offset,
    TransactionKind? kindFilter,
  }) async {
    // First, try to fetch from Rust to ensure we have latest
    try {
      final rustTxs = await _rust.getTransactions(
        accountId: accountId,
        limit: limit,
        offset: offset,
      );

      // Store in local DB
      for (final tx in rustTxs) {
        await _local.saveTransactionForAccount(accountId, tx);
      }
    } catch (e, stack) {
      // Log sync error but don't crash - return cached data
      // TODO: Consider returning SyncResult type with isStale flag
      _log.warning(
        'Transaction list sync error for $accountId, returning cached data',
        e,
        stack,
      );
    }

    // Return from local DB (may be stale if sync failed)
    return _local.getTransactions(
      accountId: accountId,
      limit: limit,
      offset: offset,
      kindFilter: kindFilter,
    );
  }

  @override
  Stream<List<Transaction>> watchTransactions({required String accountId}) {
    // Use atomic sync start to prevent race conditions
    // This ensures only one subscription per account even with concurrent calls
    _startSyncAtomic(accountId);

    // Return stream from local DB
    return _local.watchTransactions(accountId: accountId);
  }

  @override
  Stream<Transaction> watchNewTransactions({required String accountId}) =>
      _rust.watchTransactions(accountId: accountId);

  @override
  Future<TransactionEstimate> estimateTransaction({
    required SendRequest request,
  }) =>
      _rust.estimateTransaction(
        accountId: request.accountId,
        destination: request.destination,
        amount: request.amount,
        priorityFee: request.priorityFee,
      );

  @override
  Future<TransactionId> sendTransaction({
    required SendRequest request,
    required String password,
  }) async {
    final txId = await _rust.sendTransaction(
      accountId: request.accountId,
      destination: request.destination,
      amount: request.amount,
      password: password,
      priorityFee: request.priorityFee,
      note: request.note,
    );

    return txId;
  }

  @override
  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  }) =>
      _rust.sendMax(
        accountId: accountId,
        destination: destination,
        password: password,
        note: note,
      );

  @override
  Future<bool> cancelTransaction({required TransactionId id}) async {
    // Kaspa transactions cannot be cancelled once submitted
    return false;
  }

  @override
  Future<void> addTransactionNote({
    required TransactionId id,
    required String note,
  }) =>
      _local.updateTransactionNote(id: id, note: note);

  @override
  Future<int> getTransactionCount({required String accountId}) =>
      _local.getTransactionCount(accountId: accountId);

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;

    for (final sub in _accountSubscriptions.values) {
      sub.cancel();
    }
    _accountSubscriptions.clear();
  }
}
