import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Transaction list item card.
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncoming = transaction.isIncoming;
    final typeLabel = _getTypeLabel();
    final statusLabel = transaction.isConfirmed ? '' : ', pending';

    return Semantics(
      label: '$typeLabel ${transaction.formatAmount()} KAS$statusLabel',
      button: onTap != null,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.card,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                _TransactionIcon(isIncoming: isIncoming, kind: transaction.kind),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TransactionTitle(kind: transaction.kind),
                      const SizedBox(height: AppSpacing.xxxs),
                      _TransactionSubtitle(transaction: transaction),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountDisplay(
                      value: transaction.formatAmount(),
                      currency: 'KAS',
                      showSign: true,
                      isPositive: isIncoming,
                    ),
                    if (!transaction.isConfirmed)
                      Text(
                        'Pending',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.pending,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeLabel() {
    return switch (transaction.kind) {
      TransactionKind.incoming => 'Received',
      TransactionKind.outgoing => 'Sent',
      TransactionKind.transferIncoming => 'Transfer received',
      TransactionKind.transferOutgoing => 'Transfer sent',
      TransactionKind.batch => 'Batch transaction',
      TransactionKind.change => 'Change',
      TransactionKind.reorg => 'Reorganization',
      TransactionKind.stasis => 'Stasis',
      TransactionKind.external => 'External',
    };
  }
}

class _TransactionIcon extends StatelessWidget {
  const _TransactionIcon({required this.isIncoming, required this.kind});

  final bool isIncoming;
  final TransactionKind kind;

  @override
  Widget build(BuildContext context) {
    final color = isIncoming ? AppColors.incoming : AppColors.outgoing;
    final icon = _getIcon();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadii.borderRadiusSm,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  IconData _getIcon() {
    return switch (kind) {
      TransactionKind.incoming => Icons.arrow_downward_rounded,
      TransactionKind.outgoing => Icons.arrow_upward_rounded,
      TransactionKind.transferIncoming => Icons.swap_horiz_rounded,
      TransactionKind.transferOutgoing => Icons.swap_horiz_rounded,
      TransactionKind.batch => Icons.layers_rounded,
      TransactionKind.change => Icons.cached_rounded,
      TransactionKind.reorg => Icons.refresh_rounded,
      TransactionKind.stasis => Icons.pause_circle_rounded,
      TransactionKind.external => Icons.call_received_rounded,
    };
  }
}

class _TransactionTitle extends StatelessWidget {
  const _TransactionTitle({required this.kind});

  final TransactionKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      _getTitle(),
      style: theme.textTheme.titleSmall,
    );
  }

  String _getTitle() {
    return switch (kind) {
      TransactionKind.incoming => 'Received',
      TransactionKind.outgoing => 'Sent',
      TransactionKind.transferIncoming => 'Transfer In',
      TransactionKind.transferOutgoing => 'Transfer Out',
      TransactionKind.batch => 'Batch',
      TransactionKind.change => 'Change',
      TransactionKind.reorg => 'Reorg',
      TransactionKind.stasis => 'Stasis',
      TransactionKind.external => 'External',
    };
  }
}

class _TransactionSubtitle extends StatelessWidget {
  const _TransactionSubtitle({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      _formatDate(transaction.date),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}
