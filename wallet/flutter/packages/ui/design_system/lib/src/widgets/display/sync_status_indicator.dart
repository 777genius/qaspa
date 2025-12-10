import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';

/// Sync status indicator with progress.
class SyncStatusIndicator extends StatelessWidget {
  final SyncState state;
  final bool showDetails;

  const SyncStatusIndicator({
    super.key,
    required this.state,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(theme),
        if (showDetails) ...[
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              state.description,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getStatusColor(theme),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    if (state.isSynced) {
      return Icon(
        Icons.check_circle_rounded,
        size: 16,
        color: AppColors.success,
      );
    }

    final progress = state.progressPercent;
    if (progress != null) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 2,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: AppColors.warning,
        ),
      );
    }

    return Icon(
      Icons.sync_rounded,
      size: 16,
      color: AppColors.warning,
    );
  }

  Color _getStatusColor(ThemeData theme) {
    if (state.isSynced) return AppColors.success;
    return AppColors.warning;
  }
}
