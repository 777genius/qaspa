// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dag_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DagInfoDto _$DagInfoDtoFromJson(Map<String, dynamic> json) => _DagInfoDto(
  tipHashes: (json['tip_hashes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  sinkHash: json['sink_hash'] as String,
  pruningPointHash: json['pruning_point_hash'] as String,
  virtualDaaScore: (json['virtual_daa_score'] as num).toInt(),
  blockCount: (json['block_count'] as num).toInt(),
  difficulty: (json['difficulty'] as num).toDouble(),
  pastMedianTime: (json['past_median_time'] as num?)?.toInt(),
  virtualParentHashes:
      (json['virtual_parent_hashes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$DagInfoDtoToJson(_DagInfoDto instance) =>
    <String, dynamic>{
      'tip_hashes': instance.tipHashes,
      'sink_hash': instance.sinkHash,
      'pruning_point_hash': instance.pruningPointHash,
      'virtual_daa_score': instance.virtualDaaScore,
      'block_count': instance.blockCount,
      'difficulty': instance.difficulty,
      'past_median_time': instance.pastMedianTime,
      'virtual_parent_hashes': instance.virtualParentHashes,
    };
