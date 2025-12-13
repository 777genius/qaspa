import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:onboarding_domain/onboarding_domain.dart';

import 'mnemonic_verification_grid.dart';

/// Current verification challenge display.
class VerificationChallenge extends StatelessWidget {
  final MnemonicChallenge challenge;
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
