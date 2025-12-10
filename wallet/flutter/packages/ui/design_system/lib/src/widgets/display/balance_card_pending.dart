import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';

/// Pending balance indicator for the balance card.
class BalanceCardPending extends StatelessWidget {
  final String formattedPendingBalance;

  const BalanceCardPending({
    super.key,
    required this.formattedPendingBalance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            '+$formattedPendingBalance KAS pending',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
