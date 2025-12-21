import 'package:go_router/go_router.dart';

import '../pages/miners_page.dart';

abstract final class MinersRoutes {
  static const String miners = '/miners';

  static List<RouteBase> get routes => [
        GoRoute(
          path: miners,
          name: 'miners',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MinersPage(),
          ),
        ),
      ];
}
