import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class MinerCard extends StatefulWidget {
  final MinerInstance miner;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRemove;

  const MinerCard({
    super.key,
    required this.miner,
    required this.onStart,
    required this.onStop,
    required this.onRemove,
  });

  @override
  State<MinerCard> createState() => _MinerCardState();
}

class _MinerCardState extends State<MinerCard> {
  bool _isExpanded = false;
  bool _isLoadingHistory = false;
  List<MinerMetricsPoint>? _historyData;
  String? _historyError;

  String _formatHashrate(double hashrate) {
    if (!hashrate.isFinite || hashrate < 0) {
      return '0.00 H/s';
    }
    if (hashrate >= 1e12) {
      return '${(hashrate / 1e12).toStringAsFixed(2)} TH/s';
    }
    if (hashrate >= 1e9) {
      return '${(hashrate / 1e9).toStringAsFixed(2)} GH/s';
    }
    if (hashrate >= 1e6) {
      return '${(hashrate / 1e6).toStringAsFixed(2)} MH/s';
    }
    if (hashrate >= 1e3) {
      return '${(hashrate / 1e3).toStringAsFixed(2)} KH/s';
    }
    return '${hashrate.toStringAsFixed(2)} H/s';
  }

  Future<void> _loadHistory() async {
    if (_isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final repository = GetIt.instance<MetricsRepository>();
      final history = await repository.getMinerHistory(
        widget.miner.id,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _historyData = history.data;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded && _historyData == null && !_isLoadingHistory) {
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRunning = widget.miner.status == 'running';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                        color: AdminColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AdminSpacing.sm),
                      ),
                      child: const Icon(
                        Icons.memory_outlined,
                        color: AdminColors.secondary,
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
                                widget.miner.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: AdminSpacing.sm),
                              StatusBadge.fromString(widget.miner.status),
                            ],
                          ),
                          const SizedBox(height: AdminSpacing.xxs),
                          Text(
                            'Target: ${widget.miner.targetNode}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                            widget.onStart();
                            break;
                          case 'stop':
                            widget.onStop();
                            break;
                          case 'remove':
                            widget.onRemove();
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
                if (isRunning) ...[
                  const SizedBox(height: AdminSpacing.md),
                  const Divider(),
                  const SizedBox(height: AdminSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetric(
                          context,
                          isDark,
                          'Hashrate',
                          _formatHashrate(widget.miner.hashrate),
                          Icons.speed_outlined,
                          AdminColors.warning,
                        ),
                      ),
                      const SizedBox(width: AdminSpacing.lg),
                      Expanded(
                        child: _buildMetric(
                          context,
                          isDark,
                          'Blocks Found',
                          '${widget.miner.blocksFound}',
                          Icons.view_module_outlined,
                          AdminColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  InkWell(
                    onTap: _toggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AdminSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 20,
                            color: isDark
                                ? AdminColors.textSecondaryDark
                                : AdminColors.textSecondaryLight,
                          ),
                          const SizedBox(width: AdminSpacing.xs),
                          Text(
                            _isExpanded ? 'Hide History' : 'Show History',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isExpanded && isRunning) _buildHistorySection(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, bool isDark) {
    if (_isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.all(AdminSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_historyError != null) {
      return Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Center(
          child: Column(
            children: [
              Text(
                'Failed to load history',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminColors.error,
                    ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              TextButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_historyData == null || _historyData!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Center(
          child: Text(
            'No history data yet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AdminColors.textSecondaryDark
                      : AdminColors.textSecondaryLight,
                ),
          ),
        ),
      );
    }

    final chartData = _historyData!
        .map((p) => MetricsDataPoint(
              timestamp: p.dateTime,
              value: p.hashrate,
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.cardPadding,
        0,
        AdminSpacing.cardPadding,
        AdminSpacing.cardPadding,
      ),
      child: MetricsChart(
        data: chartData,
        title: 'Hashrate History',
        lineColor: AdminColors.warning,
        formatValue: _formatHashrate,
        height: 180,
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AdminSpacing.xs),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: AdminSpacing.sm),
        Column(
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
            AnimatedValueText(
              value: value,
              highlightColor: color,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
