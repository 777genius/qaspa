import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../entities/mnemonic_verification.dart';
import '../services/bip39_wordlist_service.dart';

/// Use case for generating mnemonic verification challenges.
///
/// Used in the wallet creation flow to verify that the user has
/// correctly written down their seed phrase.
@injectable
class VerifyMnemonicUseCase {
  final Bip39WordlistService _wordlistService;

  /// Number of words to verify
  static const int defaultChallengeCount = 3;

  /// Number of options per challenge
  static const int defaultOptionsPerChallenge = 4;

  final int challengeCount;
  final int optionsPerChallenge;

  VerifyMnemonicUseCase(
    this._wordlistService,
  )   : challengeCount = defaultChallengeCount,
        optionsPerChallenge = defaultOptionsPerChallenge;

  /// Generate verification challenges for a mnemonic.
  ///
  /// Selects [challengeCount] random words from the mnemonic and
  /// creates multiple-choice challenges for each.
  ///
  /// [mnemonic] - The mnemonic to create verification for
  ///
  /// Returns a [MnemonicVerification] with challenges ready for user.
  MnemonicVerification execute(Mnemonic mnemonic) {
    // Get random indices for verification (1-based)
    final indices = _wordlistService.getRandomIndices(
      challengeCount,
      totalWords: mnemonic.wordCount,
    );

    final challenges = indices.map((index) {
      final correctWord = mnemonic.wordAt(index - 1);
      final options = _wordlistService.generateVerificationOptions(
        correctWord: correctWord,
        optionCount: optionsPerChallenge,
      );

      return VerificationChallenge(
        wordIndex: index,
        correctWord: correctWord,
        options: options,
      );
    }).toList();

    return MnemonicVerification(challenges: challenges);
  }

  /// Check if the user's answer is correct for the current challenge.
  ///
  /// [verification] - Current verification state
  /// [selectedWord] - The word selected by the user
  ///
  /// Returns updated verification state with the answer recorded.
  MnemonicVerification submitAnswer(
    MnemonicVerification verification,
    String selectedWord,
  ) {
    return verification.answerCurrent(selectedWord);
  }

  /// Check if verification is complete and all answers are correct.
  bool isVerificationSuccessful(MnemonicVerification verification) {
    return verification.isComplete && verification.isAllCorrect;
  }
}
