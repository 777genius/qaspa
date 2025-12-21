import 'package:get_it/get_it.dart';
import 'package:nodes_domain/nodes_domain.dart';
import 'package:nodes_presentation/src/stores/nodes_store.dart';

/// Configure Nodes presentation dependencies (stores)
/// Note: Use cases must be registered before calling this (in nodes_domain)
GetIt configureNodesPresentationDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<NodesStore>(
    () => NodesStore(
      getIt<GetNodesUseCase>(),
      getIt<WatchNodesUseCase>(),
      getIt<AddNodeUseCase>(),
      getIt<RemoveNodeUseCase>(),
      getIt<StartNodeUseCase>(),
      getIt<StopNodeUseCase>(),
      getIt<RestartNodeUseCase>(),
    ),
  );

  return getIt;
}
