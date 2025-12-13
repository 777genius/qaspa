import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'quick_action_button.dart';

/// Row of quick action buttons.
class QuickActionsRow extends StatelessWidget {
  final VoidCallback? onSendTap;
  final VoidCallback? onReceiveTap;
  final VoidCallback? onHistoryTap;

  const QuickActionsRow({
    super.key,
    this.onSendTap,
    this.onReceiveTap,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionButton(
            icon: Icons.arrow_upward_rounded,
            label: 'Send',
            onTap: onSendTap ?? () {},
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Receive',
            onTap: onReceiveTap ?? () {},
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.history_rounded,
            label: 'History',
            onTap: onHistoryTap ?? () {},
          ),
        ),
      ],
    );
  }
}
