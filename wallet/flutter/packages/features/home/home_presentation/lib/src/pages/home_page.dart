import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/home_store.dart';

/// Main home page showing wallet balance and recent transactions.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final store = ModuleProvider.of(context).get<HomeStore>();
        // TODO: Get actual account ID from wallet state
        store.loadHomeData(accountId: 'default');
      } catch (e) {
        debugPrint('HomePage initState error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<HomeStore>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaspa Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (store.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(store.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => store.loadHomeData(accountId: 'default'),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                store.refreshBalance(),
                store.refreshTransactions(),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                // Balance Card
                BalanceCard(balance: store.balance),
                const SizedBox(height: AppSpacing.lg),

                // Quick Actions
                const QuickActionsRow(),
                const SizedBox(height: AppSpacing.lg),

                // Recent Transactions
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (store.hasTransactions)
                  ...store.recentTransactions.map(
                    (tx) => TransactionListItem(transaction: tx),
                  )
                else
                  const EmptyTransactionsPlaceholder(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card showing wallet balance.
class BalanceCard extends StatelessWidget {
  final dynamic balance;

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
          colors: [AppColors.kaspaGreen, AppColors.kaspaTeal],
        ),
        borderRadius: AppRadii.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            balance?.formatted ?? '0.00 KAS',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of quick action buttons.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionButton(
            icon: Icons.arrow_upward_rounded,
            label: 'Send',
            onTap: () {
              // TODO: Navigate to send
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Receive',
            onTap: () {
              // TODO: Navigate to receive
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: () {
              // TODO: Navigate to history
            },
          ),
        ),
      ],
    );
  }
}

/// Quick action button widget.
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadii.borderRadiusMd,
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// Transaction list item.
class TransactionListItem extends StatelessWidget {
  final dynamic transaction;

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
      title: Text(transaction.id ?? 'Transaction'),
      subtitle: Text(transaction.timestamp?.toString() ?? ''),
      trailing: Text(
        transaction.amount?.toString() ?? '0 KAS',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Placeholder for empty transactions.
class EmptyTransactionsPlaceholder extends StatelessWidget {
  const EmptyTransactionsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No transactions yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
