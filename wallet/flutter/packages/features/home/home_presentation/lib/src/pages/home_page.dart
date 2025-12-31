import 'dart:developer' as developer;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:history_presentation/history_presentation.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:receive_presentation/receive_presentation.dart';
import 'package:send_presentation/send_presentation.dart';
import 'package:settings_presentation/settings_presentation.dart';

import '../stores/home_store.dart';
import '../widgets/balance_card.dart';
import '../widgets/empty_transactions_placeholder.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/transaction_list_item.dart';

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
        store.loadHomeData(accountId: 'default');
      } catch (e) {
        developer.log(
          'HomePage initState error',
          error: e,
          name: 'HomePage',
        );
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
            onPressed: () => context.push(SettingsRoutes.main),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (store.errorMessage case final errorMsg?) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(errorMsg),
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
                QuickActionsRow(
                  onSendTap: () => context.push(SendRoutes.main),
                  onReceiveTap: () => context.push(ReceiveRoutes.main),
                  onHistoryTap: () => context.push(HistoryRoutes.main),
                ),
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
                    (tx) => TransactionListItem(
                      key: ValueKey(tx.id),
                      transaction: tx,
                    ),
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
