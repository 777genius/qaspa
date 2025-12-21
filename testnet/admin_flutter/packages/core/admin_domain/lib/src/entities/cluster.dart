import 'package:freezed_annotation/freezed_annotation.dart';

part 'cluster.freezed.dart';
part 'cluster.g.dart';

/// Cluster status enum
enum ClusterStatus {
  starting,
  running,
  degraded,
  stopping,
  stopped,
}

/// Represents the testnet cluster state
@freezed
sealed class Cluster with _$Cluster {
  const Cluster._();

  const factory Cluster({
    required ClusterStatus status,
    required int nodeCount,
    required int minerCount,
    required bool txgenRunning,
    required DateTime lastUpdated,
  }) = _Cluster;

  factory Cluster.fromJson(Map<String, dynamic> json) => _$ClusterFromJson(json);

  factory Cluster.initial() => Cluster(
        status: ClusterStatus.stopped,
        nodeCount: 0,
        minerCount: 0,
        txgenRunning: false,
        lastUpdated: DateTime.now(),
      );

  bool get isHealthy => status == ClusterStatus.running;
  bool get isRunning => status == ClusterStatus.running || status == ClusterStatus.degraded;
}
