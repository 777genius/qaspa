import 'dart:developer' as developer;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../stores/history_store.dart';

/// Transaction details page.
class TransactionDetailsPage extends StatefulWidget {
  final String transactionId;

  const TransactionDetailsPage({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionDetailsPage> createState() => _TransactionDetailsPageState();
}

class _TransactionDetailsPageState extends State<TransactionDetailsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final store = ModuleProvider.of(context).get<HistoryStore>();
        store.selectTransaction(TransactionId.fromHex(widget.transactionId));
      } catch (e) {
        developer.log(
          'TransactionDetailsPage initState error',
          error: e,
          name: 'TransactionDetailsPage',
        );
      }
    });
  }

  @override
  void dispose() {
    // Clear selected transaction when leaving details page
    try {
      final store = ModuleProvider.of(context).get<HistoryStore>();
      store.clearSelectedTransaction();
    } catch (_) {
      // Module may already be disposed
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<HistoryStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: Observer(
        builder: (_) {
          final transaction = store.selectedTransaction;

          if (transaction == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailCard(
                  title: 'Amount',
                  value: '${transaction.formatAmount()} KAS',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailCard(
                  title: 'Transaction ID',
                  value: transaction.id.value,
                  copyable: true,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailCard(
                  title: 'Status',
                  value: transaction.isConfirmed ? 'CONFIRMED' : 'PENDING',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailCard(
                  title: 'Date',
                  value: _formatDate(transaction.date),
                ),
                if (transaction.fee != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DetailCard(
                    title: 'Fee',
                    value: '${transaction.formatFee()} KAS',
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final bool copyable;

  const _DetailCard({
    required this.title,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: textTheme.bodyLarge,
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy to clipboard',
                    onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to copy')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
