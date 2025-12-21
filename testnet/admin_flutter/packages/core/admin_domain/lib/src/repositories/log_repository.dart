import '../entities/log_entry.dart';

/// Repository interface for log operations
abstract interface class LogRepository {
  /// Get historical logs
  Future<List<LogEntry>> getLogs({
    String? containerId,
    LogLevel? minLevel,
    DateTime? since,
    int limit = 100,
  });

  /// Watch logs in real-time
  Stream<LogEntry> watchLogs({
    String? containerId,
    LogLevel? minLevel,
  });

  /// Get list of container IDs for log filtering
  Future<List<String>> getContainerIds();
}
