import 'package:go_router/go_router.dart';

import '../pages/dashboard_page.dart';

abstract final class DashboardRoutes {
  static const String dashboard = '/';

  static List<RouteBase> get routes => [
        GoRoute(
          path: dashboard,
          name: 'dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardPage(),
          ),
        ),
      ];
}
