import 'package:flutter/material.dart';

import '../layout/block_position.dart';
import '../theme/dag_theme.dart';

/// Paints a single block on the canvas
/// Based on KGI BlockSprite.ts
class BlockPainter {
  final double blockSize;
  final Set<String> newBlockHashes;
  final String? hoveredBlockHash;
  final String? selectedBlockHash;

  BlockPainter({
    required this.blockSize,
    this.newBlockHashes = const {},
    this.hoveredBlockHash,
    this.selectedBlockHash,
  });

  /// Paint a block at the given position
  void paint(
    Canvas canvas,
    BlockPosition blockPos, {
    required Offset offset,
  }) {
    final block = blockPos.block;
    final isNew = newBlockHashes.contains(block.hash.value);
    final isHovered = hoveredBlockHash == block.hash.value;
    final isSelected = selectedBlockHash == block.hash.value;

    final position = blockPos.position + offset;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(position.dx, position.dy, blockSize, blockSize),
      Radius.circular(DagTheme.scale(DagTheme.blockRoundingRadius, blockSize)),
    );

    // Scale for hover effect
    final scale = isHovered ? DagTheme.blockScaleHover : DagTheme.blockScaleDefault;
    if (scale != 1.0) {
      canvas.save();
      final center = Offset(
        position.dx + blockSize / 2,
        position.dy + blockSize / 2,
      );
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      canvas.translate(-center.dx, -center.dy);
    }

    // Draw highlight frame for selected/hovered blocks
    if (isSelected || isHovered) {
      _drawHighlight(
        canvas,
        position,
        isChainBlock: block.isChainBlock,
        isNew: isNew,
        isFocus: isSelected,
      );
    }

    // Draw block background
    final fillPaint = Paint()
      ..color = DagBlockColors.getMainColor(
        isChainBlock: block.isChainBlock,
        isNew: isNew,
      )
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, fillPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = DagBlockColors.getBorderColor(
        isChainBlock: block.isChainBlock,
        isNew: isNew,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = DagTheme.scale(DagTheme.blockBorderWidth, blockSize);
    canvas.drawRRect(rect, borderPaint);

    // Draw hash text
    _drawHashText(
      canvas,
      position,
      block.hash.value,
      isChainBlock: block.isChainBlock,
      isNew: isNew,
    );

    if (scale != 1.0) {
      canvas.restore();
    }
  }

  /// Draw highlight frame around block
  void _drawHighlight(
    Canvas canvas,
    Offset position, {
    required bool isChainBlock,
    required bool isNew,
    required bool isFocus,
  }) {
    final highlightOffset = DagTheme.scale(
      isFocus ? 24.0 : 13.0,
      blockSize,
    );
    final highlightWidth = DagTheme.scale(
      isFocus ? 10.0 : 5.0,
      blockSize,
    );

    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - highlightOffset / 2,
        position.dy - highlightOffset / 2,
        blockSize + highlightOffset,
        blockSize + highlightOffset,
      ),
      Radius.circular(DagTheme.scale(
        DagTheme.blockRoundingRadius + highlightOffset / 2,
        blockSize,
      )),
    );

    final paint = Paint()
      ..color = DagBlockColors.getHighlightColor(
        isChainBlock: isChainBlock,
        isNew: isNew,
      ).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlightWidth;

    canvas.drawRRect(highlightRect, paint);
  }

  /// Draw hash text inside block
  void _drawHashText(
    Canvas canvas,
    Offset position,
    String hash, {
    required bool isChainBlock,
    required bool isNew,
  }) {
    // Calculate font size based on block size
    final nominalFontSize = blockSize * DagTheme.textSizeMultiplier * 2;
    final fontSize = nominalFontSize.clamp(DagTheme.minFontSize, DagTheme.maxFontSize);

    // Calculate number of text lines
    final textLines = _calculateTextLines(nominalFontSize);
    final lineLength = textLines * 2;
    final totalChars = lineLength * textLines;

    // Get last characters of hash
    final displayHash = hash.length >= totalChars
        ? hash.substring(hash.length - totalChars).toUpperCase()
        : hash.toUpperCase();

    // Split into lines
    final lines = <String>[];
    for (int i = 0; i < displayHash.length; i += lineLength) {
      final end = (i + lineLength).clamp(0, displayHash.length);
      lines.add(displayHash.substring(i, end));
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: lines.join('\n'),
        style: TextStyle(
          fontFamily: DagTheme.fontFamily,
          fontSize: fontSize / textLines,
          fontWeight: FontWeight.bold,
          color: DagBlockColors.getTextColor(
            isChainBlock: isChainBlock,
            isNew: isNew,
          ),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final textPosition = Offset(
      position.dx + (blockSize - textPainter.width) / 2,
      position.dy + (blockSize - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textPosition);
  }

  /// Calculate number of text lines based on font size
  int _calculateTextLines(double nominalFontSize) {
    if (nominalFontSize <= DagTheme.minFontSize - 2) {
      return ((nominalFontSize / DagTheme.minFontSize))
          .floor()
          .clamp(1, DagTheme.maxTextLines);
    } else {
      return ((nominalFontSize + 2) / DagTheme.maxFontSize)
          .ceil()
          .clamp(1, DagTheme.maxTextLines);
    }
  }
}
