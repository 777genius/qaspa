// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'miner_instance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MinerInstance _$MinerInstanceFromJson(Map<String, dynamic> json) =>
    _MinerInstance(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      targetNode: json['targetNode'] as String,
      hashrate: (json['hashrate'] as num).toDouble(),
      blocksFound: (json['blocksFound'] as num).toInt(),
    );

Map<String, dynamic> _$MinerInstanceToJson(_MinerInstance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'status': instance.status,
      'targetNode': instance.targetNode,
      'hashrate': instance.hashrate,
      'blocksFound': instance.blocksFound,
    };
