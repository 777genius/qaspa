import 'package:injectable/injectable.dart';

import '../services/bip39_wordlist_service.dart';

/// Use case for validating a mnemonic phrase against BIP-39 wordlist.
///
/// Used during wallet import to verify that all words are valid BIP-39 words.
@Injectable()
class ValidateMnemonicUseCase {
  final Bip39WordlistService _wordlistService;

  ValidateMnemonicUseCase(this._wordlistService);

  /// Validate a list of words against the BIP-39 wordlist.
  ///
  /// [words] - List of words to validate
  ///
  /// Returns `true` if all words are valid BIP-39 words, `false` otherwise.
  bool execute(List<String> words) {
    if (words.isEmpty) return false;
    if (words.length != 12 && words.length != 24) return false;
    return _wordlistService.validateWords(words);
  }

  /// Validate a single word against the BIP-39 wordlist.
  bool isValidWord(String word) {
    return _wordlistService.isValidWord(word);
  }

  /// Get word suggestions for autocomplete.
  ///
  /// [prefix] - The prefix to search for
  /// [limit] - Maximum number of suggestions (default 10)
  List<String> getSuggestions(String prefix, {int limit = 10}) {
    return _wordlistService.searchByPrefix(prefix, limit: limit);
  }

  /// Get validation result with details.
  MnemonicValidationResult validateWithDetails(List<String> words) {
    if (words.isEmpty) {
      return const MnemonicValidationResult(
        isValid: false,
        errorMessage: 'Mnemonic is empty',
      );
    }

    if (words.length != 12 && words.length != 24) {
      return MnemonicValidationResult(
        isValid: false,
        errorMessage: 'Mnemonic must be 12 or 24 words, got ${words.length}',
      );
    }

    final invalidWords = <int, String>{};
    for (var i = 0; i < words.length; i++) {
      if (!_wordlistService.isValidWord(words[i])) {
        invalidWords[i + 1] = words[i];
      }
    }

    if (invalidWords.isNotEmpty) {
      return MnemonicValidationResult(
        isValid: false,
        errorMessage: 'Invalid words found',
        invalidWordIndices: invalidWords.keys.toList(),
      );
    }

    return const MnemonicValidationResult(isValid: true);
  }
}

/// Result of mnemonic validation with details.
class MnemonicValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<int> invalidWordIndices;

  const MnemonicValidationResult({
    required this.isValid,
    this.errorMessage,
    this.invalidWordIndices = const [],
  });
}
