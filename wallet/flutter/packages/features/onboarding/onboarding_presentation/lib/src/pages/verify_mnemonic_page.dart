import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_indicator.dart';
import '../widgets/verification_challenge.dart';
import '../widgets/verification_failure.dart';
import '../widgets/verification_progress.dart';
import '../widgets/verification_success.dart';

/// Page for verifying the mnemonic phrase.
class VerifyMnemonicPage extends StatelessWidget {
  /// Callback when verification is complete
  final VoidCallback onContinue;

  /// Callback when user wants to go back
  final VoidCallback onBack;

  const VerifyMnemonicPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return OnboardingScaffold(
      title: 'Verify Seed Phrase',
      onBack: onBack,
      bottomActions: Observer(
        builder: (_) => SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: store.canProceedFromVerify
                ? () {
                    store.proceedToNextStep();
                    onContinue();
                  }
                : null,
            child: const Text('Continue'),
          ),
        ),
      ),
      child: Observer(
        builder: (_) {
          final verification = store.verification;
          if (verification == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepIndicator(
                currentStep: store.currentStepNumber,
                totalSteps: store.totalSteps,
              ),
              const SizedBox(height: AppSpacing.xl),
              VerificationProgress(
                current: verification.currentChallengeIndex,
                total: verification.totalChallenges,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!verification.isComplete && verification.currentChallenge != null)
                VerificationChallenge(
                  challenge: verification.currentChallenge!,
                  onOptionSelected: (word) {
                    store.submitVerificationAnswer(word);
                  },
                )
              else if (verification.isAllCorrect)
                const VerificationSuccess()
              else
                VerificationFailure(
                  onRetry: () {
                    store.proceedToVerification();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
