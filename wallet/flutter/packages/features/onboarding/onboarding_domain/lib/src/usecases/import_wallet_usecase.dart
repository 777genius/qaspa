import 'package:wallet_domain/wallet_domain.dart';

import '../services/bip39_wordlist_service.dart';

/// Use case for importing an existing wallet from a mnemonic phrase.
///
/// This is the main step in the wallet import flow, after:
/// 1. User enters mnemonic words (ImportMnemonicPage)
class ImportWalletUseCase {
  final WalletRepository _walletRepository;
  final Bip39WordlistService _wordlistService;

  ImportWalletUseCase({
    required WalletRepository walletRepository,
    required Bip39WordlistService wordlistService,
  })  : _walletRepository = walletRepository,
        _wordlistService = wordlistService;

  /// Import a wallet from an existing mnemonic phrase.
  ///
  /// [name] - Display name for the wallet
  /// [password] - Encryption password (minimum 8 characters)
  /// [words] - List of mnemonic words (12 or 24)
  /// [networkId] - Network to use (mainnet or testnet)
  ///
  /// Returns the imported [Wallet].
  ///
  /// Throws:
  /// - [InvalidMnemonicException] if mnemonic is invalid
  /// - [InvalidPasswordException] if password is too short
  /// - [InvalidWalletNameException] if wallet name is invalid
  /// - [WalletAlreadyExistsException] if wallet with same name exists
  Future<Wallet> execute({
    required String name,
    required String password,
    required List<String> words,
    required NetworkId networkId,
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

    // Validate word count
    if (words.length != 12 && words.length != 24) {
      throw InvalidMnemonicException(
        message: 'Mnemonic must be 12 or 24 words',
        wordCount: words.length,
      );
    }

    // Validate all words against BIP-39 wordlist
    final invalidWords = <String>[];
    for (final word in words) {
      if (!_wordlistService.isValidWord(word)) {
        invalidWords.add(word);
      }
    }

    if (invalidWords.isNotEmpty) {
      throw InvalidMnemonicException(
        message: 'Invalid BIP-39 words: ${invalidWords.join(", ")}',
        invalidWord: invalidWords.first,
      );
    }

    // Create Mnemonic value object
    final mnemonic = Mnemonic.fromWords(words);

    return _walletRepository.importWallet(
      name: trimmedName,
      password: password,
      mnemonic: mnemonic,
      networkId: networkId,
    );
  }

  /// Validate mnemonic words without importing.
  ///
  /// Returns `true` if all words are valid BIP-39 words.
  bool validateWords(List<String> words) {
    if (words.length != 12 && words.length != 24) return false;
    return _wordlistService.validateWords(words);
  }
}
