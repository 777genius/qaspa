import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/security_warning_card.dart';
import '../widgets/step_indicator.dart';

/// Page for backing up the mnemonic phrase.
class BackupMnemonicPage extends StatelessWidget {
  /// Callback when user wants to proceed to verification
  final VoidCallback onContinue;

  /// Callback when user wants to go back
  final VoidCallback onBack;

  const BackupMnemonicPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return OnboardingScaffold(
      title: 'Backup Seed Phrase',
      onBack: onBack,
      bottomActions: Observer(
        builder: (_) => SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: store.canProceedFromBackup
                ? () {
                    store.proceedToVerification();
                    onContinue();
                  }
                : null,
            child: const Text('I\'ve Written It Down'),
          ),
        ),
      ),
      child: Observer(
        builder: (_) {
          final mnemonic = store.mnemonic;
          if (mnemonic == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepIndicator(
                currentStep: store.currentStepNumber,
                totalSteps: store.totalSteps,
              ),
              const SizedBox(height: AppSpacing.xl),
              SecurityWarningCard.seedPhraseBackup(),
              const SizedBox(height: AppSpacing.lg),
              BackupMnemonicContent(
                words: mnemonic.words,
                isRevealed: store.isMnemonicRevealed,
                onReveal: store.revealMnemonic,
              ),
              const SizedBox(height: AppSpacing.lg),
              BackupConfirmationCheckbox(
                isChecked: store.isBackupConfirmed,
                isEnabled: store.isMnemonicRevealed,
                onChanged: (value) {
                  if (value == true) store.confirmBackup();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Content showing mnemonic with reveal functionality.
class BackupMnemonicContent extends StatelessWidget {
  final List<String> words;
  final bool isRevealed;
  final VoidCallback onReveal;

  const BackupMnemonicContent({
    super.key,
    required this.words,
    required this.isRevealed,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recovery Phrase',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isRevealed)
              TextButton.icon(
                onPressed: onReveal,
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Reveal'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isRevealed)
          MnemonicGrid(
            words: words,
            showCopyButton: true,
          )
        else
          HiddenMnemonicPlaceholder(
            wordCount: words.length,
            onReveal: onReveal,
          ),
      ],
    );
  }
}

/// Placeholder for hidden mnemonic.
class HiddenMnemonicPlaceholder extends StatelessWidget {
  final int wordCount;
  final VoidCallback onReveal;

  const HiddenMnemonicPlaceholder({
    super.key,
    required this.wordCount,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onReveal,
      borderRadius: AppRadii.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadii.borderRadiusMd,
          border: Border.all(
            color: theme.colorScheme.outline,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.visibility_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap to reveal $wordCount words',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Make sure no one is watching',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checkbox for confirming backup.
class BackupConfirmationCheckbox extends StatelessWidget {
  final bool isChecked;
  final bool isEnabled;
  final ValueChanged<bool?> onChanged;

  const BackupConfirmationCheckbox({
    super.key,
    required this.isChecked,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isEnabled ? () => onChanged(!isChecked) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: isEnabled ? onChanged : null,
            ),
            Expanded(
              child: Text(
                'I have safely stored my recovery phrase',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isEnabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
