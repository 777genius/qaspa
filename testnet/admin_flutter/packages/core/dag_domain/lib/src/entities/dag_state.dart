import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/value_objects.dart';
import 'dag_block.dart';

part 'dag_state.freezed.dart';
part 'dag_state.g.dart';

/// Aggregate Root: represents the current state of the DAG
@freezed
sealed class DagState with _$DagState {
  const DagState._();

  const factory DagState({
    required List<BlockHash> tipHashes,
    required BlockHash sinkHash,
    required BlockHash pruningPointHash,
    required DaaScore virtualDaaScore,
    required int blockCount,
    required double difficulty,
    @Default({}) Map<String, DagBlock> blocks,
    DagBlock? virtualBlock,
    @Default(false) bool isConnected,
    @Default(false) bool isLoading,
    String? error,
  }) = _DagState;

  /// Factory for initial empty state
  factory DagState.initial() => DagState(
        tipHashes: const [],
        sinkHash: BlockHash.empty,
        pruningPointHash: BlockHash.empty,
        virtualDaaScore: DaaScore.zero,
        blockCount: 0,
        difficulty: 0,
      );

  /// Get a block by its hash
  DagBlock? getBlock(BlockHash hash) => blocks[hash.value];

  /// Get all tip blocks
  List<DagBlock> get tips => tipHashes
      .where((h) => blocks.containsKey(h.value))
      .map((h) => blocks[h.value]!)
      .toList();

  /// Get the sink block
  DagBlock? get sink => sinkHash.isNotEmpty ? blocks[sinkHash.value] : null;

  /// Get blocks sorted by DAA score (descending - newest first)
  List<DagBlock> get sortedBlocks {
    final list = blocks.values.toList();
    list.sort((a, b) => b.daaScore.value.compareTo(a.daaScore.value));
    return list;
  }

  /// Get blocks sorted by DAA score (ascending - oldest first)
  List<DagBlock> get sortedBlocksAscending {
    final list = blocks.values.toList();
    list.sort((a, b) => a.daaScore.value.compareTo(b.daaScore.value));
    return list;
  }

  /// Get chain blocks (blue blocks in consensus)
  List<DagBlock> get chainBlocks =>
      blocks.values.where((b) => b.isChainBlock).toList();

  /// Get off-chain blocks (red blocks)
  List<DagBlock> get offChainBlocks =>
      blocks.values.where((b) => b.isRed).toList();

  /// Check if has error
  bool get hasError => error != null;

  /// Minimum DAA score in the current block set
  DaaScore? get minDaaScore {
    if (blocks.isEmpty) return null;
    return blocks.values
        .map((b) => b.daaScore)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Maximum DAA score in the current block set
  DaaScore? get maxDaaScore {
    if (blocks.isEmpty) return null;
    return blocks.values
        .map((b) => b.daaScore)
        .reduce((a, b) => a > b ? a : b);
  }

  factory DagState.fromJson(Map<String, dynamic> json) =>
      _$DagStateFromJson(json);
}
