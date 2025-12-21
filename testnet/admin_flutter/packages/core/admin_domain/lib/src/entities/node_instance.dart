import 'package:freezed_annotation/freezed_annotation.dart';

part 'node_instance.freezed.dart';
part 'node_instance.g.dart';

/// Node status enum
enum NodeStatus {
  creating,
  starting,
  running,
  stopping,
  stopped,
  error,
}

/// Node metrics
@freezed
sealed class NodeMetrics with _$NodeMetrics {
  const NodeMetrics._();

  const factory NodeMetrics({
    required int blockCount,
    required int headerCount,
    required int virtualDaaScore,
    required int peerCount,
    required int mempoolSize,
    required bool isSynced,
  }) = _NodeMetrics;

  factory NodeMetrics.fromJson(Map<String, dynamic> json) => _$NodeMetricsFromJson(json);

  factory NodeMetrics.empty() => const NodeMetrics(
        blockCount: 0,
        headerCount: 0,
        virtualDaaScore: 0,
        peerCount: 0,
        mempoolSize: 0,
        isSynced: false,
      );
}

/// Represents a kaspad node instance
@freezed
sealed class NodeInstance with _$NodeInstance {
  const NodeInstance._();

  const factory NodeInstance({
    required String id,
    required String name,
    required String role,
    required String status,
    required int p2pPort,
    required int grpcPort,
    NodeMetrics? metrics,
  }) = _NodeInstance;

  factory NodeInstance.fromJson(Map<String, dynamic> json) => _$NodeInstanceFromJson(json);

  bool get isRunning => status == 'running';
  bool get isSeed => role == 'seed';
  bool get isPeer => role == 'peer';
  bool get isSynced => metrics?.isSynced ?? false;
}
