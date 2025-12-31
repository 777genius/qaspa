import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Card showing wallet balance.
class BalanceCard extends StatelessWidget {
  final Balance? balance;

  const BalanceCard({super.key, this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary, AppColors.brandSecondary],
        ),
        borderRadius: AppRadii.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${balance?.formatAvailable() ?? '0.00'} KAS',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
