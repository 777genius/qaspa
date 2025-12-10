import 'package:flutter/material.dart';

/// Label widget for balance card showing "Total Balance".
class BalanceCardLabel extends StatelessWidget {
  const BalanceCardLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'Total Balance',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
