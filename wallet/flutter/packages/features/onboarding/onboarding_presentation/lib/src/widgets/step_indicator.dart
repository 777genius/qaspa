import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Visual step indicator showing progress through onboarding.
///
/// Displays current step and total steps (e.g., "2 of 4").
class StepIndicator extends StatelessWidget {
  /// Current step (1-based)
  final int currentStep;

  /// Total number of steps
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Step $currentStep of $totalSteps',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Step $currentStep',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' of $totalSteps',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          StepProgressBar(
            currentStep: currentStep,
            totalSteps: totalSteps,
          ),
        ],
      ),
    );
  }
}

/// Horizontal progress bar showing step completion.
class StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep - 1;
        final isCurrent = index == currentStep - 1;

        return Padding(
          padding: EdgeInsets.only(
            right: index < totalSteps - 1 ? AppSpacing.xxs : 0,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCurrent ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted || isCurrent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
