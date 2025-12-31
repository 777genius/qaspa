import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Large balance card for home screen.
///
/// Composes smaller widgets for each section:
/// - [BalanceCardLabel] - "Total Balance" label
/// - [BalanceCardMainBalance] - Main amount
/// - [BalanceCardFiatValue] - Optional fiat equivalent
/// - [BalanceCardPending] - Pending balance indicator
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    this.isLoading = false,
    this.showPending = true,
    this.fiatValue,
    this.onTap,
  });

  final Balance balance;
  final bool isLoading;
  final bool showPending;
  final String? fiatValue;
  final VoidCallback? onTap;

  static const _currency = 'KAS';

  @override
  Widget build(BuildContext context) {
    final formattedBalance = _formatBalance(balance.availableKas);
    final formattedPending = _formatBalance(balance.pendingKas);

    final balanceLabel = isLoading
        ? 'Balance loading'
        : 'Total balance: $formattedBalance $_currency';
    final pendingLabel = showPending && balance.pending > BigInt.zero
        ? ', $formattedPending $_currency pending'
        : '';

    return Semantics(
      label: '$balanceLabel$pendingLabel',
      button: onTap != null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.card,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BalanceCardLabel(),
                const SizedBox(height: AppSpacing.xs),
                BalanceCardMainBalance(
                  formattedBalance: formattedBalance,
                  currency: _currency,
                  isLoading: isLoading,
                ),
                if (fiatValue != null) ...[
                  const SizedBox(height: AppSpacing.xxxs),
                  BalanceCardFiatValue(fiatValue: fiatValue!),
                ],
                if (showPending && balance.pending > BigInt.zero) ...[
                  const SizedBox(height: AppSpacing.sm),
                  BalanceCardPending(
                    formattedPendingBalance: formattedPending,
                    currency: _currency,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format balance with precision awareness.
  /// Uses "~" prefix for compact abbreviations to indicate approximation.
  String _formatBalance(double value) {
    if (value == 0) return '0';
    if (value >= 1000000) {
      return '~${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 1000) {
      return '~${(value / 1000).toStringAsFixed(2)}K';
    }
    if (value >= 1) {
      return value.toStringAsFixed(2);
    }
    return value.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '');
  }
}
