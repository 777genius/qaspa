import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';

class NodeCard extends StatelessWidget {
  final NodeInstance node;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onRemove;

  const NodeCard({
    super.key,
    required this.node,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRunning = node.status == 'running';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AdminColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AdminSpacing.sm),
                  ),
                  child: const Icon(
                    Icons.dns_outlined,
                    color: AdminColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AdminSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            node.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: AdminSpacing.sm),
                          StatusBadge.fromString(node.status),
                          if (node.role == 'seed') ...[
                            const SizedBox(width: AdminSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AdminSpacing.xs,
                                vertical: AdminSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AdminSpacing.xs),
                              ),
                              child: Text(
                                'SEED',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AdminColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AdminSpacing.xxs),
                      Text(
                        'P2P: ${node.p2pPort} • gRPC: ${node.grpcPort}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AdminColors.textSecondaryDark
                                  : AdminColors.textSecondaryLight,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'start':
                        onStart();
                        break;
                      case 'stop':
                        onStop();
                        break;
                      case 'restart':
                        onRestart();
                        break;
                      case 'remove':
                        onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isRunning)
                      const PopupMenuItem(
                        value: 'start',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 18),
                            SizedBox(width: AdminSpacing.sm),
                            Text('Start'),
                          ],
                        ),
                      ),
                    if (isRunning)
                      const PopupMenuItem(
                        value: 'stop',
                        child: Row(
                          children: [
                            Icon(Icons.stop, size: 18),
                            SizedBox(width: AdminSpacing.sm),
                            Text('Stop'),
                          ],
                        ),
                      ),
                    if (isRunning)
                      const PopupMenuItem(
                        value: 'restart',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: AdminSpacing.sm),
                            Text('Restart'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: AdminColors.error),
                          const SizedBox(width: AdminSpacing.sm),
                          Text('Remove',
                              style: TextStyle(color: AdminColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (node.metrics != null && isRunning) ...[
              const SizedBox(height: AdminSpacing.md),
              const Divider(),
              const SizedBox(height: AdminSpacing.md),
              _buildMetricsRow(context, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context, bool isDark) {
    final metrics = node.metrics;
    if (metrics == null) return const SizedBox.shrink();
    return Wrap(
      spacing: AdminSpacing.lg,
      runSpacing: AdminSpacing.sm,
      children: [
        _buildMetric(context, isDark, 'Blocks', '${metrics.blockCount}'),
        _buildMetric(context, isDark, 'Headers', '${metrics.headerCount}'),
        _buildMetric(context, isDark, 'DAA', '${metrics.virtualDaaScore}'),
        _buildMetric(context, isDark, 'Peers', '${metrics.peerCount}'),
        _buildMetric(context, isDark, 'Mempool', '${metrics.mempoolSize}'),
        _buildSyncedStatus(context, metrics.isSynced),
      ],
    );
  }

  Widget _buildMetric(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AdminColors.textTertiaryDark
                    : AdminColors.textTertiaryLight,
              ),
        ),
        const SizedBox(height: AdminSpacing.xxs),
        AnimatedValueText(
          value: value,
          highlightColor: AdminColors.info,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }

  Widget _buildSyncedStatus(BuildContext context, bool isSynced) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSynced ? Icons.check_circle : Icons.sync,
          size: 16,
          color: isSynced ? AdminColors.success : AdminColors.warning,
        ),
        const SizedBox(width: AdminSpacing.xs),
        Text(
          isSynced ? 'Synced' : 'Syncing',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSynced ? AdminColors.success : AdminColors.warning,
              ),
        ),
      ],
    );
  }
}
