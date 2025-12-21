import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/value_objects.dart';

part 'dag_block.freezed.dart';
part 'dag_block.g.dart';

/// Type of block in the DAG
enum DagBlockType {
  /// Regular block in the DAG
  regular,

  /// Tip block (leaf node without children)
  tip,

  /// Sink block (selected parent of virtual block)
  sink,

  /// Virtual block (conceptual block at the top of DAG)
  virtual,
}

/// Represents a block in the BlockDAG
@freezed
sealed class DagBlock with _$DagBlock {
  const DagBlock._();

  const factory DagBlock({
    required BlockHash hash,
    required DaaScore daaScore,
    required BlueScore blueScore,
    required BlueWork blueWork,
    required List<BlockHash> parentHashes,
    @Default([]) List<BlockHash> childrenHashes,
    BlockHash? selectedParentHash,
    @Default([]) List<BlockHash> mergeSetBlues,
    @Default([]) List<BlockHash> mergeSetReds,
    @Default(false) bool isChainBlock,
    required DateTime timestamp,
    @Default(DagBlockType.regular) DagBlockType blockType,
  }) = _DagBlock;

  /// Check if this block is a tip (leaf without children)
  bool get isTip => childrenHashes.isEmpty && blockType != DagBlockType.virtual;

  /// Check if this block is the sink
  bool get isSink => blockType == DagBlockType.sink;

  /// Check if this block is virtual
  bool get isVirtual => blockType == DagBlockType.virtual;

  /// Check if this block is in the main chain (blue)
  bool get isBlue => isChainBlock;

  /// Check if this block is off-chain (red)
  bool get isRed => !isChainBlock && !isVirtual;

  /// Check if this block has parents
  bool get hasParents => parentHashes.isNotEmpty;

  /// Check if this block has children
  bool get hasChildren => childrenHashes.isNotEmpty;

  /// Number of parents
  int get parentCount => parentHashes.length;

  /// Number of children
  int get childCount => childrenHashes.length;

  /// Check if this block is selected parent of another block
  bool isSelectedParentOf(DagBlock child) =>
      child.selectedParentHash == hash;

  factory DagBlock.fromJson(Map<String, dynamic> json) =>
      _$DagBlockFromJson(json);
}
