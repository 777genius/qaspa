import 'dart:math' as math;

import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/material.dart';

import '../../styles/dag_colors.dart';

/// Compact DAG block node widget (40x40px with 2-char hash)
class DagBlockNode extends StatelessWidget {
  /// Safely get first 2 chars of hash, handling short strings
  static String _getHashPrefix(String hash) {
    final len = math.min(2, hash.length);
    return len > 0 ? hash.substring(0, len).toUpperCase() : '??';
  }

  final DagBlock block;
  final bool isNew;
  final bool isHovered;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onHover;
  final VoidCallback? onHoverExit;

  const DagBlockNode({
    super.key,
    required this.block,
    this.isNew = false,
    this.isHovered = false,
    this.isSelected = false,
    this.onTap,
    this.onHover,
    this.onHoverExit,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = DagColors.getBlockBorder(block);
    final textColor = DagColors.getBlockText(block);

    return MouseRegion(
      onEnter: (_) => onHover?.call(),
      onExit: (_) => onHoverExit?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          transform: isHovered
              ? (Matrix4.identity()..scaleByDouble(1.1, 1.1, 1.0, 1.0))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            // Opaque background to hide edges behind blocks
            color: DagColors.getBlockBackground(block),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Colors.white : borderColor,
              width: isSelected || isHovered ? 2 : 1,
            ),
            boxShadow: isHovered || isSelected
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              _getHashPrefix(block.hash.short),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
