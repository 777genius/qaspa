// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cluster.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Cluster _$ClusterFromJson(Map<String, dynamic> json) => _Cluster(
  status: $enumDecode(_$ClusterStatusEnumMap, json['status']),
  nodeCount: (json['nodeCount'] as num).toInt(),
  minerCount: (json['minerCount'] as num).toInt(),
  txgenRunning: json['txgenRunning'] as bool,
  lastUpdated: DateTime.parse(json['lastUpdated'] as String),
);

Map<String, dynamic> _$ClusterToJson(_Cluster instance) => <String, dynamic>{
  'status': _$ClusterStatusEnumMap[instance.status]!,
  'nodeCount': instance.nodeCount,
  'minerCount': instance.minerCount,
  'txgenRunning': instance.txgenRunning,
  'lastUpdated': instance.lastUpdated.toIso8601String(),
};

const _$ClusterStatusEnumMap = {
  ClusterStatus.starting: 'starting',
  ClusterStatus.running: 'running',
  ClusterStatus.degraded: 'degraded',
  ClusterStatus.stopping: 'stopping',
  ClusterStatus.stopped: 'stopped',
};
