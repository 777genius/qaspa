import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_rust_bridge/wallet_rust_bridge.dart';

/// Default timeout for Rust FFI operations.
/// Prevents app freeze if Rust hangs.
const _defaultTimeout = Duration(seconds: 30);

/// Timeout for quick operations (balance, account info).
const _quickTimeout = Duration(seconds: 10);

/// Timeout for network operations (send, connect).
const _networkTimeout = Duration(seconds: 60);

/// Datasource that wraps [WalletBridge] operations.
/// Provides a clean interface for repository implementations.
/// All async operations have timeouts to prevent app freeze.
@LazySingleton()
class RustDatasource {
  final WalletBridge _bridge;

  RustDatasource(this._bridge);

  /// Wrap future with timeout and proper error mapping.
  Future<T> _withTimeout<T>(
    Future<T> future, {
    Duration timeout = _defaultTimeout,
  }) {
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        message: 'Rust operation timed out after ${timeout.inSeconds}s',
        timeout: timeout,
      ),
    );
  }

  /// Factory using singleton bridge instance.
  factory RustDatasource.instance() => RustDatasource(WalletBridge.instance);

  // === Wallet Operations ===

  Future<Mnemonic> generateMnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) =>
      _bridge.generateMnemonic(wordCount: wordCount);

  Future<Wallet> createWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) =>
      _bridge.createWallet(
        name: name,
        mnemonic: mnemonic,
        password: password,
        networkId: networkId,
      );

  Future<Wallet> importWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) =>
      _bridge.importWallet(
        name: name,
        mnemonic: mnemonic,
        password: password,
        networkId: networkId,
      );

  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  }) =>
      _withTimeout(
        _bridge.openWallet(walletId: walletId, password: password),
      );

  Future<void> closeWallet() => _bridge.closeWallet();

  Future<List<WalletDescriptor>> listWallets() => _bridge.listWallets();

  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) =>
      _bridge.deleteWallet(walletId: walletId, password: password);

  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  }) =>
      _bridge.exportMnemonic(walletId: walletId, password: password);

  // === Account Operations ===

  Future<Account> createAccount({
    required String walletId,
    required String name,
    AccountKind kind = AccountKind.bip32,
  }) =>
      _bridge.createAccount(walletId: walletId, name: name, kind: kind);

  Future<Account?> getAccount({required String accountId}) =>
      _bridge.getAccount(accountId: accountId);

  Future<List<AccountDescriptor>> listAccounts({required String walletId}) =>
      _bridge.listAccounts(walletId: walletId);

  Future<Address> getReceiveAddress({required String accountId}) =>
      _bridge.getReceiveAddress(accountId: accountId);

  Future<Address> generateNewAddress({required String accountId}) =>
      _bridge.generateNewAddress(accountId: accountId);

  // === Balance Operations ===

  Future<Balance> getBalance({required String accountId}) =>
      _withTimeout(
        _bridge.getBalance(accountId: accountId),
        timeout: _quickTimeout,
      );

  Stream<Balance> watchBalance({required String accountId}) =>
      _bridge.watchBalance(accountId: accountId);

  // === Transaction Operations ===

  Future<TransactionEstimate> estimateTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    Amount? priorityFee,
  }) =>
      _withTimeout(
        _bridge.estimateTransaction(
          accountId: accountId,
          destination: destination,
          amount: amount,
          priorityFee: priorityFee,
        ),
        timeout: _networkTimeout,
      );

  Future<TransactionId> sendTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    required String password,
    Amount? priorityFee,
    String? note,
  }) =>
      _withTimeout(
        _bridge.sendTransaction(
          accountId: accountId,
          destination: destination,
          amount: amount,
          password: password,
          priorityFee: priorityFee,
          note: note,
        ),
        timeout: _networkTimeout,
      );

  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  }) =>
      _withTimeout(
        _bridge.sendMax(
          accountId: accountId,
          destination: destination,
          password: password,
          note: note,
        ),
        timeout: _networkTimeout,
      );

  Future<List<Transaction>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
  }) =>
      _bridge.getTransactions(
        accountId: accountId,
        limit: limit,
        offset: offset,
      );

  Stream<Transaction> watchTransactions({required String accountId}) =>
      _bridge.watchTransactions(accountId: accountId);

  // === Connection ===

  Future<void> connect() => _withTimeout(
        _bridge.connect(),
        timeout: _networkTimeout,
      );

  Future<void> disconnect() => _withTimeout(
        _bridge.disconnect(),
        timeout: _quickTimeout,
      );

  Future<bool> isConnected() => _withTimeout(
        _bridge.isConnected(),
        timeout: _quickTimeout,
      );

  Future<SyncState> getSyncState() => _bridge.getSyncState();

  Stream<SyncState> watchSyncState() => _bridge.watchSyncState();

  // === Events ===

  Stream<WalletEvent> get events => _bridge.events;

  // === Stealth ===

  Future<void> scanStealthPayments({required String accountId}) =>
      _bridge.scanStealthPayments(accountId: accountId);

  Future<String> getStealthAddress({required String accountId}) =>
      _bridge.getStealthAddress(accountId: accountId);
}
