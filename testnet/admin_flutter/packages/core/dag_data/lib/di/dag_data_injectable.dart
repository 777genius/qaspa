import 'package:dag_data/src/cache/dag_block_cache.dart';
import 'package:dag_data/src/clients/dag_api_client.dart';
import 'package:dag_data/src/clients/dag_websocket_client.dart';
import 'package:dag_data/src/mappers/dag_block_mapper.dart';
import 'package:dag_data/src/mappers/dag_state_mapper.dart';
import 'package:dag_data/src/repositories/dag_repository_impl.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

/// Configure DAG data dependencies (repository impl, clients, mappers, cache)
/// Note: http.Client must be registered before calling this (in admin_data)
GetIt configureDagDataDependencies(
  GetIt getIt, {
  String? environment,
}) {
  // URLs
  const controllerBaseUrl = String.fromEnvironment(
    'CONTROLLER_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );
  const dagWsUrl = String.fromEnvironment(
    'DAG_WS_URL',
    defaultValue: 'ws://localhost:8081/ws/dag',
  );

  // Cache
  getIt.registerLazySingleton<DagBlockCache>(
    () => DagBlockCache(),
  );

  // Mappers
  getIt.registerLazySingleton<DagBlockMapper>(
    () => const DagBlockMapper(),
  );
  getIt.registerLazySingleton<DagStateMapper>(
    () => DagStateMapper(getIt<DagBlockMapper>()),
  );

  // API Client
  getIt.registerLazySingleton<DagApiClient>(
    () => DagApiClient(
      getIt<http.Client>(),
      getIt<DagBlockMapper>(),
      getIt<DagStateMapper>(),
      controllerBaseUrl,
    ),
  );

  // WebSocket Client
  getIt.registerLazySingleton<DagWebSocketClient>(
    () => DagWebSocketClient(
      getIt<DagBlockMapper>(),
      dagWsUrl,
    ),
  );

  // Repository
  getIt.registerLazySingleton<DagRepository>(
    () => DagRepositoryImpl(
      getIt<DagApiClient>(),
      getIt<DagWebSocketClient>(),
      getIt<DagBlockCache>(),
    ),
  );

  // Register repository also as DagReader and DagWatcher interfaces
  getIt.registerLazySingleton<DagReader>(
    () => getIt<DagRepository>(),
  );
  getIt.registerLazySingleton<DagWatcher>(
    () => getIt<DagRepository>(),
  );

  return getIt;
}
