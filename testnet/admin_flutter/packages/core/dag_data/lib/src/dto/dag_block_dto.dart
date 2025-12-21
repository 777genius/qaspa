import 'package:freezed_annotation/freezed_annotation.dart';

part 'dag_block_dto.freezed.dart';
part 'dag_block_dto.g.dart';

/// DTO for block data from API
@freezed
sealed class DagBlockDto with _$DagBlockDto {
  const DagBlockDto._();

  const factory DagBlockDto({
    required String hash,
    @JsonKey(name: 'daa_score') required int daaScore,
    @JsonKey(name: 'blue_score') required int blueScore,
    @JsonKey(name: 'blue_work') required String blueWork,
    @JsonKey(name: 'parent_hashes') required List<String> parentHashes,
    @JsonKey(name: 'children_hashes') @Default([]) List<String> childrenHashes,
    @JsonKey(name: 'selected_parent_hash') String? selectedParentHash,
    @JsonKey(name: 'merge_set_blues') @Default([]) List<String> mergeSetBlues,
    @JsonKey(name: 'merge_set_reds') @Default([]) List<String> mergeSetReds,
    @JsonKey(name: 'is_chain_block') @Default(false) bool isChainBlock,
    @JsonKey(name: 'timestamp') required int timestampMs,
    @JsonKey(name: 'block_type') @Default('regular') String blockType,
  }) = _DagBlockDto;

  factory DagBlockDto.fromJson(Map<String, dynamic> json) =>
      _$DagBlockDtoFromJson(json);
}
