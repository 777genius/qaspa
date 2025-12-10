import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Empty state display for lists or screens.
class EmptyState extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_rounded,
    this.onAction,
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
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
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
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
