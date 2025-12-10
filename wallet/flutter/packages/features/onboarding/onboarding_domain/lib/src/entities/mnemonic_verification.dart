import 'package:freezed_annotation/freezed_annotation.dart';

part 'mnemonic_verification.freezed.dart';
part 'mnemonic_verification.g.dart';

/// Represents a verification challenge for a single mnemonic word
@freezed
sealed class VerificationChallenge with _$VerificationChallenge {
  const VerificationChallenge._();

  const factory VerificationChallenge({
    /// The position of the word in the mnemonic (1-based)
    required int wordIndex,

    /// The correct word that should be selected
    required String correctWord,

    /// The list of options to choose from (includes correctWord)
    required List<String> options,
  }) = _VerificationChallenge;

  factory VerificationChallenge.fromJson(Map<String, dynamic> json) =>
      _$VerificationChallengeFromJson(json);

  /// Check if the selected option is correct
  bool isCorrect(String selectedWord) =>
      selectedWord.toLowerCase() == correctWord.toLowerCase();

  /// Get the index of the correct word in options (0-based)
  int get correctOptionIndex => options.indexOf(correctWord);
}

/// Represents the complete mnemonic verification state
@freezed
sealed class MnemonicVerification with _$MnemonicVerification {
  const MnemonicVerification._();

  const factory MnemonicVerification({
    /// List of verification challenges (typically 3)
    required List<VerificationChallenge> challenges,

    /// Index of the current challenge (0-based)
    @Default(0) int currentChallengeIndex,

    /// List of user's answers (null if not answered yet)
    @Default([]) List<String?> userAnswers,
  }) = _MnemonicVerification;

  factory MnemonicVerification.fromJson(Map<String, dynamic> json) =>
      _$MnemonicVerificationFromJson(json);

  /// Total number of challenges
  int get totalChallenges => challenges.length;

  /// Get current challenge
  VerificationChallenge? get currentChallenge =>
      currentChallengeIndex < challenges.length
          ? challenges[currentChallengeIndex]
          : null;

  /// Check if all challenges have been answered
  bool get isComplete => currentChallengeIndex >= challenges.length;

  /// Check if all answers are correct
  bool get isAllCorrect {
    if (userAnswers.length != challenges.length) return false;
    for (var i = 0; i < challenges.length; i++) {
      final answer = userAnswers[i];
      if (answer == null || !challenges[i].isCorrect(answer)) {
        return false;
      }
    }
    return true;
  }

  /// Number of correct answers so far
  int get correctAnswersCount {
    var count = 0;
    for (var i = 0; i < userAnswers.length && i < challenges.length; i++) {
      final answer = userAnswers[i];
      if (answer != null && challenges[i].isCorrect(answer)) {
        count++;
      }
    }
    return count;
  }

  /// Progress as a fraction (0.0 to 1.0)
  double get progress => totalChallenges > 0
      ? currentChallengeIndex / totalChallenges
      : 0.0;

  /// Answer current challenge and move to next
  MnemonicVerification answerCurrent(String selectedWord) {
    if (isComplete) return this;

    final newAnswers = List<String?>.from(userAnswers);
    while (newAnswers.length <= currentChallengeIndex) {
      newAnswers.add(null);
    }
    newAnswers[currentChallengeIndex] = selectedWord;

    return copyWith(
      currentChallengeIndex: currentChallengeIndex + 1,
      userAnswers: newAnswers,
    );
  }

  /// Reset verification to start
  MnemonicVerification reset() => copyWith(
        currentChallengeIndex: 0,
        userAnswers: [],
      );
}

/// Result of verification attempt
enum VerificationResult {
  /// User selected correct word
  correct,

  /// User selected wrong word
  incorrect,

  /// Verification is complete and all answers are correct
  success,

  /// Verification failed (wrong answer)
  failed,
}
