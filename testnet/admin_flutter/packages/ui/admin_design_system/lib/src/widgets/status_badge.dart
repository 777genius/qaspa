import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_spacing.dart';

enum StatusType {
  running,
  starting,
  stopped,
  failed,
  syncing,
  success,
  warning,
  error,
  info,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType status;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.showDot = true,
  });

  factory StatusBadge.fromString(String statusString) {
    final status = switch (statusString.toLowerCase()) {
      'running' => StatusType.running,
      'starting' => StatusType.starting,
      'stopped' => StatusType.stopped,
      'failed' || 'error' => StatusType.failed,
      'syncing' => StatusType.syncing,
      'success' => StatusType.success,
      'warning' => StatusType.warning,
      'info' => StatusType.info,
      _ => StatusType.info,
    };
    return StatusBadge(label: statusString, status: status);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.badgePaddingH,
        vertical: AdminSpacing.badgePaddingV,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AdminSpacing.badgeRadius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AdminSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  _StatusColors _getColors() {
    return switch (status) {
      StatusType.running || StatusType.success => _StatusColors(
          background: AdminColors.success.withValues(alpha: 0.1),
          border: AdminColors.success.withValues(alpha: 0.2),
          text: AdminColors.success,
          dot: AdminColors.success,
        ),
      StatusType.starting ||
      StatusType.syncing ||
      StatusType.warning =>
        _StatusColors(
          background: AdminColors.warning.withValues(alpha: 0.1),
          border: AdminColors.warning.withValues(alpha: 0.2),
          text: AdminColors.warning,
          dot: AdminColors.warning,
        ),
      StatusType.stopped => _StatusColors(
          background: AdminColors.stopped.withValues(alpha: 0.1),
          border: AdminColors.stopped.withValues(alpha: 0.2),
          text: AdminColors.stopped,
          dot: AdminColors.stopped,
        ),
      StatusType.failed || StatusType.error => _StatusColors(
          background: AdminColors.error.withValues(alpha: 0.1),
          border: AdminColors.error.withValues(alpha: 0.2),
          text: AdminColors.error,
          dot: AdminColors.error,
        ),
      StatusType.info => _StatusColors(
          background: AdminColors.info.withValues(alpha: 0.1),
          border: AdminColors.info.withValues(alpha: 0.2),
          text: AdminColors.info,
          dot: AdminColors.info,
        ),
    };
  }
}

class _StatusColors {
  final Color background;
  final Color border;
  final Color text;
  final Color dot;

  const _StatusColors({
    required this.background,
    required this.border,
    required this.text,
    required this.dot,
  });
}
