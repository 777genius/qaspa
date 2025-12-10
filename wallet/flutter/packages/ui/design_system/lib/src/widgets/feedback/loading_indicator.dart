import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// Loading indicator with optional message.
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full screen loading overlay.
class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      child: LoadingIndicator(message: message),
    );
  }
}
