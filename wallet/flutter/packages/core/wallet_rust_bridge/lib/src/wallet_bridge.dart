import 'dart:async';

import 'package:meta/meta.dart';
import 'package:wallet_domain/wallet_domain.dart';

import 'wallet_config.dart';
import 'events/wallet_events.dart';

/// Abstract interface for wallet bridge operations.
///
/// Platform-specific implementations:
/// - [WalletBridgeNative] - FFI for Mobile/Desktop
/// - [WalletBridgeWeb] - WASM for Web/Extension
///
/// Usage:
/// ```dart
/// await WalletBridge.initialize(WalletConfig.mainnet());
/// final bridge = WalletBridge.instance;
/// final mnemonic = await bridge.generateMnemonic();
/// ```
abstract class WalletBridge {
  static WalletBridge? _instance;

  /// Single completer that acts as both initialization tracker and lock.
  /// - null: not initializing
  /// - not completed: initialization in progress
  /// - completed: initialization done (success or error in _initError)
  static Completer<WalletBridge>? _initCompleter;

  /// Stores initialization error if any.
  /// Used for debugging and error reporting.
  // ignore: unused_field
  static Object? _initError;

  /// Number of failed initialization attempts.
  static int _retryCount = 0;

  /// Maximum number of retry attempts before giving up.
  static const int _maxRetries = 3;

  /// Base delay for exponential backoff (doubles each retry).
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);

  /// Get the initialized bridge instance.
  /// Throws [BridgeNotInitializedException] if [initialize] was not called.
  static WalletBridge get instance {
    if (_instance == null) {
      throw BridgeNotInitializedException();
    }
    return _instance!;
  }

  /// Check if bridge is initialized.
  static bool get isInitialized => _instance != null;

  /// Check if initialization is in progress.
  static bool get isInitializing =>
      _initCompleter != null && !_initCompleter!.isCompleted;

  /// Initialize the wallet bridge.
  /// Thread-safe - multiple concurrent calls will share the same initialization.
  /// If initialization fails, retries up to [_maxRetries] times with exponential backoff.
  /// Throws [BridgeInitializationException] if all retries fail.
  static Future<void> initialize(WalletConfig config) async {
    // Fast path: already initialized
    if (_instance != null) return;

    // Check if initialization is already in progress
    final existingCompleter = _initCompleter;
    if (existingCompleter != null) {
      if (!existingCompleter.isCompleted) {
        // Wait for ongoing initialization
        try {
          await existingCompleter.future;
        } catch (_) {
          // If previous initialization failed, retry below
        }
        // Check if we now have an instance
        if (_instance != null) return;
      } else if (_instance != null) {
        // Completed successfully before
        return;
      }
      // Previous attempt failed, check retry limit
      if (_retryCount >= _maxRetries) {
        throw BridgeInitializationException(
          'Bridge initialization failed after $_maxRetries attempts. '
          'Last error: $_initError',
        );
      }
      // Apply exponential backoff before retry
      final delay = _baseRetryDelay * (1 << _retryCount);
      await Future<void>.delayed(delay);
      _retryCount++;
      _initCompleter = null;
    }

    // Create new completer for this initialization attempt
    final completer = Completer<WalletBridge>();
    _initCompleter = completer;

    try {
      final bridge = await _createBridge(config);
      _instance = bridge;
      _initError = null;
      _retryCount = 0; // Reset retry count on success
      completer.complete(bridge);
    } catch (e) {
      _initError = e;
      completer.completeError(e);
      rethrow;
    }
  }

  /// Reset the bridge and release resources.
  /// Thread-safe. Cancels any pending initialization.
  static Future<void> reset() async {
    final completer = _initCompleter;

    // Wait for any ongoing initialization to complete (or fail)
    if (completer != null && !completer.isCompleted) {
      try {
        await completer.future;
      } catch (_) {
        // Ignore errors - we're resetting anyway
      }
    }

    // Dispose the instance if exists
    final instance = _instance;
    if (instance != null) {
      try {
        await instance.dispose();
      } catch (_) {
        // Log but continue - we need to reset state
      }
    }

    // Clear all state
    _instance = null;
    _initCompleter = null;
    _initError = null;
    _retryCount = 0;
  }

  /// Set a mock bridge instance (for testing).
  @visibleForTesting
  static void setInstance(WalletBridge bridge) {
    _instance = bridge;
    // Create completed completer so future initialize calls succeed fast
    _initCompleter = Completer<WalletBridge>()..complete(bridge);
    _initError = null;
    _retryCount = 0;
  }

  /// Clear the instance (for testing).
  @visibleForTesting
  static void clearInstance() {
    _instance = null;
    _initCompleter = null;
    _initError = null;
    _retryCount = 0;
  }

  static Future<WalletBridge> _createBridge(WalletConfig config) async {
    // Platform detection and bridge creation
    // This will be implemented with conditional imports
    throw UnimplementedError(
      'Platform-specific bridge not implemented. '
      'Import wallet_rust_bridge_native.dart or wallet_rust_bridge_web.dart',
    );
  }

  // ============================================================================
  // LIFECYCLE (~3 methods)
  // ============================================================================

  /// Dispose bridge resources.
  Future<void> dispose();

  // ============================================================================
  // VERSION INFO (~1 method)
  // ============================================================================

  /// Get Rust core version string.
  Future<String> getRustVersion();

  // ============================================================================
  // WALLET MANAGEMENT (~10 methods)
  // ============================================================================

  /// Generate a new mnemonic phrase.
  Future<Mnemonic> generateMnemonic({MnemonicWordCount wordCount});

  /// Check if a wallet with given name exists.
  Future<bool> walletExists({required String name});

  /// Create a new wallet.
  Future<Wallet> createWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  });

  /// Import an existing wallet from mnemonic.
  Future<Wallet> importWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  });

  /// Open/unlock a wallet.
  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  });

  /// Close/lock the current wallet.
  Future<void> closeWallet();

  /// Check if wallet is currently open.
  Future<bool> isWalletOpen();

  /// Get list of all wallet descriptors.
  Future<List<WalletDescriptor>> listWallets();

  /// Rename a wallet.
  Future<void> renameWallet({
    required String walletId,
    required String newName,
  });

  /// Change wallet password.
  Future<void> changePassword({
    required String walletId,
    required String oldPassword,
    required String newPassword,
  });

  /// Delete a wallet.
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  });

  /// Export mnemonic from wallet.
  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  });

  // ============================================================================
  // ACCOUNT MANAGEMENT (~8 methods)
  // ============================================================================

  /// Create a new account.
  Future<Account> createAccount({
    required String walletId,
    required String name,
    AccountKind kind = AccountKind.bip32,
  });

  /// Get account by ID.
  Future<Account?> getAccount({required String accountId});

  /// List all accounts for a wallet.
  Future<List<AccountDescriptor>> listAccounts({required String walletId});

  /// Get active accounts (currently syncing).
  Future<List<String>> getActiveAccounts();

  /// Activate an account (start syncing).
  Future<void> activateAccount({required String accountId});

  /// Deactivate an account (stop syncing).
  Future<void> deactivateAccount({required String accountId});

  /// Rename an account.
  Future<void> renameAccount({
    required String accountId,
    required String newName,
  });

  /// Delete an account.
  Future<void> deleteAccount({
    required String walletId,
    required String accountId,
  });

  // ============================================================================
  // ADDRESS (~5 methods)
  // ============================================================================

  /// Get current receive address.
  Future<Address> getReceiveAddress({required String accountId});

  /// Generate new receive address.
  Future<Address> generateNewAddress({required String accountId});

  /// Get multiple addresses.
  Future<List<Address>> getAddresses({
    required String accountId,
    int start = 0,
    int count = 10,
  });

  /// Check if address belongs to this account.
  Future<bool> isOwnAddress({
    required String accountId,
    required Address address,
  });

  /// Validate address format.
  Future<bool> validateAddress({required String address});

  // ============================================================================
  // BALANCE & UTXO (~5 methods)
  // ============================================================================

  /// Get balance for an account.
  Future<Balance> getBalance({required String accountId});

  /// Watch balance updates.
  Stream<Balance> watchBalance({required String accountId});

  /// Get UTXO set for an account.
  Future<UtxoSet> getUtxoSet({required String accountId});

  /// Get UTXO count.
  Future<int> getUtxoCount({required String accountId});

  /// Consolidate UTXOs (compound transaction).
  Future<TransactionId> compoundUtxos({
    required String accountId,
    required String password,
  });

  // ============================================================================
  // TRANSACTIONS (~10 methods)
  // ============================================================================

  /// Estimate transaction fee.
  Future<TransactionEstimate> estimateTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    Amount? priorityFee,
  });

  /// Send a transaction.
  Future<TransactionId> sendTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    required String password,
    Amount? priorityFee,
    String? note,
  });

  /// Send max amount (sweep).
  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  });

  /// Get transaction by ID.
  Future<Transaction?> getTransaction({required TransactionId id});

  /// Get transaction history.
  Future<List<Transaction>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
  });

  /// Watch new transactions.
  Stream<Transaction> watchTransactions({required String accountId});

  /// Wait for transaction confirmation.
  Future<Transaction> waitForConfirmation({
    required TransactionId id,
    int confirmations = 10,
    Duration? timeout,
  });

  /// Get pending transactions.
  Future<List<Transaction>> getPendingTransactions({required String accountId});

  /// Cancel a pending transaction (if possible).
  Future<bool> cancelPendingTransaction({required TransactionId id});

  /// Replace a pending transaction (RBF-like).
  Future<TransactionId> replaceTransaction({
    required TransactionId originalId,
    required Amount newPriorityFee,
    required String password,
  });

  // ============================================================================
  // NODE & SYNC (~6 methods)
  // ============================================================================

  /// Connect to node.
  Future<void> connect();

  /// Disconnect from node.
  Future<void> disconnect();

  /// Check if connected to node.
  Future<bool> isConnected();

  /// Get current sync state.
  Future<SyncState> getSyncState();

  /// Watch sync state changes.
  Stream<SyncState> watchSyncState();

  /// Get network info (block height, node version, etc).
  Future<NetworkInfo> getNetworkInfo();

  // ============================================================================
  // EVENTS
  // ============================================================================

  /// Stream of all wallet events.
  Stream<WalletEvent> get events;

  // ============================================================================
  // STEALTH (Optional Feature)
  // ============================================================================

  /// Check if stealth is supported.
  Future<bool> isStealthSupported();

  /// Create stealth account.
  Future<Account> createStealthAccount({
    required String walletId,
    required String name,
  });

  /// Get stealth address for receiving.
  Future<String> getStealthAddress({required String accountId});

  /// Scan for stealth payments.
  Future<void> scanStealthPayments({required String accountId});

  /// Get stealth scan progress.
  Stream<StealthScanProgress> watchStealthScanProgress({
    required String accountId,
  });
}
