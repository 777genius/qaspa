import 'package:wallet_domain/wallet_domain.dart';

/// Use case for generating a new BIP-39 mnemonic phrase.
///
/// This is the first step in wallet creation flow.
/// The generated mnemonic should be shown to the user for backup.
class GenerateMnemonicUseCase {
  final WalletRepository _walletRepository;

  GenerateMnemonicUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  /// Generate a new mnemonic with the specified word count.
  ///
  /// [wordCount] - Number of words (12 or 24, defaults to 24)
  ///
  /// Returns a [Mnemonic] containing the generated words.
  /// The mnemonic is generated using secure randomness in the Rust layer.
  Future<Mnemonic> execute({
    MnemonicWordCount wordCount = MnemonicWordCount.words24,
  }) async {
    return _walletRepository.generateMnemonic(wordCount: wordCount);
  }
}
