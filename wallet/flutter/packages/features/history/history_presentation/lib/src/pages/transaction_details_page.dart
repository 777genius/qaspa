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
        debugPrint('TransactionDetailsPage initState error: $e');
      }
    });
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
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
