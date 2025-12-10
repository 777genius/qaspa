import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/radii.dart';

/// Icon button for quick actions (send, receive, etc).
class IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.primaryContainer;
    final fgColor = iconColor ?? theme.colorScheme.onPrimaryContainer;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bgColor,
            borderRadius: AppRadii.borderRadiusLg,
            child: InkWell(
              onTap: onPressed,
              borderRadius: AppRadii.borderRadiusLg,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  icon,
                  color: fgColor,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action buttons row (Send, Receive, etc).
class ActionButtonRow extends StatelessWidget {
  final VoidCallback? onSend;
  final VoidCallback? onReceive;
  final VoidCallback? onScan;

  const ActionButtonRow({
    super.key,
    this.onSend,
    this.onReceive,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconActionButton(
          icon: Icons.arrow_upward_rounded,
          label: 'Send',
          onPressed: onSend,
          backgroundColor: AppColors.primaryContainer,
          iconColor: AppColors.onPrimaryContainer,
        ),
        IconActionButton(
          icon: Icons.arrow_downward_rounded,
          label: 'Receive',
          onPressed: onReceive,
          backgroundColor: AppColors.secondaryContainer,
          iconColor: AppColors.onSecondaryContainer,
        ),
        if (onScan != null)
          IconActionButton(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan',
            onPressed: onScan,
          ),
      ],
    );
  }
}
