// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_chain_changed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VirtualChainChanged _$VirtualChainChangedFromJson(Map<String, dynamic> json) =>
    _VirtualChainChanged(
      removedHashes: (json['removedHashes'] as List<dynamic>)
          .map(BlockHash.fromJson)
          .toList(),
      addedHashes: (json['addedHashes'] as List<dynamic>)
          .map(BlockHash.fromJson)
          .toList(),
    );

Map<String, dynamic> _$VirtualChainChangedToJson(
  _VirtualChainChanged instance,
) => <String, dynamic>{
  'removedHashes': instance.removedHashes,
  'addedHashes': instance.addedHashes,
};
