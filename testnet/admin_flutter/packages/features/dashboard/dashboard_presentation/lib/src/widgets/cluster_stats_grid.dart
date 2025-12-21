import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../stores/dashboard_store.dart';

class ClusterStatsGrid extends StatelessWidget {
  final DashboardStore store;

  const ClusterStatsGrid({
    super.key,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1400
              ? 4
              : constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;

          return GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AdminSpacing.sm,
            mainAxisSpacing: AdminSpacing.sm,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: [
              StatCard(
                title: 'Total Nodes',
                value: '${store.totalNodes}',
                icon: Icons.dns_outlined,
                iconColor: AdminColors.info,
                subtitle: '${store.runningNodes} running',
              ),
              StatCard(
                title: 'Total Miners',
                value: '${store.totalMiners}',
                icon: Icons.memory_outlined,
                iconColor: AdminColors.secondary,
                subtitle: '${store.runningMiners} active',
              ),
              StatCard(
                title: 'Block Count',
                value: _formatNumber(store.totalBlockCount),
                icon: Icons.view_module_outlined,
                iconColor: AdminColors.primary,
              ),
              StatCard(
                title: 'Total Hashrate',
                value: _formatHashrate(store.totalHashrate),
                icon: Icons.speed_outlined,
                iconColor: AdminColors.warning,
              ),
              StatCard(
                title: 'DAA Score',
                value: _formatNumber(store.stats?.virtualDaaScore ?? 0),
                icon: Icons.timeline_outlined,
                iconColor: AdminColors.success,
              ),
              StatCard(
                title: 'Mempool Size',
                value: '${store.stats?.totalMempoolSize ?? 0}',
                icon: Icons.layers_outlined,
                iconColor: AdminColors.error,
                subtitle: 'transactions',
              ),
              StatCard(
                title: 'Total Peers',
                value: '${store.stats?.totalPeers ?? 0}',
                icon: Icons.hub_outlined,
                iconColor: AdminColors.info,
              ),
              StatCard(
                title: 'Synced Nodes',
                value: '${store.stats?.syncedNodes ?? 0}',
                icon: Icons.sync_outlined,
                iconColor: AdminColors.success,
                subtitle: 'of ${store.totalNodes}',
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatHashrate(double hashrate) {
    // Handle invalid values: NaN, Infinity, negative
    if (hashrate.isNaN || hashrate.isInfinite || hashrate < 0) {
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
}
