import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_spacing.dart';
import 'animated_value_text.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget? trailing;
  final bool animateValue;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.animateValue = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ?? AdminColors.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.sm + 4,
          vertical: AdminSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AdminSpacing.sm),
              ),
              child: Icon(
                icon,
                color: effectiveIconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AdminColors.textSecondaryDark
                              : AdminColors.textSecondaryLight,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (animateValue)
                        AnimatedValueText(
                          value: value,
                          highlightColor: effectiveIconColor,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        )
                      else
                        Text(
                          value,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(width: AdminSpacing.xs),
                        AnimatedValueText(
                          value: subtitle!,
                          highlightColor: effectiveIconColor,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AdminColors.textTertiaryDark
                                        : AdminColors.textTertiaryLight,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class StatCardRow extends StatelessWidget {
  final List<StatCard> cards;

  const StatCardRow({
    super.key,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    // Guard against empty cards list to prevent division by zero
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardCount = cards.length;
        final spacing = AdminSpacing.md;
        final totalSpacing = spacing * (cardCount - 1);
        final cardWidth = (constraints.maxWidth - totalSpacing) / cardCount;

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              SizedBox(
                width: cardWidth,
                child: cards[i],
              ),
            ],
          ],
        );
      },
    );
  }
}
