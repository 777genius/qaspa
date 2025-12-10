import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Row with multiple action buttons.
class ActionRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;
  final double spacing;

  const ActionRow({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.center,
    this.spacing = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
