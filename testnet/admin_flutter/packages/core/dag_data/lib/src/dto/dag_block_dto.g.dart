// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dag_block_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DagBlockDto _$DagBlockDtoFromJson(Map<String, dynamic> json) => _DagBlockDto(
  hash: json['hash'] as String,
  daaScore: (json['daa_score'] as num).toInt(),
  blueScore: (json['blue_score'] as num).toInt(),
  blueWork: json['blue_work'] as String,
  parentHashes: (json['parent_hashes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  childrenHashes:
      (json['children_hashes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  selectedParentHash: json['selected_parent_hash'] as String?,
  mergeSetBlues:
      (json['merge_set_blues'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  mergeSetReds:
      (json['merge_set_reds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  isChainBlock: json['is_chain_block'] as bool? ?? false,
  timestampMs: (json['timestamp'] as num).toInt(),
  blockType: json['block_type'] as String? ?? 'regular',
);

Map<String, dynamic> _$DagBlockDtoToJson(_DagBlockDto instance) =>
    <String, dynamic>{
      'hash': instance.hash,
      'daa_score': instance.daaScore,
      'blue_score': instance.blueScore,
      'blue_work': instance.blueWork,
      'parent_hashes': instance.parentHashes,
      'children_hashes': instance.childrenHashes,
      'selected_parent_hash': instance.selectedParentHash,
      'merge_set_blues': instance.mergeSetBlues,
      'merge_set_reds': instance.mergeSetReds,
      'is_chain_block': instance.isChainBlock,
      'timestamp': instance.timestampMs,
      'block_type': instance.blockType,
    };
