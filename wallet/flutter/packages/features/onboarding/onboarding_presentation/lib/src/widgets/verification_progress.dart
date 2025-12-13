import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Progress indicator for verification.
class VerificationProgress extends StatelessWidget {
  final int current;
  final int total;

  const VerificationProgress({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          current < total
              ? 'Select word ${current + 1} of $total'
              : 'Verification Complete',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (index) {
            final isComplete = index < current;
            final isCurrent = index == current;

            return Container(
              width: 12,
              height: 12,
              margin: EdgeInsets.only(right: index < total - 1 ? 8 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isComplete
                    ? AppColors.success
                    : isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
              ),
              child: isComplete
                  ? const Icon(
                      Icons.check,
                      size: 8,
                      color: Colors.white,
                    )
                  : null,
            );
          }),
        ),
      ],
    );
  }
}
