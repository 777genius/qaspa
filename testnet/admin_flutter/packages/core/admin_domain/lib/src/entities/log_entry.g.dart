// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LogEntry _$LogEntryFromJson(Map<String, dynamic> json) => _LogEntry(
  message: json['message'] as String,
  timestamp: _parseTimestamp(json['timestamp']),
  level: $enumDecodeNullable(_$LogLevelEnumMap, json['level']) ?? LogLevel.info,
  containerId: json['containerId'] as String?,
  containerName: json['containerName'] as String?,
);

Map<String, dynamic> _$LogEntryToJson(_LogEntry instance) => <String, dynamic>{
  'message': instance.message,
  'timestamp': instance.timestamp.toIso8601String(),
  'level': _$LogLevelEnumMap[instance.level]!,
  'containerId': instance.containerId,
  'containerName': instance.containerName,
};

const _$LogLevelEnumMap = {
  LogLevel.trace: 'trace',
  LogLevel.debug: 'debug',
  LogLevel.info: 'info',
  LogLevel.warn: 'warn',
  LogLevel.error: 'error',
};
