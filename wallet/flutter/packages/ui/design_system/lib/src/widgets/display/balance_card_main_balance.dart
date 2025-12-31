import 'package:flutter/material.dart';

import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

/// Main balance display widget showing the formatted amount.
class BalanceCardMainBalance extends StatelessWidget {
  const BalanceCardMainBalance({
    super.key,
    required this.formattedBalance,
    this.currency,
    this.isLoading = false,
  });

  final String formattedBalance;
  final String? currency;
  final bool isLoading;

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
        if (currency != null) ...[
          const SizedBox(width: AppSpacing.xxs),
          Text(
            currency!,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
