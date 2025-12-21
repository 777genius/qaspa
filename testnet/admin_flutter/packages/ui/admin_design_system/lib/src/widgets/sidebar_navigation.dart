import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_spacing.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String? badge;

  const SidebarItem({
    required this.icon,
    required this.label,
    this.badge,
  });
}

class SidebarNavigation extends StatelessWidget {
  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool collapsed;

  const SidebarNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: collapsed
          ? AdminSpacing.sidebarCollapsedWidth
          : AdminSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AdminColors.sidebarDark : AdminColors.sidebarLight,
        border: Border(
          right: BorderSide(
            color: isDark ? AdminColors.borderDark : AdminColors.borderLight,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildLogo(context, isDark),
          const SizedBox(height: AdminSpacing.md),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminSpacing.sm,
                vertical: AdminSpacing.xs,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildItem(context, index, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context, bool isDark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AdminColors.borderDark : AdminColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hub,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: AdminSpacing.sm),
            Flexible(
              child: Text(
                'Qaspa Testnet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, bool isDark) {
    final item = items[index];
    final isSelected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(index),
          borderRadius: BorderRadius.circular(AdminSpacing.sm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AdminSpacing.sm,
              vertical: collapsed ? AdminSpacing.sm : AdminSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? AdminColors.sidebarActiveDark
                      : AdminColors.sidebarActiveLight)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AdminSpacing.sm),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? AdminColors.primary
                      : (isDark
                          ? AdminColors.textSecondaryDark
                          : AdminColors.textSecondaryLight),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? AdminColors.primary
                                : (isDark
                                    ? AdminColors.textSecondaryDark
                                    : AdminColors.textSecondaryLight),
                          ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.xs,
                        vertical: AdminSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.badge!,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
