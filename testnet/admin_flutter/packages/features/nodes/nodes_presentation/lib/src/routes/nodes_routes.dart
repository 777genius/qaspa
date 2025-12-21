import 'package:go_router/go_router.dart';

import '../pages/nodes_page.dart';

abstract final class NodesRoutes {
  static const String nodes = '/nodes';

  static List<RouteBase> get routes => [
        GoRoute(
          path: nodes,
          name: 'nodes',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NodesPage(),
          ),
        ),
      ];
}
