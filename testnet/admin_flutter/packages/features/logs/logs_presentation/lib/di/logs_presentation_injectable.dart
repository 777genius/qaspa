import 'package:get_it/get_it.dart';
import 'package:logs_domain/logs_domain.dart';
import 'package:logs_presentation/src/stores/logs_store.dart';

/// Configure Logs presentation dependencies (stores)
/// Note: Use cases must be registered before calling this (in logs_domain)
GetIt configureLogsPresentationDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<LogsStore>(
    () => LogsStore(
      getIt<WatchLogsUseCase>(),
      getIt<GetContainerIdsUseCase>(),
    ),
  );

  return getIt;
}
