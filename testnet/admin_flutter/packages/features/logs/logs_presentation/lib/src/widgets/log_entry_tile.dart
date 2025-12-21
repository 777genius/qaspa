import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';

class LogEntryTile extends StatelessWidget {
  final LogEntry log;

  const LogEntryTile({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final levelColor = _getLevelColor(log.level);

    return Container(
      margin: const EdgeInsets.only(bottom: AdminSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AdminColors.cardDark.withValues(alpha: 0.5)
            : AdminColors.cardLight,
        borderRadius: BorderRadius.circular(AdminSpacing.xs),
        border: Border(
          left: BorderSide(
            color: levelColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              _formatTime(log.timestamp),
              style: AdminTypography.codeSmall.copyWith(
                color: isDark
                    ? AdminColors.textTertiaryDark
                    : AdminColors.textTertiaryLight,
              ),
            ),
          ),
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.xs,
              vertical: AdminSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AdminSpacing.xxs),
            ),
            child: Text(
              _getLevelLabel(log.level),
              style: AdminTypography.labelSmall.copyWith(
                color: levelColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Container(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              log.containerId ?? 'unknown',
              style: AdminTypography.codeSmall.copyWith(
                color: AdminColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: SelectableText(
              log.message,
              style: AdminTypography.code.copyWith(
                color: isDark
                    ? AdminColors.textPrimaryDark
                    : AdminColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    return switch (level) {
      LogLevel.trace => AdminColors.info.withValues(alpha: 0.5),
      LogLevel.debug => AdminColors.info,
      LogLevel.info => AdminColors.success,
      LogLevel.warn => AdminColors.warning,
      LogLevel.error => AdminColors.error,
    };
  }

  String _getLevelLabel(LogLevel level) {
    return switch (level) {
      LogLevel.trace => 'TRC',
      LogLevel.debug => 'DBG',
      LogLevel.info => 'INF',
      LogLevel.warn => 'WRN',
      LogLevel.error => 'ERR',
    };
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
