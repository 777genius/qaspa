// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cluster_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClusterStats _$ClusterStatsFromJson(Map<String, dynamic> json) =>
    _ClusterStats(
      totalNodes: (json['totalNodes'] as num).toInt(),
      runningNodes: (json['runningNodes'] as num).toInt(),
      syncedNodes: (json['syncedNodes'] as num).toInt(),
      totalMiners: (json['totalMiners'] as num).toInt(),
      runningMiners: (json['runningMiners'] as num).toInt(),
      totalBlockCount: (json['totalBlockCount'] as num).toInt(),
      virtualDaaScore: (json['virtualDaaScore'] as num).toInt(),
      totalPeers: (json['totalPeers'] as num).toInt(),
      totalMempoolSize: (json['totalMempoolSize'] as num).toInt(),
      totalHashrate: (json['totalHashrate'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$ClusterStatsToJson(_ClusterStats instance) =>
    <String, dynamic>{
      'totalNodes': instance.totalNodes,
      'runningNodes': instance.runningNodes,
      'syncedNodes': instance.syncedNodes,
      'totalMiners': instance.totalMiners,
      'runningMiners': instance.runningMiners,
      'totalBlockCount': instance.totalBlockCount,
      'virtualDaaScore': instance.virtualDaaScore,
      'totalPeers': instance.totalPeers,
      'totalMempoolSize': instance.totalMempoolSize,
      'totalHashrate': instance.totalHashrate,
      'timestamp': instance.timestamp.toIso8601String(),
    };
