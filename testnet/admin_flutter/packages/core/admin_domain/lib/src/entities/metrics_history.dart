import 'package:freezed_annotation/freezed_annotation.dart';

part 'metrics_history.freezed.dart';
part 'metrics_history.g.dart';

/// A single point in miner metrics history
@freezed
sealed class MinerMetricsPoint with _$MinerMetricsPoint {
  const MinerMetricsPoint._();

  const factory MinerMetricsPoint({
    required int timestamp,
    required double hashrate,
    required int blocksFound,
  }) = _MinerMetricsPoint;

  factory MinerMetricsPoint.fromJson(Map<String, dynamic> json) =>
      _$MinerMetricsPointFromJson(json);

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

/// Response containing miner metrics history
@freezed
sealed class MinerMetricsHistory with _$MinerMetricsHistory {
  const MinerMetricsHistory._();

  const factory MinerMetricsHistory({
    required List<MinerMetricsPoint> data,
  }) = _MinerMetricsHistory;

  factory MinerMetricsHistory.fromJson(Map<String, dynamic> json) =>
      _$MinerMetricsHistoryFromJson(json);
}

/// A single point in aggregate metrics history
@freezed
sealed class AggregateMetricsPoint with _$AggregateMetricsPoint {
  const AggregateMetricsPoint._();

  const factory AggregateMetricsPoint({
    required int timestamp,
    required int totalNodes,
    required int runningNodes,
    required int syncedNodes,
    required int totalMiners,
    required int runningMiners,
    required int totalBlockCount,
    required int virtualDaaScore,
    required double totalHashrate,
  }) = _AggregateMetricsPoint;

  factory AggregateMetricsPoint.fromJson(Map<String, dynamic> json) =>
      _$AggregateMetricsPointFromJson(json);

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

/// Response containing aggregate metrics history
@freezed
sealed class AggregateMetricsHistory with _$AggregateMetricsHistory {
  const AggregateMetricsHistory._();

  const factory AggregateMetricsHistory({
    required List<AggregateMetricsPoint> data,
  }) = _AggregateMetricsHistory;

  factory AggregateMetricsHistory.fromJson(Map<String, dynamic> json) =>
      _$AggregateMetricsHistoryFromJson(json);
}
