import 'dart:math';

/// Service for working with BIP-39 wordlist
class Bip39WordlistService {
  final List<String> _wordlist;
  final Set<String> _wordSet;
  final Random _random;

  Bip39WordlistService({
    required List<String> wordlist,
    Random? random,
  })  : _wordlist = wordlist,
        _wordSet = wordlist.toSet(),
        _random = random ?? Random.secure();

  /// Total number of words in the wordlist (should be 2048)
  int get wordCount => _wordlist.length;

  /// Check if a word is in the BIP-39 wordlist
  bool isValidWord(String word) => _wordSet.contains(word.toLowerCase().trim());

  /// Get all words in the wordlist
  List<String> get allWords => List.unmodifiable(_wordlist);

  /// Search words by prefix (for autocomplete)
  /// Returns up to [limit] words that start with the given prefix
  List<String> searchByPrefix(String prefix, {int limit = 10}) {
    if (prefix.isEmpty) return const [];

    final lowerPrefix = prefix.toLowerCase().trim();
    final results = <String>[];

    for (final word in _wordlist) {
      if (word.startsWith(lowerPrefix)) {
        results.add(word);
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  /// Get a random word from the wordlist
  String getRandomWord() => _wordlist[_random.nextInt(_wordlist.length)];

  /// Get multiple random words from the wordlist
  /// [excludeWords] - words to exclude from selection
  List<String> getRandomWords(int count, {Set<String>? excludeWords}) {
    final available = excludeWords != null
        ? _wordlist.where((w) => !excludeWords.contains(w)).toList()
        : _wordlist;

    if (count > available.length) {
      throw ArgumentError(
        'Cannot select $count words from ${available.length} available',
      );
    }

    final selected = <String>[];
    final indices = <int>{};

    while (selected.length < count) {
      final index = _random.nextInt(available.length);
      if (indices.add(index)) {
        selected.add(available[index]);
      }
    }

    return selected;
  }

  /// Get random indices for verification (1-based)
  /// Returns [count] unique random indices from 1 to [totalWords]
  List<int> getRandomIndices(int count, {required int totalWords}) {
    if (count > totalWords) {
      throw ArgumentError(
        'Cannot select $count indices from $totalWords total',
      );
    }

    final indices = <int>{};
    while (indices.length < count) {
      indices.add(_random.nextInt(totalWords) + 1);
    }

    return indices.toList()..sort();
  }

  /// Generate verification options for a word
  /// Returns a list of [optionCount] words including the correct word at a random position
  List<String> generateVerificationOptions({
    required String correctWord,
    int optionCount = 4,
  }) {
    if (optionCount < 2) {
      throw ArgumentError('optionCount must be at least 2');
    }

    final wrongWords = getRandomWords(
      optionCount - 1,
      excludeWords: {correctWord},
    );

    final options = [...wrongWords];
    final correctPosition = _random.nextInt(optionCount);
    options.insert(correctPosition, correctWord);

    return options;
  }

  /// Validate a list of words (all must be in the wordlist)
  bool validateWords(List<String> words) {
    return words.every((word) => isValidWord(word));
  }

  /// Get the index of a word in the wordlist (0-based)
  /// Returns -1 if word is not found
  int indexOf(String word) => _wordlist.indexOf(word.toLowerCase().trim());
}
