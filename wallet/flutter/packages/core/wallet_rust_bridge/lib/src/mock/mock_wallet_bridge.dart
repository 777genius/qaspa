import 'dart:async';

import 'package:wallet_domain/wallet_domain.dart';

import '../wallet_bridge.dart';
import '../events/wallet_events.dart';

/// Mock implementation of [WalletBridge] for testing.
class MockWalletBridge implements WalletBridge {
  // Required for WalletBridge.setInstance to work
  MockWalletBridge();

  final _eventsController = StreamController<WalletEvent>.broadcast();
  final _balanceControllers = <String, StreamController<Balance>>{};
  final _transactionControllers = <String, StreamController<Transaction>>{};
  final _syncStateController = StreamController<SyncState>.broadcast();

  bool _isConnected = false;
  bool _isDisposed = false;
  SyncState _syncState = const SyncState.notSynced();
  Wallet? _currentWallet;

  final Map<String, Wallet> _wallets = {};
  final Map<String, Account> _accounts = {};
  final Map<String, Balance> _balances = {};
  final Map<String, List<Transaction>> _transactions = {};

  @override
  Stream<WalletEvent> get events => _eventsController.stream;

  @override
  Future<String> getRustVersion() async => '1.0.0';

  @override
  Future<Mnemonic> generateMnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) async {
    final words = List.generate(
      wordCount.count,
      (i) => _testWords[i % _testWords.length],
    );
    return Mnemonic.fromWords(words);
  }

  @override
  Future<Wallet> createWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) async {
    final wallet = Wallet(
      id: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      networkId: networkId.toString(),
      isOpen: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _wallets[wallet.id] = wallet;
    _currentWallet = wallet;
    return wallet;
  }

  @override
  Future<Wallet> importWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) async {
    return createWallet(
      name: name,
      mnemonic: mnemonic,
      password: password,
      networkId: networkId,
    );
  }

  @override
  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  }) async {
    final wallet = _wallets[walletId];
    if (wallet == null) {
      throw WalletNotFoundException(walletId: walletId);
    }
    _currentWallet = wallet.copyWith(isOpen: true);
    _wallets[walletId] = _currentWallet!;
    return _currentWallet!;
  }

  @override
  Future<bool> walletExists({required String name}) async {
    return _wallets.values.any((w) => w.name == name);
  }

  @override
  Future<bool> isWalletOpen() async {
    final wallet = _currentWallet;
    return wallet != null && wallet.isOpen;
  }

  @override
  Future<void> renameWallet({
    required String walletId,
    required String newName,
  }) async {
    final wallet = _wallets[walletId];
    if (wallet != null) {
      _wallets[walletId] = wallet.copyWith(name: newName);
    }
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String oldPassword,
    required String newPassword,
  }) async {
    // Mock: no-op
  }

  @override
  Future<void> closeWallet() async {
    final wallet = _currentWallet;
    if (wallet != null) {
      _wallets[wallet.id] = wallet.copyWith(isOpen: false);
      _currentWallet = null;
    }
  }

  @override
  Future<List<WalletDescriptor>> listWallets() async {
    return _wallets.values
        .map((w) => WalletDescriptor(
              id: w.id,
              name: w.name,
              networkId: w.networkId,
              createdAt: w.createdAt,
            ))
        .toList();
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    _wallets.remove(walletId);
  }

  @override
  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  }) async {
    return generateMnemonic();
  }

  @override
  Future<Account> createAccount({
    required String walletId,
    required String name,
    AccountKind kind = AccountKind.bip32,
  }) async {
    final account = Account(
      id: 'account_${DateTime.now().millisecondsSinceEpoch}',
      walletId: walletId,
      name: name,
      kind: kind,
      accountIndex: _accounts.values.where((a) => a.walletId == walletId).length,
      receiveAddress: null,
    );
    _accounts[account.id] = account;
    _balances[account.id] = Balance.zero();
    _transactions[account.id] = [];
    return account;
  }

  @override
  Future<Account?> getAccount({required String accountId}) async {
    return _accounts[accountId];
  }

  @override
  Future<List<AccountDescriptor>> listAccounts({
    required String walletId,
  }) async {
    return _accounts.values
        .where((a) => a.walletId == walletId)
        .map((a) => AccountDescriptor(
              id: a.id,
              walletId: a.walletId,
              name: a.name,
              kind: a.kind,
              accountIndex: a.accountIndex,
            ))
        .toList();
  }

  @override
  Future<List<String>> getActiveAccounts() async {
    return _accounts.keys.toList();
  }

  @override
  Future<void> activateAccount({required String accountId}) async {
    // Mock: no-op
  }

  @override
  Future<void> deactivateAccount({required String accountId}) async {
    // Mock: no-op
  }

  @override
  Future<void> renameAccount({
    required String accountId,
    required String newName,
  }) async {
    final account = _accounts[accountId];
    if (account != null) {
      _accounts[accountId] = Account(
        id: account.id,
        walletId: account.walletId,
        name: newName,
        kind: account.kind,
        accountIndex: account.accountIndex,
        receiveAddress: account.receiveAddress,
      );
    }
  }

  @override
  Future<void> deleteAccount({
    required String walletId,
    required String accountId,
  }) async {
    _accounts.remove(accountId);
    _balances.remove(accountId);
    _transactions.remove(accountId);

    // Close and remove stream controllers to prevent memory leaks
    final balanceController = _balanceControllers.remove(accountId);
    await balanceController?.close();

    final txController = _transactionControllers.remove(accountId);
    await txController?.close();
  }

  @override
  Future<Address> getReceiveAddress({required String accountId}) async {
    final account = _accounts[accountId];
    if (account == null) {
      throw ArgumentError('Account not found: $accountId');
    }
    return Address.fromString(
      account.receiveAddress ?? 'kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx9awp4e',
    );
  }

  @override
  Future<List<Address>> getAddresses({
    required String accountId,
    int start = 0,
    int count = 10,
  }) async {
    return [await getReceiveAddress(accountId: accountId)];
  }

  @override
  Future<bool> isOwnAddress({
    required String accountId,
    required Address address,
  }) async {
    return true;
  }

  @override
  Future<bool> validateAddress({required String address}) async {
    try {
      Address.fromString(address);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Address> generateNewAddress({required String accountId}) async {
    return getReceiveAddress(accountId: accountId);
  }

  @override
  Future<Balance> getBalance({required String accountId}) async {
    return _balances[accountId] ?? Balance.zero();
  }

  @override
  Stream<Balance> watchBalance({required String accountId}) {
    _balanceControllers[accountId] ??= StreamController<Balance>.broadcast();
    return _balanceControllers[accountId]!.stream;
  }

  @override
  Future<UtxoSet> getUtxoSet({required String accountId}) async {
    return const UtxoSet(mature: [], pending: [], stasis: []);
  }

  @override
  Future<int> getUtxoCount({required String accountId}) async {
    return 0;
  }

  @override
  Future<TransactionId> compoundUtxos({
    required String accountId,
    required String password,
  }) async {
    return TransactionId.fromHex('0' * 64);
  }

  @override
  Future<TransactionEstimate> estimateTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    Amount? priorityFee,
  }) async {
    final fee = Amount.fromSompi(BigInt.from(10000));
    return TransactionEstimate(
      amount: amount,
      fee: fee,
      total: amount + fee,
      utxoCount: 1,
    );
  }

  @override
  Future<TransactionId> sendTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    required String password,
    Amount? priorityFee,
    String? note,
  }) async {
    final txId = TransactionId.fromHex(
      '0' * 64,
    );
    return txId;
  }

  @override
  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  }) async {
    return TransactionId.fromHex('0' * 64);
  }

  @override
  Future<List<Transaction>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
  }) async {
    return _transactions[accountId] ?? [];
  }

  @override
  Stream<Transaction> watchTransactions({required String accountId}) {
    _transactionControllers[accountId] ??=
        StreamController<Transaction>.broadcast();
    return _transactionControllers[accountId]!.stream;
  }

  @override
  Future<Transaction?> getTransaction({required TransactionId id}) async {
    for (final txList in _transactions.values) {
      for (final tx in txList) {
        if (tx.id == id) return tx;
      }
    }
    return null;
  }

  @override
  Future<Transaction> waitForConfirmation({
    required TransactionId id,
    int confirmations = 10,
    Duration? timeout,
  }) async {
    final tx = await getTransaction(id: id);
    if (tx != null) return tx;
    throw ArgumentError('Transaction not found: $id');
  }

  @override
  Future<List<Transaction>> getPendingTransactions({
    required String accountId,
  }) async {
    return (_transactions[accountId] ?? [])
        .where((tx) => !tx.isConfirmed)
        .toList();
  }

  @override
  Future<bool> cancelPendingTransaction({required TransactionId id}) async {
    return false;
  }

  @override
  Future<TransactionId> replaceTransaction({
    required TransactionId originalId,
    required Amount newPriorityFee,
    required String password,
  }) async {
    return TransactionId.fromHex('0' * 64);
  }

  @override
  Future<void> connect() async {
    _isConnected = true;
    if (!_eventsController.isClosed) {
      _eventsController.add(ConnectionEvent(isConnected: true));
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    if (!_eventsController.isClosed) {
      _eventsController.add(ConnectionEvent(isConnected: false));
    }
  }

  @override
  Future<NetworkInfo> getNetworkInfo() async {
    return NetworkInfo(
      networkId: NetworkId.mainnet,
      nodeVersion: '1.0.0',
      blockCount: 1000000,
      headerCount: 1000000,
      daaScore: 1000000,
      difficulty: 1000000000,
      isSynced: true,
    );
  }

  @override
  Future<SyncState> getSyncState() async => _syncState;

  @override
  Stream<SyncState> watchSyncState() => _syncStateController.stream;

  @override
  Future<bool> isConnected() async => _isConnected;

  @override
  Future<bool> isStealthSupported() async => true;

  @override
  Future<Account> createStealthAccount({
    required String walletId,
    required String name,
  }) async {
    return createAccount(
      walletId: walletId,
      name: name,
      kind: AccountKind.bip32,
    );
  }

  @override
  Future<void> scanStealthPayments({required String accountId}) async {
    // Mock: no-op
  }

  @override
  Future<String> getStealthAddress({required String accountId}) async {
    return 'kaspa:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx9awp4e';
  }

  @override
  Stream<StealthScanProgress> watchStealthScanProgress({
    required String accountId,
  }) {
    return Stream.empty();
  }

  // === Test Helpers ===

  /// Set balance for testing.
  void setBalance(String accountId, Balance balance) {
    if (_isDisposed) return;
    _balances[accountId] = balance;
    final controller = _balanceControllers[accountId];
    if (controller != null && !controller.isClosed) {
      controller.add(balance);
    }
    if (!_eventsController.isClosed) {
      _eventsController.add(BalanceUpdateEvent(
        accountId: accountId,
        balance: balance,
      ));
    }
  }

  /// Add transaction for testing.
  void addTransaction(String accountId, Transaction tx) {
    if (_isDisposed) return;
    _transactions[accountId] ??= [];
    _transactions[accountId]!.add(tx);
    final controller = _transactionControllers[accountId];
    if (controller != null && !controller.isClosed) {
      controller.add(tx);
    }
    if (!_eventsController.isClosed) {
      _eventsController.add(TransactionEvent(
        accountId: accountId,
        transaction: tx,
      ));
    }
  }

  /// Set sync state for testing.
  void setSyncState(SyncState state) {
    if (_isDisposed) return;
    _syncState = state;
    if (!_syncStateController.isClosed) {
      _syncStateController.add(state);
    }
    if (!_eventsController.isClosed) {
      _eventsController.add(SyncStateEvent(state: state));
    }
  }

  /// Dispose resources.
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
    if (!_syncStateController.isClosed) {
      await _syncStateController.close();
    }
    for (final controller in _balanceControllers.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    for (final controller in _transactionControllers.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _balanceControllers.clear();
    _transactionControllers.clear();
  }

  static const _testWords = [
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
    'absurd',
    'abuse',
    'access',
    'accident',
    'account',
    'accuse',
    'achieve',
    'acid',
    'acoustic',
    'acquire',
    'across',
    'act',
    'action',
    'actor',
    'actress',
    'actual',
  ];
}
