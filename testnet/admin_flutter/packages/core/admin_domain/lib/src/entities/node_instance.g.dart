// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node_instance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NodeMetrics _$NodeMetricsFromJson(Map<String, dynamic> json) => _NodeMetrics(
  blockCount: (json['blockCount'] as num).toInt(),
  headerCount: (json['headerCount'] as num).toInt(),
  virtualDaaScore: (json['virtualDaaScore'] as num).toInt(),
  peerCount: (json['peerCount'] as num).toInt(),
  mempoolSize: (json['mempoolSize'] as num).toInt(),
  isSynced: json['isSynced'] as bool,
);

Map<String, dynamic> _$NodeMetricsToJson(_NodeMetrics instance) =>
    <String, dynamic>{
      'blockCount': instance.blockCount,
      'headerCount': instance.headerCount,
      'virtualDaaScore': instance.virtualDaaScore,
      'peerCount': instance.peerCount,
      'mempoolSize': instance.mempoolSize,
      'isSynced': instance.isSynced,
    };

_NodeInstance _$NodeInstanceFromJson(Map<String, dynamic> json) =>
    _NodeInstance(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      p2pPort: (json['p2pPort'] as num).toInt(),
      grpcPort: (json['grpcPort'] as num).toInt(),
      metrics: json['metrics'] == null
          ? null
          : NodeMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$NodeInstanceToJson(_NodeInstance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': instance.role,
      'status': instance.status,
      'p2pPort': instance.p2pPort,
      'grpcPort': instance.grpcPort,
      'metrics': instance.metrics,
    };
