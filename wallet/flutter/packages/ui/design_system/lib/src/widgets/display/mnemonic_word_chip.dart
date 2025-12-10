import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';
import '../../tokens/radii.dart';

/// Single mnemonic word chip with index.
class MnemonicWordChip extends StatelessWidget {
  final int index;
  final String word;
  final bool isHidden;
  final bool isSelected;
  final VoidCallback? onTap;

  const MnemonicWordChip({
    super.key,
    required this.index,
    required this.word,
    this.isHidden = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: AppRadii.borderRadiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderRadiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$index.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                isHidden ? '••••••' : word,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
