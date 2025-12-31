import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';

/// Pending balance indicator for the balance card.
class BalanceCardPending extends StatelessWidget {
  const BalanceCardPending({
    super.key,
    required this.formattedPendingBalance,
    this.currency,
    this.label = 'pending',
  });

  final String formattedPendingBalance;
  final String? currency;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySuffix = currency != null ? ' $currency' : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: AppRadii.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            '+$formattedPendingBalance$currencySuffix $label',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
