import 'package:flutter/material.dart';

import '../layout/block_position.dart';
import '../layout/dag_layout.dart';
import '../theme/dag_theme.dart';

/// Paints edges (connections) between blocks
/// Based on KGI EdgeSprite.ts
class EdgePainter {
  final double blockSize;
  final String? selectedBlockHash;

  EdgePainter({
    required this.blockSize,
    this.selectedBlockHash,
  });

  /// Paint all edges for the DAG
  void paintEdges(
    Canvas canvas,
    DagLayoutResult layout, {
    required Offset offset,
  }) {
    // First pass: draw normal edges (and edges to missing parents)
    for (final blockPos in layout.positionsList) {
      for (final parentHash in blockPos.block.parentHashes) {
        final parentPos = layout[parentHash.value];

        if (parentPos == null) {
          // Parent not loaded - draw line going left to indicate missing parent
          _paintEdgeToMissing(canvas, to: blockPos, offset: offset);
          continue;
        }

        final isVirtualChain =
            blockPos.block.selectedParentHash?.value == parentHash.value;
        final isHighlighted = selectedBlockHash == blockPos.hash ||
            selectedBlockHash == parentHash.value;

        if (!isVirtualChain && !isHighlighted) {
          _paintEdge(
            canvas,
            from: parentPos,
            to: blockPos,
            offset: offset,
            isVirtualChain: false,
            isHighlighted: false,
          );
        }
      }
    }

    // Second pass: draw virtual chain edges (on top)
    for (final blockPos in layout.positionsList) {
      final selectedParentHash = blockPos.block.selectedParentHash?.value;
      if (selectedParentHash == null) continue;

      final parentPos = layout[selectedParentHash];
      if (parentPos == null) continue;

      final isHighlighted = selectedBlockHash == blockPos.hash ||
          selectedBlockHash == selectedParentHash;

      _paintEdge(
        canvas,
        from: parentPos,
        to: blockPos,
        offset: offset,
        isVirtualChain: true,
        isHighlighted: isHighlighted,
      );
    }

    // Third pass: draw highlighted edges (on very top)
    if (selectedBlockHash != null) {
      final selectedPos = layout[selectedBlockHash!];
      if (selectedPos != null) {
        // Draw edges to parents
        for (final parentHash in selectedPos.block.parentHashes) {
          final parentPos = layout[parentHash.value];
          if (parentPos == null) continue;

          final isVirtualChain =
              selectedPos.block.selectedParentHash?.value == parentHash.value;

          _paintEdge(
            canvas,
            from: parentPos,
            to: selectedPos,
            offset: offset,
            isVirtualChain: isVirtualChain,
            isHighlighted: true,
            isChildEdge: false, // This is a parent edge
          );
        }

        // Draw edges to children
        for (final childHash in selectedPos.block.childrenHashes) {
          final childPos = layout[childHash.value];
          if (childPos == null) continue;

          final isVirtualChain =
              childPos.block.selectedParentHash?.value == selectedBlockHash;

          _paintEdge(
            canvas,
            from: selectedPos,
            to: childPos,
            offset: offset,
            isVirtualChain: isVirtualChain,
            isHighlighted: true,
            isChildEdge: true, // This is a child edge
          );
        }
      }
    }
  }

  /// Paint a single edge (straight line like KGI)
  void _paintEdge(
    Canvas canvas, {
    required BlockPosition from,
    required BlockPosition to,
    required Offset offset,
    required bool isVirtualChain,
    required bool isHighlighted,
    bool isChildEdge = true,
  }) {
    final fromPoint = from.rightEdge(blockSize) + offset;
    final toPoint = to.leftEdge(blockSize) + offset;

    // Get edge style
    final color = _getEdgeColor(isVirtualChain, isHighlighted);
    final lineWidth = _getEdgeWidth(isVirtualChain, isHighlighted);
    final arrowRadius = _getArrowRadius(isVirtualChain, isHighlighted);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    // KGI uses straight lines, not bezier curves
    canvas.drawLine(fromPoint, toPoint, paint);

    // Draw arrow at the end
    _drawArrow(canvas, toPoint, arrowRadius, color);

    // KGI: Draw highlight mark on highlighted edges
    if (isHighlighted) {
      _drawHighlightMark(canvas, fromPoint, toPoint, color, isChildEdge);
    }
  }

  /// Paint edge to a missing parent (not loaded in current view)
  /// Draws a fading line going left to indicate the block has parents outside the view
  void _paintEdgeToMissing(
    Canvas canvas, {
    required BlockPosition to,
    required Offset offset,
  }) {
    final toPoint = to.leftEdge(blockSize) + offset;
    // Line extends left by 2 block sizes
    final fromPoint = Offset(toPoint.dx - blockSize * 2, toPoint.dy);

    final paint = Paint()
      ..color = DagEdgeColors.normal.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = DagTheme.normalEdgeWidth
      ..strokeCap = StrokeCap.round;

    // Draw straight line (no bezier needed for simple fade-out)
    canvas.drawLine(fromPoint, toPoint, paint);

    // Draw arrow at the block
    _drawArrow(canvas, toPoint, DagTheme.normalArrowRadius, paint.color);
  }

  /// Draw arrow head at the edge end (triangle like KGI)
  void _drawArrow(
    Canvas canvas,
    Offset point,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // KGI uses triangular arrow pointing left (toward the block)
    final path = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(point.dx + radius * 1.5, point.dy - radius)
      ..lineTo(point.dx + radius * 1.5, point.dy + radius)
      ..close();

    canvas.drawPath(path, paint);
  }

  /// Draw highlight mark on the edge (KGI feature)
  /// Shows a circular mark along the edge to indicate parent/child relationship
  void _drawHighlightMark(
    Canvas canvas,
    Offset fromPoint,
    Offset toPoint,
    Color color,
    bool isChildEdge,
  ) {
    // KGI formula: markOffsetX = (blockSize + margin) / 2
    // For simplicity, position mark at 25% or 75% along the edge
    final t = isChildEdge ? 0.75 : 0.25;

    // Calculate point along bezier curve (approximation using linear interpolation)
    final markX = fromPoint.dx + (toPoint.dx - fromPoint.dx) * t;
    final markY = fromPoint.dy + (toPoint.dy - fromPoint.dy) * t;

    final markRadius = DagTheme.scale(6.0, blockSize);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(markX, markY), markRadius, paint);
  }

  /// Get edge color based on type
  Color _getEdgeColor(bool isVirtualChain, bool isHighlighted) {
    if (isHighlighted) {
      return isVirtualChain
          ? DagEdgeColors.virtualChain
          : DagEdgeColors.highlightedSelected;
    }
    return isVirtualChain ? DagEdgeColors.virtualChain : DagEdgeColors.normal;
  }

  /// Get edge line width based on type
  double _getEdgeWidth(bool isVirtualChain, bool isHighlighted) {
    if (isHighlighted) {
      return isVirtualChain ? 10.0 : 8.0;
    }
    return isVirtualChain
        ? DagTheme.virtualChainEdgeWidth
        : DagTheme.normalEdgeWidth;
  }

  /// Get arrow radius based on type
  double _getArrowRadius(bool isVirtualChain, bool isHighlighted) {
    if (isHighlighted) {
      return isVirtualChain ? 11.0 : 10.0;
    }
    return isVirtualChain
        ? DagTheme.virtualChainArrowRadius
        : DagTheme.normalArrowRadius;
  }
}
