import 'dart:async';
import 'dart:io';

import 'package:wallet_domain/wallet_domain.dart';

import '../wallet_bridge.dart';
import '../wallet_config.dart';
import '../events/wallet_events.dart';

/// Native (FFI) implementation of [WalletBridge].
/// Uses flutter_rust_bridge to communicate with kaspa-wallet-core.
class WalletBridgeNative implements WalletBridge {
  // TODO: Add flutter_rust_bridge generated bindings
  // late final RustLib _rustLib;

  final _eventsController = StreamController<WalletEvent>.broadcast();

  WalletBridgeNative._();

  /// Initialize the native bridge.
  static Future<WalletBridgeNative> init(WalletConfig config) async {
    final bridge = WalletBridgeNative._();

    // TODO: Initialize flutter_rust_bridge
    // await RustLib.init();
    // bridge._rustLib = RustLib.instance;
    //
    // await bridge._rustLib.initializeWallet(
    //   nodeUrl: config.nodeUrl,
    //   networkId: config.networkId.toString(),
    //   storagePath: config.storagePath ?? _getDefaultStoragePath(),
    // );

    return bridge;
  }

  /// Get default storage path for wallet data.
  /// Platform-specific paths follow OS conventions.
  /// Will be used when FFI bridge is implemented.
  // ignore: unused_element
  static String _getDefaultStoragePath() {
    if (Platform.isAndroid) {
      // Android app private directory
      return '/data/data/com.kaspa.wallet/files/wallet';
    }

    if (Platform.isIOS) {
      // iOS app container (will be overridden by path_provider in production)
      return '${Directory.systemTemp.parent.path}/wallet';
    }

    if (Platform.isMacOS) {
      // macOS ~/Library/Application Support/Kaspa
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw StateError('HOME environment variable not set on macOS');
      }
      return '$home/Library/Application Support/Kaspa/wallet';
    }

    if (Platform.isLinux) {
      // Linux ~/.local/share/kaspa or XDG_DATA_HOME
      final xdgData = Platform.environment['XDG_DATA_HOME'];
      if (xdgData != null && xdgData.isNotEmpty) {
        return '$xdgData/kaspa/wallet';
      }
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw StateError('HOME environment variable not set on Linux');
      }
      return '$home/.local/share/kaspa/wallet';
    }

    if (Platform.isWindows) {
      // Windows %LOCALAPPDATA%\Kaspa or fallback to USERPROFILE
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return '$localAppData\\Kaspa\\wallet';
      }
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile == null || userProfile.isEmpty) {
        throw StateError(
          'LOCALAPPDATA and USERPROFILE environment variables not set on Windows',
        );
      }
      return '$userProfile\\AppData\\Local\\Kaspa\\wallet';
    }

    // Unsupported platform
    throw UnsupportedError(
      'Unsupported platform: ${Platform.operatingSystem}',
    );
  }

  @override
  Stream<WalletEvent> get events => _eventsController.stream;

  @override
  Future<void> dispose() async {
    // Close all stream controllers
    await _eventsController.close();
    // TODO: Dispose Rust resources
    // await _rustLib.dispose();
  }

  @override
  Future<String> getRustVersion() async {
    // TODO: return await _rustLib.getRustVersion();
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Mnemonic> generateMnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) async {
    // TODO: final words = await _rustLib.generateMnemonic(wordCount: wordCount.count);
    // return Mnemonic.fromWords(words);
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Wallet> createWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Wallet> importWallet({
    required String name,
    required Mnemonic mnemonic,
    required String password,
    required NetworkId networkId,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> closeWallet() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<List<WalletDescriptor>> listWallets() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Account> createAccount({
    required String walletId,
    required String name,
    AccountKind kind = AccountKind.bip32,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Account?> getAccount({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<List<AccountDescriptor>> listAccounts({
    required String walletId,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Address> getReceiveAddress({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Address> generateNewAddress({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Balance> getBalance({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Stream<Balance> watchBalance({required String accountId}) {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<TransactionEstimate> estimateTransaction({
    required String accountId,
    required Address destination,
    required Amount amount,
    Amount? priorityFee,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
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
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<List<Transaction>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Stream<Transaction> watchTransactions({required String accountId}) {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> connect() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> disconnect() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<SyncState> getSyncState() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Stream<SyncState> watchSyncState() {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> isConnected() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> walletExists({required String name}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> isWalletOpen() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> renameWallet({
    required String walletId,
    required String newName,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String oldPassword,
    required String newPassword,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<List<String>> getActiveAccounts() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> activateAccount({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> deactivateAccount({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> renameAccount({
    required String accountId,
    required String newName,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> deleteAccount({
    required String walletId,
    required String accountId,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<List<Address>> getAddresses({
    required String accountId,
    int start = 0,
    int count = 10,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> isOwnAddress({
    required String accountId,
    required Address address,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> validateAddress({required String address}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<UtxoSet> getUtxoSet({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<int> getUtxoCount({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<TransactionId> compoundUtxos({
    required String accountId,
    required String password,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Transaction?> getTransaction({required TransactionId id}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Transaction> waitForConfirmation({
    required TransactionId id,
    int confirmations = 10,
    Duration? timeout,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<List<Transaction>> getPendingTransactions({
    required String accountId,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> cancelPendingTransaction({required TransactionId id}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<TransactionId> replaceTransaction({
    required TransactionId originalId,
    required Amount newPriorityFee,
    required String password,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<NetworkInfo> getNetworkInfo() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<bool> isStealthSupported() async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<Account> createStealthAccount({
    required String walletId,
    required String name,
  }) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<void> scanStealthPayments({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Future<String> getStealthAddress({required String accountId}) async {
    throw UnimplementedError('Native bridge not implemented');
  }

  @override
  Stream<StealthScanProgress> watchStealthScanProgress({
    required String accountId,
  }) {
    throw UnimplementedError('Native bridge not implemented');
  }
}
