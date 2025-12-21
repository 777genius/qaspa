import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/material.dart';

import '../theme/dag_theme.dart';
import 'block_position.dart';

/// DAG layout calculator based on kaspa-graph-inspector TimelineContainer
/// Reference: https://github.com/kaspa-live/kaspa-graph-inspector/blob/master/web/src/dag/TimelineContainer.ts
class DagLayout {
  final double blockSize;
  final double marginX;
  final double marginY;

  DagLayout({
    this.blockSize = 60.0,
    double? marginX,
    double? marginY,
  })  : marginX = marginX ?? blockSize * DagTheme.marginXMultiplier,
        marginY = marginY ?? blockSize * DagTheme.minMarginYMultiplier;

  /// Calculate positions for all blocks
  /// Returns a map of hash -> BlockPosition for quick lookup
  DagLayoutResult calculate(Map<String, DagBlock> blocks) {
    if (blocks.isEmpty) {
      return DagLayoutResult.empty();
    }

    // Group blocks by DAA score
    final groups = _groupByDaaScore(blocks.values.toList());
    if (groups.isEmpty) {
      return DagLayoutResult.empty();
    }

    final positions = <String, BlockPosition>{};
    final sortedDaaScores = groups.keys.toList()..sort();

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    int columnIndex = 0;
    for (final daaScore in sortedDaaScores) {
      final group = groups[daaScore]!;
      final x = _calculateBlockX(columnIndex);
      columnIndex++;

      for (int i = 0; i < group.length; i++) {
        final y = _calculateCenteredY(i, group.length);
        final block = group[i];

        positions[block.hash.value] = BlockPosition(
          hash: block.hash.value,
          position: Offset(x, y),
          block: block,
          heightGroupIndex: i,
          heightGroupSize: group.length,
        );

        // Track bounds
        minX = minX < x ? minX : x;
        maxX = maxX > x + blockSize ? maxX : x + blockSize;
        minY = minY < y ? minY : y;
        maxY = maxY > y + blockSize ? maxY : y + blockSize;
      }
    }

    return DagLayoutResult(
      positions: positions,
      bounds: Rect.fromLTRB(minX, minY, maxX, maxY),
      blockSize: blockSize,
    );
  }

  /// Group blocks by DAA score
  Map<int, List<DagBlock>> _groupByDaaScore(List<DagBlock> blocks) {
    final groups = <int, List<DagBlock>>{};
    for (final block in blocks) {
      groups.putIfAbsent(block.daaScore.value, () => []).add(block);
    }

    // Sort each group by hash for consistent ordering
    for (final group in groups.values) {
      group.sort((a, b) => a.hash.value.compareTo(b.hash.value));
    }

    return groups;
  }

  /// Calculate X position based on height/DAA score index
  /// KGI formula: blockHeight * (blockSize + margin)
  double _calculateBlockX(int heightIndex) {
    return heightIndex * (blockSize + marginX);
  }

  /// Calculate Y position with zigzag centering from KGI
  /// KGI formula from TimelineContainer.ts:
  /// - Blocks are placed in zigzag pattern from center: 0, -1, 1, -2, 2, ...
  /// - First block in odd-sized groups is always centered (y=0)
  double _calculateCenteredY(int index, int groupSize) {
    if (groupSize == 1) {
      return 0;
    }

    // KGI: if (heightGroupIndex === 0 && heightGroupSize % 2 === 1) return 0
    if (index == 0 && groupSize.isOdd) {
      return 0;
    }

    // KGI formula from TimelineContainer.ts:
    // offsetGroupIndex = (heightGroupIndex * 2) + ((heightGroupSize - heightGroupIndex - 1) % 2)
    final offsetIndex = (index * 2) + ((groupSize - index - 1) % 2);

    // KGI: signMultiplier = heightGroupSize % 2 === 0 ? 1 : -1
    final signMultiplier = groupSize.isEven ? 1 : -1;

    // KGI: (-1) ** (offsetGroupIndex + 1) gives 1 if odd, -1 if even
    final baseSign = offsetIndex.isOdd ? 1 : -1;

    // KGI: Math.ceil(offsetGroupIndex / 2) - ceiling division
    final ceilDiv = (offsetIndex + 1) ~/ 2;

    // KGI: centeredIndex = ceil(offsetIndex/2) * baseSign * signMultiplier
    final centeredIndex = ceilDiv * baseSign * signMultiplier;

    return centeredIndex * (blockSize + marginY) / 2;
  }
}

/// Result of DAG layout calculation
class DagLayoutResult {
  final Map<String, BlockPosition> positions;
  final Rect bounds;
  final double blockSize;

  const DagLayoutResult({
    required this.positions,
    required this.bounds,
    required this.blockSize,
  });

  factory DagLayoutResult.empty() {
    return const DagLayoutResult(
      positions: {},
      bounds: Rect.zero,
      blockSize: 60.0,
    );
  }

  bool get isEmpty => positions.isEmpty;
  bool get isNotEmpty => positions.isNotEmpty;

  /// Get position by hash
  BlockPosition? operator [](String hash) => positions[hash];

  /// Get all positions as list
  List<BlockPosition> get positionsList => positions.values.toList();

  /// Canvas size with padding
  Size canvasSize({double padding = 100.0}) {
    if (isEmpty) return Size.zero;
    return Size(
      bounds.width + padding * 2,
      bounds.height + padding * 2,
    );
  }

  /// Offset to center the layout
  Offset centerOffset({double padding = 100.0}) {
    if (isEmpty) return Offset.zero;
    return Offset(
      -bounds.left + padding,
      -bounds.top + padding,
    );
  }
}
