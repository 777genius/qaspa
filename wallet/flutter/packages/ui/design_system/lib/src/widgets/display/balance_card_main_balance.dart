import 'package:flutter/material.dart';

import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

/// Main balance display widget showing the KAS amount.
class BalanceCardMainBalance extends StatelessWidget {
  final String formattedBalance;
  final bool isLoading;

  const BalanceCardMainBalance({
    super.key,
    required this.formattedBalance,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return SizedBox(
        height: 40,
        width: 120,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadii.borderRadiusSm,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formattedBalance,
          style: AppTypography.monoLarge.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          'KAS',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
