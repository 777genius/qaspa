import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Warning card for security-related messages.
class SecurityWarningCard extends StatelessWidget {
  /// Warning title
  final String title;

  /// Warning message
  final String message;

  /// Type of warning (affects color)
  final SecurityWarningType type;

  /// Optional icon override
  final IconData? icon;

  const SecurityWarningCard({
    super.key,
    required this.title,
    required this.message,
    this.type = SecurityWarningType.warning,
    this.icon,
  });

  static Widget seedPhraseBackup() {
    return const SecurityWarningCard(
      title: 'Keep your seed phrase safe',
      message:
          'Your seed phrase is the only way to recover your wallet. '
          'Never share it with anyone and store it in a secure location.',
      type: SecurityWarningType.critical,
      icon: Icons.security_rounded,
    );
  }

  static Widget passwordReminder() {
    return const SecurityWarningCard(
      title: 'Remember your password',
      message:
          'Your password encrypts your wallet. If you forget it, '
          'you can recover using your seed phrase.',
      type: SecurityWarningType.info,
      icon: Icons.lock_rounded,
    );
  }

  static Widget testnetWarning() {
    return const SecurityWarningCard(
      title: 'Testnet coins have no value',
      message:
          'Testnet is for development and testing only. '
          'Coins on testnet cannot be converted to mainnet KAS.',
      type: SecurityWarningType.warning,
      icon: Icons.science_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors(type);

    return Semantics(
      label: 'Warning: $title. $message',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: AppRadii.borderRadiusMd,
          border: Border.all(
            color: colors.border,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              decoration: BoxDecoration(
                color: colors.iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon ?? _getDefaultIcon(type),
                color: colors.iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxs),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDefaultIcon(SecurityWarningType type) {
    return switch (type) {
      SecurityWarningType.info => Icons.info_outline_rounded,
      SecurityWarningType.warning => Icons.warning_amber_rounded,
      SecurityWarningType.critical => Icons.error_outline_rounded,
    };
  }

  _WarningColors _getColors(SecurityWarningType type) {
    return switch (type) {
      SecurityWarningType.info => _WarningColors(
          background: AppColors.secondary.withValues(alpha: 0.1),
          border: AppColors.secondary.withValues(alpha: 0.3),
          iconBackground: AppColors.secondary.withValues(alpha: 0.2),
          iconColor: AppColors.secondaryDark,
          textColor: AppColors.secondaryDark,
        ),
      SecurityWarningType.warning => _WarningColors(
          background: AppColors.warning.withValues(alpha: 0.1),
          border: AppColors.warning.withValues(alpha: 0.3),
          iconBackground: AppColors.warning.withValues(alpha: 0.2),
          iconColor: AppColors.onWarning,
          textColor: AppColors.onWarning,
        ),
      SecurityWarningType.critical => _WarningColors(
          background: AppColors.error.withValues(alpha: 0.1),
          border: AppColors.error.withValues(alpha: 0.3),
          iconBackground: AppColors.error.withValues(alpha: 0.2),
          iconColor: AppColors.error,
          textColor: AppColors.error,
        ),
    };
  }
}

/// Types of security warnings.
enum SecurityWarningType {
  /// Informational, low priority
  info,

  /// Warning, medium priority
  warning,

  /// Critical, high priority
  critical,
}

class _WarningColors {
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final Color textColor;

  const _WarningColors({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.textColor,
  });
}
