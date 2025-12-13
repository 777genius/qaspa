import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../navigation/history_routes.dart';
import '../stores/history_store.dart';

/// Transaction history list page.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<HistoryStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: Observer(
        builder: (_) {
          if (store.isLoading && store.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (store.errorMessage != null && store.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(store.errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: store.loadTransactions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (store.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No transactions yet'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: store.loadTransactions,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: store.transactions.length + (store.hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= store.transactions.length) {
                  if (!store.isLoadingMore) {
                    store.loadMore();
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final transaction = store.transactions[index];
                return _TransactionListItem(
                  key: ValueKey(transaction.id),
                  transaction: transaction,
                  onTap: () => context.push(
                    HistoryRoutes.details.replaceFirst(
                      ':transactionId',
                      transaction.id.value,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const _TransactionListItem({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.isIncoming;
    final amountColor = isIncoming ? AppColors.success : AppColors.error;
    final amountPrefix = isIncoming ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.1),
          child: Icon(
            isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
            color: amountColor,
          ),
        ),
        title: Text(
          '$amountPrefix${transaction.formatAmount()} KAS',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: amountColor,
          ),
        ),
        subtitle: Text(
          _formatDate(transaction.date),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Icon(
          transaction.isConfirmed ? Icons.check_circle : Icons.schedule,
          color: transaction.isConfirmed ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
