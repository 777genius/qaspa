import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';
import '../widgets/mnemonic_input_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_indicator.dart';

/// Page for importing an existing mnemonic phrase.
class ImportMnemonicPage extends StatefulWidget {
  /// Callback when import is validated
  final VoidCallback onContinue;

  /// Callback when user wants to go back
  final VoidCallback onBack;

  const ImportMnemonicPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<ImportMnemonicPage> createState() => _ImportMnemonicPageState();
}

class _ImportMnemonicPageState extends State<ImportMnemonicPage> {
  final List<FocusNode> _focusNodes = List.generate(24, (_) => FocusNode());

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusNextField(int currentIndex) {
    if (currentIndex < 23) {
      _focusNodes[currentIndex + 1].requestFocus();
    } else {
      // Last field, unfocus
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return OnboardingScaffold(
      title: 'Import Wallet',
      onBack: widget.onBack,
      scrollable: true,
      bottomActions: Observer(
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (store.errorMessage != null) ...[
              Text(
                store.errorMessage!,
                style: TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: store.canProceedFromImport
                    ? () async {
                        await store.validateImportedMnemonic();
                        if (store.errorMessage == null) {
                          widget.onContinue();
                        }
                      }
                    : null,
                child: const Text('Continue'),
              ),
            ),
          ],
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
            const SizedBox(height: AppSpacing.lg),
            ImportMnemonicHeader(
              validCount: store.validImportedWordsCount,
              totalCount: 24,
            ),
            const SizedBox(height: AppSpacing.md),
            ImportMnemonicGrid(
              words: store.importedWords,
              focusNodes: _focusNodes,
              onWordChanged: store.setImportedWord,
              onWordSubmitted: _focusNextField,
              getSuggestions: store.getSuggestions,
              isWordValid: store.isWordValid,
            ),
          ],
        ),
      ),
    );
  }
}

/// Header with progress counter.
class ImportMnemonicHeader extends StatelessWidget {
  final int validCount;
  final int totalCount;

  const ImportMnemonicHeader({
    super.key,
    required this.validCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Recovery Phrase',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Text(
              'Enter your 24-word recovery phrase',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: validCount == totalCount
                    ? AppColors.success.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$validCount/$totalCount',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: validCount == totalCount
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Grid of mnemonic input fields.
class ImportMnemonicGrid extends StatelessWidget {
  final List<String> words;
  final List<FocusNode> focusNodes;
  final void Function(int index, String word) onWordChanged;
  final void Function(int index) onWordSubmitted;
  final List<String> Function(String prefix) getSuggestions;
  final bool Function(int index) isWordValid;

  const ImportMnemonicGrid({
    super.key,
    required this.words,
    required this.focusNodes,
    required this.onWordChanged,
    required this.onWordSubmitted,
    required this.getSuggestions,
    required this.isWordValid,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 3,
      ),
      itemCount: 24,
      itemBuilder: (context, index) {
        final word = words[index];
        final hasValue = word.isNotEmpty;

        return MnemonicInputField(
          wordIndex: index + 1,
          value: word,
          onChanged: (value) => onWordChanged(index, value),
          onSubmitted: () => onWordSubmitted(index),
          getSuggestions: getSuggestions,
          isValid: hasValue ? isWordValid(index) : null,
          focusNode: focusNodes[index],
        );
      },
    );
  }
}
