import 'package:wallet_domain/wallet_domain.dart';

/// Use case for creating a new wallet with a previously generated mnemonic.
///
/// This is the final step in the wallet creation flow, after:
/// 1. Generating mnemonic (GenerateMnemonicUseCase)
/// 2. User backup (BackupMnemonicPage)
/// 3. Verification (VerifyMnemonicUseCase)
class CreateWalletUseCase {
  final WalletRepository _walletRepository;

  CreateWalletUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  /// Create a new wallet with the given parameters.
  ///
  /// [name] - Display name for the wallet
  /// [password] - Encryption password (minimum 8 characters)
  /// [networkId] - Network to use (mainnet or testnet)
  /// [wordCount] - Number of words in mnemonic (default 24)
  ///
  /// Returns the created [Wallet].
  ///
  /// Throws:
  /// - [InvalidPasswordException] if password is too short
  /// - [InvalidWalletNameException] if wallet name is invalid
  /// - [WalletAlreadyExistsException] if wallet with same name exists
  Future<Wallet> execute({
    required String name,
    required String password,
    required NetworkId networkId,
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) async {
    // Validate password length
    if (password.length < 8) {
      throw InvalidPasswordException.tooShort();
    }

    // Validate wallet name
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw InvalidWalletNameException.empty();
    }

    return _walletRepository.createWallet(
      name: trimmedName,
      password: password,
      networkId: networkId,
      wordCount: wordCount,
    );
  }
}
