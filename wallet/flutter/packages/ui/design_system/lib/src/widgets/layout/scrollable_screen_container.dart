import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Scrollable screen container with ListView.
class ScrollableScreenContainer extends StatelessWidget {
  final List<Widget> children;
  final bool useSafeArea;
  final EdgeInsets? padding;
  final ScrollController? controller;

  const ScrollableScreenContainer({
    super.key,
    required this.children,
    this.useSafeArea = true,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ListView(
      controller: controller,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
      children: children,
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}
