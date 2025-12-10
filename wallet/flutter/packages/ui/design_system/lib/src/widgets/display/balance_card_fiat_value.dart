import 'package:flutter/material.dart';

/// Fiat value display widget showing balance in local currency.
class BalanceCardFiatValue extends StatelessWidget {
  final String fiatValue;

  const BalanceCardFiatValue({
    super.key,
    required this.fiatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      fiatValue,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
