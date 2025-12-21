import 'package:freezed_annotation/freezed_annotation.dart';

part 'cluster_stats.freezed.dart';
part 'cluster_stats.g.dart';

/// Aggregated cluster statistics
@freezed
sealed class ClusterStats with _$ClusterStats {
  const ClusterStats._();

  const factory ClusterStats({
    required int totalNodes,
    required int runningNodes,
    required int syncedNodes,
    required int totalMiners,
    required int runningMiners,
    required int totalBlockCount,
    required int virtualDaaScore,
    required int totalPeers,
    required int totalMempoolSize,
    required double totalHashrate,
    required DateTime timestamp,
  }) = _ClusterStats;

  factory ClusterStats.fromJson(Map<String, dynamic> json) => _$ClusterStatsFromJson(json);

  factory ClusterStats.empty() => ClusterStats(
        totalNodes: 0,
        runningNodes: 0,
        syncedNodes: 0,
        totalMiners: 0,
        runningMiners: 0,
        totalBlockCount: 0,
        virtualDaaScore: 0,
        totalPeers: 0,
        totalMempoolSize: 0,
        totalHashrate: 0,
        timestamp: DateTime.now(),
      );

  double get nodeHealthPercent =>
      totalNodes > 0 ? (runningNodes / totalNodes) * 100 : 0;

  double get minerHealthPercent =>
      totalMiners > 0 ? (runningMiners / totalMiners) * 100 : 0;

  String get hashrateFormatted {
    if (totalHashrate >= 1e9) {
      return '${(totalHashrate / 1e9).toStringAsFixed(2)} GH/s';
    } else if (totalHashrate >= 1e6) {
      return '${(totalHashrate / 1e6).toStringAsFixed(2)} MH/s';
    } else if (totalHashrate >= 1e3) {
      return '${(totalHashrate / 1e3).toStringAsFixed(2)} KH/s';
    } else {
      return '${totalHashrate.toStringAsFixed(2)} H/s';
    }
  }
}
