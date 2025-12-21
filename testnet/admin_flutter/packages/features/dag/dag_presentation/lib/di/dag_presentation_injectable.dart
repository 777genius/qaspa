import 'package:dag_domain/dag_domain.dart';
import 'package:dag_presentation/src/stores/dag_store.dart';
import 'package:get_it/get_it.dart';
import 'package:nodes_domain/nodes_domain.dart';

/// Configure DAG presentation dependencies (stores)
/// Note: Use cases must be registered before calling this (in dag_domain and nodes_domain)
GetIt configureDagPresentationDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<DagStore>(
    () => DagStore(
      getIt<GetDagStateUseCase>(),
      getIt<WatchDagUpdatesUseCase>(),
      getIt<ConnectToNodeUseCase>(),
      getIt<GetNodesUseCase>(),
    ),
  );

  return getIt;
}
