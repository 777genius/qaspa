import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';
import '../widgets/mnemonic_verification_grid.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_indicator.dart';

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
              if (!verification.isComplete)
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
                    // Reset verification
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

/// Progress indicator for verification.
class VerificationProgress extends StatelessWidget {
  final int current;
  final int total;

  const VerificationProgress({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          current < total
              ? 'Select word ${current + 1} of $total'
              : 'Verification Complete',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (index) {
            final isComplete = index < current;
            final isCurrent = index == current;

            return Container(
              width: 12,
              height: 12,
              margin: EdgeInsets.only(right: index < total - 1 ? 8 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isComplete
                    ? AppColors.success
                    : isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
              ),
              child: isComplete
                  ? const Icon(
                      Icons.check,
                      size: 8,
                      color: Colors.white,
                    )
                  : null,
            );
          }),
        ),
      ],
    );
  }
}

/// Current verification challenge display.
class VerificationChallenge extends StatelessWidget {
  final dynamic challenge;
  final ValueChanged<String> onOptionSelected;

  const VerificationChallenge({
    super.key,
    required this.challenge,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadii.borderRadiusMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Word #${challenge.wordIndex}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Select the correct word:',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MnemonicVerificationGrid(
          options: challenge.options,
          onOptionSelected: onOptionSelected,
        ),
      ],
    );
  }
}

/// Success state after verification.
class VerificationSuccess extends StatelessWidget {
  const VerificationSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Verification Complete!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Your recovery phrase has been verified.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Failure state after verification.
class VerificationFailure extends StatelessWidget {
  final VoidCallback onRetry;

  const VerificationFailure({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_rounded,
              size: 64,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Verification Failed',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Please check your recovery phrase and try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
