// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dag_block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DagBlock _$DagBlockFromJson(Map<String, dynamic> json) => _DagBlock(
  hash: BlockHash.fromJson(json['hash']),
  daaScore: DaaScore.fromJson(json['daaScore']),
  blueScore: BlueScore.fromJson(json['blueScore']),
  blueWork: BlueWork.fromJson(json['blueWork']),
  parentHashes: (json['parentHashes'] as List<dynamic>)
      .map(BlockHash.fromJson)
      .toList(),
  childrenHashes:
      (json['childrenHashes'] as List<dynamic>?)
          ?.map(BlockHash.fromJson)
          .toList() ??
      const [],
  selectedParentHash: json['selectedParentHash'] == null
      ? null
      : BlockHash.fromJson(json['selectedParentHash']),
  mergeSetBlues:
      (json['mergeSetBlues'] as List<dynamic>?)
          ?.map(BlockHash.fromJson)
          .toList() ??
      const [],
  mergeSetReds:
      (json['mergeSetReds'] as List<dynamic>?)
          ?.map(BlockHash.fromJson)
          .toList() ??
      const [],
  isChainBlock: json['isChainBlock'] as bool? ?? false,
  timestamp: DateTime.parse(json['timestamp'] as String),
  blockType:
      $enumDecodeNullable(_$DagBlockTypeEnumMap, json['blockType']) ??
      DagBlockType.regular,
);

Map<String, dynamic> _$DagBlockToJson(_DagBlock instance) => <String, dynamic>{
  'hash': instance.hash,
  'daaScore': instance.daaScore,
  'blueScore': instance.blueScore,
  'blueWork': instance.blueWork,
  'parentHashes': instance.parentHashes,
  'childrenHashes': instance.childrenHashes,
  'selectedParentHash': instance.selectedParentHash,
  'mergeSetBlues': instance.mergeSetBlues,
  'mergeSetReds': instance.mergeSetReds,
  'isChainBlock': instance.isChainBlock,
  'timestamp': instance.timestamp.toIso8601String(),
  'blockType': _$DagBlockTypeEnumMap[instance.blockType]!,
};

const _$DagBlockTypeEnumMap = {
  DagBlockType.regular: 'regular',
  DagBlockType.tip: 'tip',
  DagBlockType.sink: 'sink',
  DagBlockType.virtual: 'virtual',
};
