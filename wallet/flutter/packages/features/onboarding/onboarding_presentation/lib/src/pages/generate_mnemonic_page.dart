import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/security_warning_card.dart';
import '../widgets/step_indicator.dart';

/// Page for generating a new mnemonic phrase.
class GenerateMnemonicPage extends StatefulWidget {
  /// Callback when user wants to proceed
  final VoidCallback onContinue;

  /// Callback when user wants to go back
  final VoidCallback onBack;

  const GenerateMnemonicPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<GenerateMnemonicPage> createState() => _GenerateMnemonicPageState();
}

class _GenerateMnemonicPageState extends State<GenerateMnemonicPage> {
  @override
  void initState() {
    super.initState();
    // Generate mnemonic when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = ModuleProvider.of(context).get<OnboardingStore>();
      if (store.mnemonic == null) {
        store.generateMnemonic();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return OnboardingScaffold(
      title: 'Create Wallet',
      onBack: widget.onBack,
      bottomActions: Observer(
        builder: (_) => SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: store.canProceedFromGenerate ? widget.onContinue : null,
            child: const Text('Continue'),
          ),
        ),
      ),
      child: Observer(
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepIndicator(
              currentStep: store.currentStepNumber,
              totalSteps: store.totalSteps,
            ),
            const SizedBox(height: AppSpacing.xl),
            SecurityWarningCard.seedPhraseBackup(),
            const SizedBox(height: AppSpacing.lg),
            if (store.isLoading)
              const GenerateMnemonicLoading()
            else if (store.mnemonic != null)
              GenerateMnemonicContent(
                words: store.mnemonic!.words,
              )
            else if (store.errorMessage != null)
              GenerateMnemonicError(
                message: store.errorMessage!,
                onRetry: store.generateMnemonic,
              ),
          ],
        ),
      ),
    );
  }
}

/// Loading state while generating mnemonic.
class GenerateMnemonicLoading extends StatelessWidget {
  const GenerateMnemonicLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.sm),
          Text('Generating secure seed phrase...'),
        ],
      ),
    );
  }
}

/// Content showing the generated mnemonic.
class GenerateMnemonicContent extends StatelessWidget {
  final List<String> words;

  const GenerateMnemonicContent({
    super.key,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Recovery Phrase',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Write down these 24 words in order and store them safely.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MnemonicGrid(
          words: words,
          showCopyButton: true,
        ),
      ],
    );
  }
}

/// Error state when mnemonic generation fails.
class GenerateMnemonicError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const GenerateMnemonicError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Failed to generate seed phrase',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
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
