// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metrics_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MinerMetricsPoint _$MinerMetricsPointFromJson(Map<String, dynamic> json) =>
    _MinerMetricsPoint(
      timestamp: (json['timestamp'] as num).toInt(),
      hashrate: (json['hashrate'] as num).toDouble(),
      blocksFound: (json['blocksFound'] as num).toInt(),
    );

Map<String, dynamic> _$MinerMetricsPointToJson(_MinerMetricsPoint instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'hashrate': instance.hashrate,
      'blocksFound': instance.blocksFound,
    };

_MinerMetricsHistory _$MinerMetricsHistoryFromJson(Map<String, dynamic> json) =>
    _MinerMetricsHistory(
      data: (json['data'] as List<dynamic>)
          .map((e) => MinerMetricsPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MinerMetricsHistoryToJson(
  _MinerMetricsHistory instance,
) => <String, dynamic>{'data': instance.data};

_AggregateMetricsPoint _$AggregateMetricsPointFromJson(
  Map<String, dynamic> json,
) => _AggregateMetricsPoint(
  timestamp: (json['timestamp'] as num).toInt(),
  totalNodes: (json['totalNodes'] as num).toInt(),
  runningNodes: (json['runningNodes'] as num).toInt(),
  syncedNodes: (json['syncedNodes'] as num).toInt(),
  totalMiners: (json['totalMiners'] as num).toInt(),
  runningMiners: (json['runningMiners'] as num).toInt(),
  totalBlockCount: (json['totalBlockCount'] as num).toInt(),
  virtualDaaScore: (json['virtualDaaScore'] as num).toInt(),
  totalHashrate: (json['totalHashrate'] as num).toDouble(),
);

Map<String, dynamic> _$AggregateMetricsPointToJson(
  _AggregateMetricsPoint instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'totalNodes': instance.totalNodes,
  'runningNodes': instance.runningNodes,
  'syncedNodes': instance.syncedNodes,
  'totalMiners': instance.totalMiners,
  'runningMiners': instance.runningMiners,
  'totalBlockCount': instance.totalBlockCount,
  'virtualDaaScore': instance.virtualDaaScore,
  'totalHashrate': instance.totalHashrate,
};

_AggregateMetricsHistory _$AggregateMetricsHistoryFromJson(
  Map<String, dynamic> json,
) => _AggregateMetricsHistory(
  data: (json['data'] as List<dynamic>)
      .map((e) => AggregateMetricsPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AggregateMetricsHistoryToJson(
  _AggregateMetricsHistory instance,
) => <String, dynamic>{'data': instance.data};
