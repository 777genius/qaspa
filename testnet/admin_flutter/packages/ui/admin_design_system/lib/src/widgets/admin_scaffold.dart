import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_spacing.dart';
import 'sidebar_navigation.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<SidebarItem> sidebarItems;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<Widget>? actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.sidebarItems,
    required this.selectedIndex,
    required this.onItemSelected,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          SidebarNavigation(
            items: sidebarItems,
            selectedIndex: selectedIndex,
            onItemSelected: onItemSelected,
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, isDark),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AdminColors.surfaceDark : AdminColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AdminColors.borderDark : AdminColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
