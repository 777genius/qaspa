import 'package:equatable/equatable.dart';

/// Mnemonic word count options.
enum MnemonicWordCount {
  words12(12),
  words24(24);

  final int count;
  const MnemonicWordCount(this.count);
}

/// BIP-39 Mnemonic value object.
/// Validates mnemonic phrase format (word count, BIP-39 compliance).
class Mnemonic extends Equatable {
  final List<String> words;

  const Mnemonic._(this.words);

  /// Create from word list
  factory Mnemonic.fromWords(List<String> words) {
    if (words.length != 12 && words.length != 24) {
      throw ArgumentError(
        'Mnemonic must be 12 or 24 words, got ${words.length}',
      );
    }

    // Normalize words
    final normalized = words.map((w) => w.toLowerCase().trim()).toList();

    // Validate no empty words
    if (normalized.any((w) => w.isEmpty)) {
      throw ArgumentError('Mnemonic contains empty words');
    }

    return Mnemonic._(normalized);
  }

  /// Create from space-separated phrase
  factory Mnemonic.fromPhrase(String phrase) {
    final words = phrase.trim().split(RegExp(r'\s+'));
    return Mnemonic.fromWords(words);
  }

  /// Word count
  int get wordCount => words.length;

  /// Get word at index (0-based)
  String wordAt(int index) => words[index];

  /// Convert to phrase string
  String toPhrase() => words.join(' ');

  /// Get masked phrase for display (shows only first and last word)
  String get masked {
    if (words.length <= 2) return '*** ***';
    return '${words.first} ${'*** ' * (words.length - 2)}${words.last}';
  }

  /// Validate against BIP-39 wordlist (basic check)
  /// Full validation happens in Rust
  bool get hasValidFormat {
    return words.every((word) => word.length >= 3 && word.length <= 8);
  }

  @override
  String toString() => '[Mnemonic: ${words.length} words]';

  @override
  List<Object?> get props => [words];
}
