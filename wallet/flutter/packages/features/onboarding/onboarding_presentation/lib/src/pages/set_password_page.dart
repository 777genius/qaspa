import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/password_input.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/security_warning_card.dart';
import '../widgets/step_indicator.dart';

/// Page for setting wallet password.
class SetPasswordPage extends StatelessWidget {
  /// Callback when password is set
  final VoidCallback onContinue;

  /// Callback when user wants to go back
  final VoidCallback onBack;

  const SetPasswordPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return OnboardingScaffold(
      title: 'Set Password',
      onBack: onBack,
      bottomActions: Observer(
        builder: (_) => SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: store.canProceedFromPassword
                ? () {
                    store.proceedToNextStep();
                    onContinue();
                  }
                : null,
            child: const Text('Continue'),
          ),
        ),
      ),
      child: Observer(
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepIndicator(
              currentStep: store.currentStepNumber,
              totalSteps: store.totalSteps,
            ),
            const SizedBox(height: AppSpacing.xl),
            SecurityWarningCard.passwordReminder(),
            const SizedBox(height: AppSpacing.lg),
            SetPasswordForm(
              password: store.password,
              confirmPassword: store.confirmPassword,
              onPasswordChanged: store.setPassword,
              onConfirmPasswordChanged: store.setConfirmPassword,
              passwordsMatch: store.passwordsMatch,
            ),
          ],
        ),
      ),
    );
  }
}

/// Password form with strength indicator.
class SetPasswordForm extends StatelessWidget {
  final String password;
  final String confirmPassword;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onConfirmPasswordChanged;
  final bool passwordsMatch;

  const SetPasswordForm({
    super.key,
    required this.password,
    required this.confirmPassword,
    required this.onPasswordChanged,
    required this.onConfirmPasswordChanged,
    required this.passwordsMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordInput(
          label: 'Password',
          hint: 'Enter a strong password',
          value: password,
          onChanged: onPasswordChanged,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.xs),
        PasswordStrengthIndicator(password: password),
        const SizedBox(height: AppSpacing.lg),
        PasswordInput(
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          value: confirmPassword,
          onChanged: onConfirmPasswordChanged,
          errorText: confirmPassword.isNotEmpty && !passwordsMatch
              ? 'Passwords do not match'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        PasswordRequirements(password: password),
      ],
    );
  }
}

/// List of password requirements.
class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final requirements = [
      (
        'At least 8 characters',
        password.length >= 8,
      ),
      (
        'Contains uppercase letter',
        password.contains(RegExp(r'[A-Z]')),
      ),
      (
        'Contains lowercase letter',
        password.contains(RegExp(r'[a-z]')),
      ),
      (
        'Contains number',
        password.contains(RegExp(r'[0-9]')),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...requirements.map((req) {
          final (label, isMet) = req;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxs),
            child: Row(
              children: [
                Icon(
                  isMet
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: isMet
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isMet
                        ? AppColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
