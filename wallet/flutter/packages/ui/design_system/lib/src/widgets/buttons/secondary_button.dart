import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Secondary action button with outlined style.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: _buildChild(context),
    );

    final wrappedButton = Semantics(
      button: true,
      enabled: !isLoading && onPressed != null,
      label: isLoading ? '$label, loading' : label,
      child: button,
    );

    if (isExpanded) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: wrappedButton,
      );
    }

    return wrappedButton;
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.iconSpacing),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}
