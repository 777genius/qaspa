// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NodeConfig _$NodeConfigFromJson(Map<String, dynamic> json) => _NodeConfig(
  name: json['name'] as String?,
  role: json['role'] as String? ?? 'peer',
  connectTo: json['connectTo'] as String?,
  utxoindex: json['utxoindex'] as bool? ?? false,
);

Map<String, dynamic> _$NodeConfigToJson(_NodeConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'role': instance.role,
      'connectTo': instance.connectTo,
      'utxoindex': instance.utxoindex,
    };
