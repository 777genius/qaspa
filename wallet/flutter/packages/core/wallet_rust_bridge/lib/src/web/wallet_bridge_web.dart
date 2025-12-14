import 'dart:async';
import 'dart:developer' as developer;

import 'package:wallet_domain/wallet_domain.dart';

import '../wallet_bridge.dart';
import '../wallet_config.dart';
import '../events/wallet_events.dart';

/// Web (WASM) implementation of [WalletBridge].
/// Uses kaspa-wallet WASM module for web and Chrome extension.
class WalletBridgeWeb implements WalletBridge {
  // TODO: Add WASM JS interop
  // late final JsWallet _jsWallet;

  final _eventsController = StreamController<WalletEvent>.broadcast();

  WalletBridgeWeb._();

  /// Initialize the web bridge.
  static Future<WalletBridgeWeb> init(WalletConfig config) async {
    final bridge = WalletBridgeWeb._();

    // TODO: Load WASM module
    // await _loadWasmModule();
    //
    // final storage = switch (config.storageBackend) {
    //   StorageBackend.indexedDb => 'indexeddb',
    //   StorageBackend.chromeStorage => 'chrome',
    //   _ => 'indexeddb',
    // };
    //
    // bridge._jsWallet = await js_util.callMethod(
    //   js_util.globalThis,
    //   'initKaspaWallet',
    //   [config.nodeUrl, config.networkId.toString(), storage],
    // );

    return bridge;
  }

  @override
  Stream<WalletEvent> get events => _eventsController.stream;

  @override
  Future<void> dispose() async {
    // Close all stream controllers safely
    try {
      if (!_eventsController.isClosed) {
        await _eventsController.close();
      }
    } catch (e) {
      developer.log(
        'Error closing events controller',
        name: 'WalletBridgeWeb',
        error: e,
      );
    }
    // TODO: Dispose WASM resources
    // _jsWallet?.dispose();
  }

  @override
  Future<String> getRustVersion() async {
    // TODO: return js_util.callMethod(_jsWallet, 'getVersion', []);
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Mnemonic> generateMnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Wallet> createWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Wallet> importWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> closeWallet() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<List<WalletDescriptor>> listWallets() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Account> createAccount({
    required String walletId,
    required String name,
    AccountKind kind = AccountKind.bip32,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Account?> getAccount({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<List<AccountDescriptor>> listAccounts({
    required String walletId,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Address> getReceiveAddress({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Address> generateNewAddress({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Balance> getBalance({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Stream<Balance> watchBalance({required String accountId}) {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<TransactionEstimate> estimateTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    Amount? priorityFee,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
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
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<List<Transaction>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Stream<Transaction> watchTransactions({required String accountId}) {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> connect() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> disconnect() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<SyncState> getSyncState() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Stream<SyncState> watchSyncState() {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> isConnected() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> walletExists({required String name}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> isWalletOpen() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> renameWallet({
    required String walletId,
    required String newName,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String oldPassword,
    required String newPassword,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<List<String>> getActiveAccounts() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> activateAccount({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> deactivateAccount({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> renameAccount({
    required String accountId,
    required String newName,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> deleteAccount({
    required String walletId,
    required String accountId,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<List<Address>> getAddresses({
    required String accountId,
    int start = 0,
    int count = 10,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> isOwnAddress({
    required String accountId,
    required Address address,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> validateAddress({required String address}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<UtxoSet> getUtxoSet({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<int> getUtxoCount({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<TransactionId> compoundUtxos({
    required String accountId,
    required String password,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Transaction?> getTransaction({required TransactionId id}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Transaction> waitForConfirmation({
    required TransactionId id,
    int confirmations = 10,
    Duration? timeout,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<List<Transaction>> getPendingTransactions({
    required String accountId,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> cancelPendingTransaction({required TransactionId id}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<TransactionId> replaceTransaction({
    required TransactionId originalId,
    required Amount newPriorityFee,
    required String password,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<NetworkInfo> getNetworkInfo() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<bool> isStealthSupported() async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<Account> createStealthAccount({
    required String walletId,
    required String name,
  }) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<void> scanStealthPayments({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Future<String> getStealthAddress({required String accountId}) async {
    throw UnimplementedError('Web bridge not implemented');
  }

  @override
  Stream<StealthScanProgress> watchStealthScanProgress({
    required String accountId,
  }) {
    throw UnimplementedError('Web bridge not implemented');
  }
}
