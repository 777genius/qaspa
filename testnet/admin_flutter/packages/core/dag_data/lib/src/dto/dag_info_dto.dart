import 'package:freezed_annotation/freezed_annotation.dart';

part 'dag_info_dto.freezed.dart';
part 'dag_info_dto.g.dart';

/// DTO for DAG info from GetBlockDagInfo API
@freezed
sealed class DagInfoDto with _$DagInfoDto {
  const DagInfoDto._();

  const factory DagInfoDto({
    @JsonKey(name: 'tip_hashes') required List<String> tipHashes,
    @JsonKey(name: 'sink_hash') required String sinkHash,
    @JsonKey(name: 'pruning_point_hash') required String pruningPointHash,
    @JsonKey(name: 'virtual_daa_score') required int virtualDaaScore,
    @JsonKey(name: 'block_count') required int blockCount,
    required double difficulty,
    @JsonKey(name: 'past_median_time') int? pastMedianTime,
    @JsonKey(name: 'virtual_parent_hashes') @Default([]) List<String> virtualParentHashes,
  }) = _DagInfoDto;

  factory DagInfoDto.fromJson(Map<String, dynamic> json) =>
      _$DagInfoDtoFromJson(json);
}
