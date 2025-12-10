import '../entities/wallet.dart';
import '../value_objects/mnemonic.dart';
import '../value_objects/network_id.dart';

/// Repository interface for wallet operations.
/// Implementations: RustWalletRepository (wallet_data package)
abstract interface class WalletRepository {
  /// List all wallet descriptors
  Future<List<WalletDescriptor>> listWallets();

  /// Check if any wallet exists
  Future<bool> hasWallet();

  /// Create a new wallet with generated mnemonic
  Future<Wallet> createWallet({
    required String name,
    required String password,
    required NetworkId networkId,
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  });

  /// Import wallet from existing mnemonic
  Future<Wallet> importWallet({
    required String name,
    required String password,
    required Mnemonic mnemonic,
    required NetworkId networkId,
  });

  /// Open/unlock an existing wallet
  Future<Wallet> openWallet({
    required String walletId,
    required String password,
  });

  /// Close/lock the current wallet
  Future<void> closeWallet();

  /// Get currently open wallet (null if none)
  Future<Wallet?> getCurrentWallet();

  /// Delete a wallet permanently
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  });

  /// Rename a wallet
  Future<Wallet> renameWallet({
    required String walletId,
    required String newName,
  });

  /// Change wallet password
  Future<void> changePassword({
    required String walletId,
    required String oldPassword,
    required String newPassword,
  });

  /// Export mnemonic (requires password)
  Future<Mnemonic> exportMnemonic({
    required String walletId,
    required String password,
  });

  /// Validate password without opening wallet
  Future<bool> validatePassword({
    required String walletId,
    required String password,
  });

  /// Generate preview of mnemonic (for wallet creation flow)
  Future<Mnemonic> generateMnemonic({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  });
}
