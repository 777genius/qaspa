import '../entities/metrics_history.dart';

/// Repository for fetching metrics history
abstract class MetricsRepository {
  /// Fetches miner metrics history
  Future<MinerMetricsHistory> getMinerHistory(
    String minerId, {
    int? from,
    int? to,
    int limit = 100,
  });

  /// Fetches aggregate cluster metrics history
  Future<AggregateMetricsHistory> getAggregateHistory({
    int? from,
    int? to,
    int limit = 100,
  });
}
