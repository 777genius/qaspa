import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_spacing.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? AdminColors.surfaceDark
                    : AdminColors.sidebarLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark
                    ? AdminColors.textTertiaryDark
                    : AdminColors.textTertiaryLight,
                size: 40,
              ),
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AdminColors.textSecondaryDark
                          : AdminColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AdminSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
