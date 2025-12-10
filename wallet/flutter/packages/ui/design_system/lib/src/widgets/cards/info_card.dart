import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/radii.dart';

/// Information card for tips, warnings, or errors.
enum InfoCardType { info, warning, error, success }

class InfoCard extends StatelessWidget {
  final String message;
  final String? title;
  final InfoCardType type;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const InfoCard({
    super.key,
    required this.message,
    this.title,
    this.type = InfoCardType.info,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.borderRadiusMd,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(colors.icon, color: colors.iconColor, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxs),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textColor.withValues(alpha: 0.8),
                  ),
                ),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: colors.iconColor,
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: colors.iconColor,
            ),
        ],
      ),
    );
  }

  _InfoCardColors _getColors() {
    return switch (type) {
      InfoCardType.info => _InfoCardColors(
          background: AppColors.secondary.withValues(alpha: 0.1),
          border: AppColors.secondary.withValues(alpha: 0.3),
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.secondary,
          textColor: AppColors.secondaryDark,
        ),
      InfoCardType.warning => _InfoCardColors(
          background: AppColors.warning.withValues(alpha: 0.1),
          border: AppColors.warning.withValues(alpha: 0.3),
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.warning,
          textColor: AppColors.onWarning,
        ),
      InfoCardType.error => _InfoCardColors(
          background: AppColors.error.withValues(alpha: 0.1),
          border: AppColors.error.withValues(alpha: 0.3),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          textColor: AppColors.onErrorContainer,
        ),
      InfoCardType.success => _InfoCardColors(
          background: AppColors.success.withValues(alpha: 0.1),
          border: AppColors.success.withValues(alpha: 0.3),
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppColors.success,
          textColor: AppColors.onSuccess,
        ),
    };
  }
}

class _InfoCardColors {
  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final Color textColor;

  const _InfoCardColors({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });
}
