import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Text button for tertiary actions.
class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;

  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.iconSpacing),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}
