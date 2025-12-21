import 'package:dag_data/src/dto/dag_info_dto.dart';
import 'package:dag_data/src/mappers/dag_block_mapper.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:injectable/injectable.dart';

/// Mapper for converting DagInfoDto to DagState entity
@lazySingleton
class DagStateMapper {
  final DagBlockMapper _blockMapper;

  DagStateMapper(DagBlockMapper blockMapper) : _blockMapper = blockMapper;

  /// Convert DagInfoDto to DagState (without blocks)
  DagState fromDto(DagInfoDto dto) {
    return DagState(
      tipHashes: dto.tipHashes.map((s) => BlockHash(s)).toList(),
      sinkHash: BlockHash(dto.sinkHash),
      pruningPointHash: BlockHash(dto.pruningPointHash),
      virtualDaaScore: DaaScore(dto.virtualDaaScore),
      blockCount: dto.blockCount,
      difficulty: dto.difficulty,
    );
  }

  /// Convert JSON to DagState
  DagState fromJson(Map<String, dynamic> json) {
    final dto = DagInfoDto.fromJson(json);
    return fromDto(dto);
  }

  /// Update DagState with new blocks
  DagState withBlocks(DagState state, List<DagBlock> blocks) {
    final blocksMap = <String, DagBlock>{};
    for (final block in blocks) {
      blocksMap[block.hash.value] = block;
    }
    return state.copyWith(blocks: blocksMap);
  }

  /// Create virtual block from tips
  DagBlock createVirtualBlock(List<BlockHash> tipHashes, DaaScore virtualDaaScore) {
    return DagBlock(
      hash: const BlockHash('virtual'),
      daaScore: virtualDaaScore,
      blueScore: const BlueScore(0),
      blueWork: const BlueWork('0'),
      parentHashes: tipHashes,
      timestamp: DateTime.now(),
      blockType: DagBlockType.virtual,
    );
  }

  DagBlockMapper get blockMapper => _blockMapper;
}
