import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/material.dart';

/// Position and metadata for a block in the DAG visualization
/// Based on KGI BlockSprite position calculation
class BlockPosition {
  final String hash;
  final Offset position;
  final DagBlock block;
  final int heightGroupIndex;
  final int heightGroupSize;

  const BlockPosition({
    required this.hash,
    required this.position,
    required this.block,
    required this.heightGroupIndex,
    required this.heightGroupSize,
  });

  /// Get the center position of the block
  Offset center(double blockSize) {
    return Offset(
      position.dx + blockSize / 2,
      position.dy + blockSize / 2,
    );
  }

  /// Get the right edge center (for outgoing edges)
  Offset rightEdge(double blockSize) {
    return Offset(
      position.dx + blockSize,
      position.dy + blockSize / 2,
    );
  }

  /// Get the left edge center (for incoming edges)
  Offset leftEdge(double blockSize) {
    return Offset(
      position.dx,
      position.dy + blockSize / 2,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockPosition && other.hash == hash;
  }

  @override
  int get hashCode => hash.hashCode;
}
