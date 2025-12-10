import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../navigation/stealth_routes.dart';
import '../stores/stealth_store.dart';

/// Main stealth (privacy) feature page.
class StealthPage extends StatefulWidget {
  const StealthPage({super.key});

  @override
  State<StealthPage> createState() => _StealthPageState();
}

class _StealthPageState extends State<StealthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final store = ModuleProvider.of(context).get<StealthStore>();
        // TODO: Get actual account ID from wallet state
        store.setAccountId('default');
      } catch (e) {
        debugPrint('StealthPage initState error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<StealthStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stealth Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: store.scanForPayments,
            tooltip: 'Scan for payments',
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.visibility_off,
                          size: 48,
                          color: Colors.purple,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Private Balance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${store.stealthBalanceInKas.toStringAsFixed(8)} KAS',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (store.isScanning) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Scanning for payments...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (store.scanTotal > 0)
                            Text(
                              '${store.scanProgress} / ${store.scanTotal} blocks',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (store.errorMessage != null) ...[
                  Card(
                    color: AppColors.error.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: AppColors.error),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(store.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(StealthRoutes.receive),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Receive'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(StealthRoutes.send),
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Send'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Recent Private Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: store.stealthTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Text('No private transactions yet'),
                              const SizedBox(height: AppSpacing.md),
                              TextButton(
                                onPressed: store.scanForPayments,
                                child: const Text('Scan for payments'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: store.stealthTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = store.stealthTransactions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Icon(
                                    Icons.visibility_off,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  '${tx.formatAmount()} KAS',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
