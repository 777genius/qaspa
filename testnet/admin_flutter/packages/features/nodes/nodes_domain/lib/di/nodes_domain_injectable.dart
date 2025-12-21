import 'package:admin_domain/admin_domain.dart';
import 'package:get_it/get_it.dart';
import 'package:nodes_domain/src/use_cases/add_node_use_case.dart';
import 'package:nodes_domain/src/use_cases/get_nodes_use_case.dart';
import 'package:nodes_domain/src/use_cases/remove_node_use_case.dart';
import 'package:nodes_domain/src/use_cases/restart_node_use_case.dart';
import 'package:nodes_domain/src/use_cases/start_node_use_case.dart';
import 'package:nodes_domain/src/use_cases/stop_node_use_case.dart';
import 'package:nodes_domain/src/use_cases/watch_nodes_use_case.dart';

/// Configure Nodes domain dependencies (use cases)
/// Note: NodeRepository must be registered before calling this (in admin_data)
GetIt configureNodesDomainDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<GetNodesUseCase>(
    () => GetNodesUseCase(getIt<NodeRepository>()),
  );
  getIt.registerLazySingleton<WatchNodesUseCase>(
    () => WatchNodesUseCase(getIt<NodeRepository>()),
  );
  getIt.registerLazySingleton<AddNodeUseCase>(
    () => AddNodeUseCase(getIt<NodeRepository>()),
  );
  getIt.registerLazySingleton<RemoveNodeUseCase>(
    () => RemoveNodeUseCase(getIt<NodeRepository>()),
  );
  getIt.registerLazySingleton<StartNodeUseCase>(
    () => StartNodeUseCase(getIt<NodeRepository>()),
  );
  getIt.registerLazySingleton<StopNodeUseCase>(
    () => StopNodeUseCase(getIt<NodeRepository>()),
  );
  getIt.registerLazySingleton<RestartNodeUseCase>(
    () => RestartNodeUseCase(getIt<NodeRepository>()),
  );

  return getIt;
}
