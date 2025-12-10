import 'package:flutter/material.dart';

import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';

/// Success message display.
class SuccessMessage extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onDone;
  final String? actionLabel;

  const SuccessMessage({
    super.key,
    required this.message,
    this.title,
    this.onDone,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 40,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onDone != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onDone,
                child: Text(actionLabel ?? 'Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
