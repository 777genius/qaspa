import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import 'admin_data_injectable.config.dart';

@InjectableInit(asExtension: false, generateForDir: ['lib'])
GetIt configureAdminDataDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(getIt, environment: environment, environmentFilter: environmentFilter);

@module
abstract class AdminDataModule {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @Named('adminApiBaseUrl')
  @lazySingleton
  String get adminApiBaseUrl => const String.fromEnvironment(
        'ADMIN_API_URL',
        defaultValue: 'http://localhost:8081',
      );

  @Named('eventsWsUrl')
  @lazySingleton
  String get eventsWsUrl => const String.fromEnvironment(
        'EVENTS_WS_URL',
        defaultValue: 'ws://localhost:8081/ws/events',
      );

  @Named('logsWsUrl')
  @lazySingleton
  String get logsWsUrl => const String.fromEnvironment(
        'LOGS_WS_URL',
        defaultValue: 'ws://localhost:8081/ws/logs',
      );
}
