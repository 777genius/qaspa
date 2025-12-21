// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:admin_data/di/admin_data_injectable.dart' as _i556;
import 'package:admin_data/src/clients/admin_api_client.dart' as _i938;
import 'package:admin_data/src/clients/events_websocket_client.dart' as _i660;
import 'package:admin_data/src/clients/logs_websocket_client.dart' as _i1000;
import 'package:admin_data/src/repositories/cluster_repository_impl.dart'
    as _i33;
import 'package:admin_data/src/repositories/log_repository_impl.dart' as _i735;
import 'package:admin_data/src/repositories/metrics_repository_impl.dart'
    as _i482;
import 'package:admin_data/src/repositories/miner_repository_impl.dart'
    as _i737;
import 'package:admin_data/src/repositories/node_repository_impl.dart' as _i792;
import 'package:admin_domain/admin_domain.dart' as _i381;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final adminDataModule = _$AdminDataModule();
  gh.lazySingleton<_i519.Client>(() => adminDataModule.httpClient);
  gh.lazySingleton<String>(
    () => adminDataModule.adminApiBaseUrl,
    instanceName: 'adminApiBaseUrl',
  );
  gh.lazySingleton<String>(
    () => adminDataModule.eventsWsUrl,
    instanceName: 'eventsWsUrl',
  );
  gh.lazySingleton<String>(
    () => adminDataModule.logsWsUrl,
    instanceName: 'logsWsUrl',
  );
  gh.lazySingleton<_i660.EventsWebSocketClient>(
    () => _i660.EventsWebSocketClient(
      wsUrl: gh<String>(instanceName: 'eventsWsUrl'),
    ),
  );
  gh.lazySingleton<_i1000.LogsWebSocketClient>(
    () => _i1000.LogsWebSocketClient(
      wsUrl: gh<String>(instanceName: 'logsWsUrl'),
    ),
  );
  gh.lazySingleton<_i938.AdminApiClient>(
    () => _i938.AdminApiClient(
      client: gh<_i519.Client>(),
      baseUrl: gh<String>(instanceName: 'adminApiBaseUrl'),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.lazySingleton<_i381.MetricsRepository>(
    () => _i482.MetricsRepositoryImpl(gh<_i938.AdminApiClient>()),
  );
  gh.lazySingleton<_i381.NodeRepository>(
    () => _i792.NodeRepositoryImpl(
      apiClient: gh<_i938.AdminApiClient>(),
      wsClient: gh<_i660.EventsWebSocketClient>(),
    ),
  );
  gh.lazySingleton<_i381.MinerRepository>(
    () => _i737.MinerRepositoryImpl(
      apiClient: gh<_i938.AdminApiClient>(),
      wsClient: gh<_i660.EventsWebSocketClient>(),
    ),
  );
  gh.lazySingleton<_i381.LogRepository>(
    () => _i735.LogRepositoryImpl(
      apiClient: gh<_i938.AdminApiClient>(),
      wsClient: gh<_i1000.LogsWebSocketClient>(),
    ),
  );
  gh.lazySingleton<_i381.ClusterRepository>(
    () => _i33.ClusterRepositoryImpl(
      apiClient: gh<_i938.AdminApiClient>(),
      wsClient: gh<_i660.EventsWebSocketClient>(),
    ),
  );
  return getIt;
}

class _$AdminDataModule extends _i556.AdminDataModule {}
