// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dag_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DagState _$DagStateFromJson(Map<String, dynamic> json) => _DagState(
  tipHashes: (json['tipHashes'] as List<dynamic>)
      .map(BlockHash.fromJson)
      .toList(),
  sinkHash: BlockHash.fromJson(json['sinkHash']),
  pruningPointHash: BlockHash.fromJson(json['pruningPointHash']),
  virtualDaaScore: DaaScore.fromJson(json['virtualDaaScore']),
  blockCount: (json['blockCount'] as num).toInt(),
  difficulty: (json['difficulty'] as num).toDouble(),
  blocks:
      (json['blocks'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, DagBlock.fromJson(e as Map<String, dynamic>)),
      ) ??
      const {},
  virtualBlock: json['virtualBlock'] == null
      ? null
      : DagBlock.fromJson(json['virtualBlock'] as Map<String, dynamic>),
  isConnected: json['isConnected'] as bool? ?? false,
  isLoading: json['isLoading'] as bool? ?? false,
  error: json['error'] as String?,
);

Map<String, dynamic> _$DagStateToJson(_DagState instance) => <String, dynamic>{
  'tipHashes': instance.tipHashes,
  'sinkHash': instance.sinkHash,
  'pruningPointHash': instance.pruningPointHash,
  'virtualDaaScore': instance.virtualDaaScore,
  'blockCount': instance.blockCount,
  'difficulty': instance.difficulty,
  'blocks': instance.blocks,
  'virtualBlock': instance.virtualBlock,
  'isConnected': instance.isConnected,
  'isLoading': instance.isLoading,
  'error': instance.error,
};
