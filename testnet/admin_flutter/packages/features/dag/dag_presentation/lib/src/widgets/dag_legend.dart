import 'package:flutter/material.dart';

import '../styles/dag_colors.dart';

/// Legend showing block type colors
class DagLegend extends StatelessWidget {
  const DagLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _LegendItem(
            color: DagColors.chainBlock,
            label: 'Chain Block (Blue)',
          ),
          const SizedBox(height: 4),
          _LegendItem(
            color: DagColors.offChainBlock,
            label: 'Off-chain (Red)',
          ),
          const SizedBox(height: 4),
          _LegendItem(
            color: DagColors.sink,
            label: 'Sink',
          ),
          const SizedBox(height: 4),
          _LegendItem(
            color: DagColors.tip,
            label: 'Tip',
          ),
          const SizedBox(height: 4),
          _LegendItem(
            color: DagColors.virtualBlock,
            label: 'Virtual',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
