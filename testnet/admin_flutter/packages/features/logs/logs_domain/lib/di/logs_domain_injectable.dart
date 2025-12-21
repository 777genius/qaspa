import 'package:admin_domain/admin_domain.dart';
import 'package:get_it/get_it.dart';
import 'package:logs_domain/src/use_cases/get_container_ids_use_case.dart';
import 'package:logs_domain/src/use_cases/watch_logs_use_case.dart';

/// Configure Logs domain dependencies (use cases)
/// Note: LogRepository must be registered before calling this (in admin_data)
GetIt configureLogsDomainDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<WatchLogsUseCase>(
    () => WatchLogsUseCase(getIt<LogRepository>()),
  );
  getIt.registerLazySingleton<GetContainerIdsUseCase>(
    () => GetContainerIdsUseCase(getIt<LogRepository>()),
  );

  return getIt;
}
