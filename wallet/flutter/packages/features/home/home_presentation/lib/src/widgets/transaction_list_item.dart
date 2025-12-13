import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Transaction list item.
class TransactionListItem extends StatelessWidget {
  final Transaction transaction;

  const TransactionListItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.swap_horiz_rounded,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(transaction.id.value),
      subtitle: Text(transaction.date.toString()),
      trailing: Text(
        transaction.formatAmount(),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
