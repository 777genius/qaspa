import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Bottom action bar for screens with safe area handling.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const BottomActionBar({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.screenHorizontal),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: child,
      ),
    );
  }
}
