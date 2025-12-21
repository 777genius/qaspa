import 'package:dag_data/src/dto/dag_block_dto.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:injectable/injectable.dart';

/// Mapper for converting DagBlockDto to DagBlock entity
/// Anti-corruption layer: isolates domain from API changes
@lazySingleton
class DagBlockMapper {
  const DagBlockMapper();

  /// Convert DTO to domain entity
  DagBlock fromDto(DagBlockDto dto) {
    return DagBlock(
      hash: BlockHash(dto.hash),
      daaScore: DaaScore(dto.daaScore),
      blueScore: BlueScore(dto.blueScore),
      blueWork: BlueWork(dto.blueWork),
      parentHashes: dto.parentHashes.map((s) => BlockHash(s)).toList(),
      childrenHashes: dto.childrenHashes.map((s) => BlockHash(s)).toList(),
      selectedParentHash:
          dto.selectedParentHash != null ? BlockHash(dto.selectedParentHash!) : null,
      mergeSetBlues: dto.mergeSetBlues.map((s) => BlockHash(s)).toList(),
      mergeSetReds: dto.mergeSetReds.map((s) => BlockHash(s)).toList(),
      isChainBlock: dto.isChainBlock,
      timestamp: DateTime.fromMillisecondsSinceEpoch(dto.timestampMs),
      blockType: _parseBlockType(dto.blockType),
    );
  }

  /// Convert JSON to domain entity (via DTO)
  DagBlock fromJson(Map<String, dynamic> json) {
    final dto = DagBlockDto.fromJson(json);
    return fromDto(dto);
  }

  /// Parse block type from string
  DagBlockType _parseBlockType(String type) {
    return switch (type.toLowerCase()) {
      'tip' => DagBlockType.tip,
      'sink' => DagBlockType.sink,
      'virtual' => DagBlockType.virtual,
      _ => DagBlockType.regular,
    };
  }
}
