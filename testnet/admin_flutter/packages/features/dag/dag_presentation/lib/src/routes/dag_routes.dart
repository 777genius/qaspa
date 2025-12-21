import 'package:go_router/go_router.dart';

import '../pages/dag_page.dart';

/// DAG feature routes
class DagRoutes {
  static const String dag = '/dag';
  static const String dagWithNode = '/dag/:nodeId';

  static List<GoRoute> routes = [
    GoRoute(
      path: dag,
      builder: (context, state) => const DagPage(),
    ),
    GoRoute(
      path: dagWithNode,
      builder: (context, state) {
        final nodeId = state.pathParameters['nodeId'];
        return DagPage(initialNodeId: nodeId);
      },
    ),
  ];
}
