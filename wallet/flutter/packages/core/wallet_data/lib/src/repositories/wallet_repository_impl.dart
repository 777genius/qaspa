import 'package:injectable/injectable.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:synchronized/synchronized.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../datasources/rust_datasource.dart';

/// Implementation of [WalletRepository] using Rust bridge.
///
/// Uses [Lock] to prevent race conditions when opening/closing wallets
/// from multiple concurrent calls.
@modularityExportEnv
@LazySingleton(as: WalletRepository)
class WalletRepositoryImpl implements WalletRepository {
  final RustDatasource _rust;

  /// Lock to prevent race conditions on wallet state operations.
  final _walletLock = Lock();

  /// Currently opened wallet (tracked in memory).
  /// Access should be synchronized via [_walletLock].
  Wallet? _currentWallet;

  WalletRepositoryImpl(this._rust);

  /// Factory using singleton datasource.
  factory WalletRepositoryImpl.instance() =>
      WalletRepositoryImpl(RustDatasource.instance());

  @override
  Future<List<WalletDescriptor>> listWallets() => _rust.listWallets();

  @override
  Future<bool> hasWallet() async {
    final wallets = await _rust.listWallets();
    return wallets.isNotEmpty;
  }

  @override
  Future<Wallet> createWallet({
    required String name,
    required String password,
    required NetworkId networkId,
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) async {
    final mnemonic = await _rust.generateMnemonic(wordCount: wordCount);
    return _rust.createWallet(
      name: name,
      mnemonic: mnemonic,
      password: password,
      networkId: networkId,
    );
  }

  @override
  Future<Wallet> importWallet({
    required String name,
    required String password,
    required Mnemonic mnemonic,
    required NetworkId networkId,
  }) =>
      _rust.importWallet(
        name: name,
        mnemonic: mnemonic,
        password: password,
        networkId: networkId,
      );

  @override
  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  }) async {
    return _walletLock.synchronized(() async {
      final currentWallet = _currentWallet;
      if (currentWallet != null) {
        throw WalletAlreadyOpenException(
          walletId: walletId,
          message: 'Cannot open wallet "$walletId" - wallet "${currentWallet.id}" is already open',
        );
      }
      final wallet =
          await _rust.openWallet(walletId: walletId, password: password);
      _currentWallet = wallet;
      return wallet;
    });
  }

  @override
  Future<void> closeWallet() async {
    await _walletLock.synchronized(() async {
      await _rust.closeWallet();
      _currentWallet = null;
    });
  }

  @override
  Future<Wallet?> getCurrentWallet() async {
    return _walletLock.synchronized(() async {
      return _currentWallet;
    });
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) =>
      _rust.deleteWallet(walletId: walletId, password: password);

  @override
  Future<Wallet> renameWallet({
    required String walletId,
    required String newName,
  }) {
    throw UnimplementedError('Rename not yet implemented in Rust bridge');
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String oldPassword,
    required String newPassword,
  }) {
    throw UnimplementedError('Change password not yet implemented');
  }

  @override
  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  }) =>
      _rust.exportMnemonic(walletId: walletId, password: password);

  @override
  Future<bool> validatePassword({
    required String walletId,
    required String password,
  }) async {
    return _walletLock.synchronized(() async {
      // Don't validate if a wallet is already open
      final currentWallet = _currentWallet;
      if (currentWallet != null) {
        throw WalletAlreadyOpenException(walletId: currentWallet.id);
      }

      try {
        await _rust.openWallet(walletId: walletId, password: password);
        return true;
      } on DecryptionFailedException {
        return false;
      } finally {
        // Always close wallet, even if an error occurred after opening
        try {
          await _rust.closeWallet();
        } catch (_) {
          // Ignore close errors - wallet may not have been opened
        }
      }
    });
  }

  @override
  Future<Mnemonic> generateMnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) =>
      _rust.generateMnemonic(wordCount: wordCount);
}
