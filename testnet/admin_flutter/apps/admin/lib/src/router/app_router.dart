import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dashboard_presentation/dashboard_presentation.dart';
import 'package:nodes_presentation/nodes_presentation.dart';
import 'package:miners_presentation/miners_presentation.dart';
import 'package:logs_presentation/logs_presentation.dart';
import 'package:dag_presentation/dag_presentation.dart';

import '../shell/admin_shell.dart';

final appRouter = GoRouter(
  initialLocation: DashboardRoutes.dashboard,
  debugLogDiagnostics: true,
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Route Error: ${state.error}'),
          Text('Path: ${state.uri.path}'),
          Text('Full URI: ${state.uri}'),
        ],
      ),
    ),
  ),
  routes: [
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        ...DashboardRoutes.routes,
        ...NodesRoutes.routes,
        ...MinersRoutes.routes,
        ...LogsRoutes.routes,
        ...DagRoutes.routes,
      ],
    ),
  ],
);
