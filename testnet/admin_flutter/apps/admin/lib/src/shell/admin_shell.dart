import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dashboard_presentation/dashboard_presentation.dart';
import 'package:nodes_presentation/nodes_presentation.dart';
import 'package:miners_presentation/miners_presentation.dart';
import 'package:logs_presentation/logs_presentation.dart';
import 'package:dag_presentation/dag_presentation.dart';

import '../stores/theme_store.dart';

class AdminShell extends StatefulWidget {
  final Widget child;

  const AdminShell({
    super.key,
    required this.child,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  static const _routes = [
    DashboardRoutes.dashboard,
    NodesRoutes.nodes,
    MinersRoutes.miners,
    LogsRoutes.logs,
    DagRoutes.dag,
  ];

  static const _sidebarItems = [
    SidebarItem(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
    ),
    SidebarItem(
      icon: Icons.dns_outlined,
      label: 'Nodes',
    ),
    SidebarItem(
      icon: Icons.memory_outlined,
      label: 'Miners',
    ),
    SidebarItem(
      icon: Icons.article_outlined,
      label: 'Logs',
    ),
    SidebarItem(
      icon: Icons.account_tree_outlined,
      label: 'DAG',
    ),
  ];

  static const _titles = [
    'Dashboard',
    'Nodes',
    'Miners',
    'Logs',
    'DAG Visualization',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final location = GoRouterState.of(context).uri.path;
    // Find the best matching route (longest match wins to avoid '/' matching everything)
    int bestIndex = 0;
    int bestLength = 0;
    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (location.startsWith(route) && route.length > bestLength) {
        bestIndex = i;
        bestLength = route.length;
      }
    }
    if (bestIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = bestIndex;
      });
    }
  }

  void _onItemSelected(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      context.go(_routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: _titles[_selectedIndex],
      sidebarItems: _sidebarItems,
      selectedIndex: _selectedIndex,
      onItemSelected: _onItemSelected,
      body: widget.child,
      actions: [
        IconButton(
          onPressed: () => themeStore.toggleTheme(context),
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          tooltip: 'Toggle theme',
        ),
      ],
    );
  }
}
