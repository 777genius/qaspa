import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_entry.freezed.dart';
part 'log_entry.g.dart';

/// Log level enum
enum LogLevel {
  trace,
  debug,
  info,
  warn,
  error,
}

/// Safe timestamp parsing with fallback to current time
DateTime _parseTimestamp(dynamic json) {
  if (json is DateTime) return json;
  if (json is String) {
    return DateTime.tryParse(json) ?? DateTime.now();
  }
  return DateTime.now();
}

/// Represents a log entry from a container
@freezed
sealed class LogEntry with _$LogEntry {
  const LogEntry._();

  const factory LogEntry({
    required String message,
    @JsonKey(fromJson: _parseTimestamp) required DateTime timestamp,
    @Default(LogLevel.info) LogLevel level,
    String? containerId,
    String? containerName,
  }) = _LogEntry;

  factory LogEntry.fromJson(Map<String, dynamic> json) => _$LogEntryFromJson(json);

  /// Parse log level from string
  static LogLevel parseLevel(String? level) {
    if (level == null) return LogLevel.info;
    return switch (level.toLowerCase()) {
      'trace' => LogLevel.trace,
      'debug' => LogLevel.debug,
      'info' => LogLevel.info,
      'warn' || 'warning' => LogLevel.warn,
      'error' || 'err' => LogLevel.error,
      _ => LogLevel.info,
    };
  }
}
