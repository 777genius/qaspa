// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'miner_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MinerConfig _$MinerConfigFromJson(Map<String, dynamic> json) => _MinerConfig(
  name: json['name'] as String?,
  targetNode: json['targetNode'] as String,
  payoutAddress: json['payoutAddress'] as String,
  threads: (json['threads'] as num?)?.toInt() ?? 1,
  targetBps: (json['targetBps'] as num?)?.toDouble(),
);

Map<String, dynamic> _$MinerConfigToJson(_MinerConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'targetNode': instance.targetNode,
      'payoutAddress': instance.payoutAddress,
      'threads': instance.threads,
      'targetBps': instance.targetBps,
    };
