// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NetworkInfo _$NetworkInfoFromJson(Map<String, dynamic> json) => _NetworkInfo(
  networkType: $enumDecode(_$NetworkTypeEnumMap, json['networkType']),
  addressPrefix: json['addressPrefix'] as String,
  defaultAddress: json['defaultAddress'] as String,
);

Map<String, dynamic> _$NetworkInfoToJson(_NetworkInfo instance) =>
    <String, dynamic>{
      'networkType': _$NetworkTypeEnumMap[instance.networkType]!,
      'addressPrefix': instance.addressPrefix,
      'defaultAddress': instance.defaultAddress,
    };

const _$NetworkTypeEnumMap = {
  NetworkType.mainnet: 'mainnet',
  NetworkType.testnet: 'testnet',
  NetworkType.devnet: 'devnet',
  NetworkType.simnet: 'simnet',
};
