import 'package:admin_design_system/admin_design_system.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/material.dart';

import '../styles/dag_colors.dart';

/// Tooltip showing block details on hover or selection
class DagBlockTooltip extends StatelessWidget {
  final DagBlock block;
  final Offset? position;

  const DagBlockTooltip({
    super.key,
    required this.block,
    this.position,
  });

  @override
  Widget build(BuildContext context) {
    final content = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow('Hash', block.hash.short),
            const SizedBox(height: 4),
            _buildRow('DAA Score', block.daaScore.value.toString()),
            const SizedBox(height: 4),
            _buildRow('Blue Score', block.blueScore.value.toString()),
            const SizedBox(height: 4),
            _buildRow('Parents', block.parentHashes.length.toString()),
            const SizedBox(height: 4),
            _buildStatusRow(block),
            const SizedBox(height: 4),
            _buildTypeRow(block),
          ],
        ),
      ),
    );

    // If position is provided, wrap in Positioned for hover tooltip
    if (position case final pos?) {
      return Positioned(
        left: pos.dx + 50,
        top: pos.dy - 20,
        child: content,
      );
    }

    // Otherwise return just the content for use in fixed panels
    return content;
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(DagBlock block) {
    final isBlue = block.isChainBlock;
    final statusColor = isBlue ? DagColors.chainBlock : DagColors.offChainBlock;
    final statusText = isBlue ? 'Chain (Blue)' : 'Off-chain (Red)';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Status: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeRow(DagBlock block) {
    final typeText = switch (block.blockType) {
      DagBlockType.sink => 'Sink',
      DagBlockType.tip => 'Tip',
      DagBlockType.virtual => 'Virtual',
      DagBlockType.regular => 'Regular',
    };
    final typeColor = DagColors.getBlockBorder(block);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Type: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          typeText,
          style: TextStyle(
            color: typeColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
