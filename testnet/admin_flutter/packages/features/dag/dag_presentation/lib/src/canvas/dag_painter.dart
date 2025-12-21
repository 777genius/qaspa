import 'package:flutter/material.dart';

import '../layout/dag_layout.dart';
import 'block_painter.dart';
import 'edge_painter.dart';

/// Main CustomPainter for the DAG visualization
/// Combines block and edge painting
class DagPainter extends CustomPainter {
  final DagLayoutResult layout;
  final Set<String> newBlockHashes;
  final String? hoveredBlockHash;
  final String? selectedBlockHash;
  final Offset panOffset;
  final double scale;

  DagPainter({
    required this.layout,
    this.newBlockHashes = const {},
    this.hoveredBlockHash,
    this.selectedBlockHash,
    this.panOffset = Offset.zero,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.isEmpty) return;

    // Apply transformations
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(scale);

    // Calculate offset to center the layout
    final offset = layout.centerOffset();

    // Draw background
    _drawBackground(canvas, size);

    // Draw edges first (below blocks)
    final edgePainter = EdgePainter(
      blockSize: layout.blockSize,
      selectedBlockHash: selectedBlockHash,
    );
    edgePainter.paintEdges(canvas, layout, offset: offset);

    // Draw blocks on top
    final blockPainter = BlockPainter(
      blockSize: layout.blockSize,
      newBlockHashes: newBlockHashes,
      hoveredBlockHash: hoveredBlockHash,
      selectedBlockHash: selectedBlockHash,
    );

    for (final blockPos in layout.positionsList) {
      blockPainter.paint(canvas, blockPos, offset: offset);
    }

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Background is handled by the widget container
  }

  @override
  bool shouldRepaint(DagPainter oldDelegate) {
    return layout != oldDelegate.layout ||
        newBlockHashes != oldDelegate.newBlockHashes ||
        hoveredBlockHash != oldDelegate.hoveredBlockHash ||
        selectedBlockHash != oldDelegate.selectedBlockHash ||
        panOffset != oldDelegate.panOffset ||
        scale != oldDelegate.scale;
  }

  @override
  bool? hitTest(Offset position) {
    // Convert position to layout coordinates
    final layoutPosition = (position - panOffset) / scale - layout.centerOffset();

    // Check if any block is hit
    for (final blockPos in layout.positionsList) {
      final blockRect = Rect.fromLTWH(
        blockPos.position.dx,
        blockPos.position.dy,
        layout.blockSize,
        layout.blockSize,
      );
      if (blockRect.contains(layoutPosition)) {
        return true;
      }
    }
    return false;
  }

  /// Find block at position (for hit testing)
  String? getBlockAtPosition(Offset position) {
    // Convert position to layout coordinates
    final layoutPosition = (position - panOffset) / scale - layout.centerOffset();

    for (final blockPos in layout.positionsList) {
      final blockRect = Rect.fromLTWH(
        blockPos.position.dx,
        blockPos.position.dy,
        layout.blockSize,
        layout.blockSize,
      );
      if (blockRect.contains(layoutPosition)) {
        return blockPos.hash;
      }
    }
    return null;
  }
}
