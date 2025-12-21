import 'package:go_router/go_router.dart';

import '../pages/logs_page.dart';

abstract final class LogsRoutes {
  static const String logs = '/logs';

  static List<RouteBase> get routes => [
        GoRoute(
          path: logs,
          name: 'logs',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LogsPage(),
          ),
        ),
      ];
}
