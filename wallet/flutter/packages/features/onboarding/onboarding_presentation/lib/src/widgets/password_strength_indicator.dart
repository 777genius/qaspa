import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Visual indicator of password strength.
class PasswordStrengthIndicator extends StatelessWidget {
  /// The password to evaluate
  final String password;

  /// Minimum required length
  final int minLength;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.minLength = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = _calculateStrength(password);

    return Semantics(
      label: 'Password strength: ${strength.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: PasswordStrengthBar(
                  strength: strength,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                strength.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: strength.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (password.isNotEmpty && password.length < minLength) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Minimum $minLength characters',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  PasswordStrength _calculateStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    if (password.length < minLength) return PasswordStrength.weak;

    var score = 0;

    // Length bonus
    if (password.length >= 12) score += 2;
    else if (password.length >= 10) score += 1;

    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.fair;
    if (score <= 5) return PasswordStrength.good;
    return PasswordStrength.strong;
  }
}

/// Password strength bar showing progress.
class PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthBar({
    super.key,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: List.generate(4, (index) {
        final isActive = index < strength.level;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: isActive
                  ? strength.color
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// Password strength levels.
enum PasswordStrength {
  none(0, 'Enter password', AppColors.outlineLight),
  weak(1, 'Weak', AppColors.error),
  fair(2, 'Fair', AppColors.warning),
  good(3, 'Good', AppColors.primaryDark),
  strong(4, 'Strong', AppColors.success);

  final int level;
  final String label;
  final Color color;

  const PasswordStrength(this.level, this.label, this.color);
}
