import 'package:get_it/get_it.dart';

import '../src/repositories/dag_reader.dart';
import '../src/repositories/dag_repository.dart';
import '../src/repositories/dag_watcher.dart';
import '../src/use_cases/connect_to_node_use_case.dart';
import '../src/use_cases/get_block_use_case.dart';
import '../src/use_cases/get_dag_state_use_case.dart';
import '../src/use_cases/watch_dag_updates_use_case.dart';

/// Configure DAG domain dependencies (use cases)
/// Note: DagReader, DagWatcher, DagRepository must be registered before calling this
GetIt configureDagDomainDependencies(
  GetIt getIt, {
  String? environment,
}) {
  // Use cases - depend on interfaces registered in dag_data
  getIt.registerLazySingleton<GetDagStateUseCase>(
    () => GetDagStateUseCase(getIt<DagReader>()),
  );
  getIt.registerLazySingleton<GetBlockUseCase>(
    () => GetBlockUseCase(getIt<DagReader>()),
  );
  getIt.registerLazySingleton<WatchDagUpdatesUseCase>(
    () => WatchDagUpdatesUseCase(getIt<DagWatcher>()),
  );
  getIt.registerLazySingleton<ConnectToNodeUseCase>(
    () => ConnectToNodeUseCase(getIt<DagRepository>()),
  );

  return getIt;
}
