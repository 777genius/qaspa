import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Standard screen container with padding.
class ScreenContainer extends StatelessWidget {
  final Widget child;
  final bool useSafeArea;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const ScreenContainer({
    super.key,
    required this.child,
    this.useSafeArea = true,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
      child: child,
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    if (backgroundColor != null) {
      content = Container(
        color: backgroundColor,
        child: content,
      );
    }

    return content;
  }
}
