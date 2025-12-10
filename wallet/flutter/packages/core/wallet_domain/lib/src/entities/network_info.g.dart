// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NetworkInfo _$NetworkInfoFromJson(Map<String, dynamic> json) => _NetworkInfo(
      networkId:
          const NetworkIdConverter().fromJson(json['networkId'] as String),
      blockCount: (json['blockCount'] as num).toInt(),
      headerCount: (json['headerCount'] as num).toInt(),
      daaScore: (json['daaScore'] as num).toInt(),
      difficulty: (json['difficulty'] as num).toInt(),
      nodeVersion: json['nodeVersion'] as String,
      isSynced: json['isSynced'] as bool,
      peerCount: (json['peerCount'] as num?)?.toInt(),
      mempoolSize: (json['mempoolSize'] as num?)?.toInt(),
    );

Map<String, dynamic> _$NetworkInfoToJson(_NetworkInfo instance) =>
    <String, dynamic>{
      'networkId': const NetworkIdConverter().toJson(instance.networkId),
      'blockCount': instance.blockCount,
      'headerCount': instance.headerCount,
      'daaScore': instance.daaScore,
      'difficulty': instance.difficulty,
      'nodeVersion': instance.nodeVersion,
      'isSynced': instance.isSynced,
      'peerCount': instance.peerCount,
      'mempoolSize': instance.mempoolSize,
    };
