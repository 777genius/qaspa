import 'package:dashboard_domain/dashboard_domain.dart';
import 'package:dashboard_presentation/src/stores/dashboard_store.dart';
import 'package:get_it/get_it.dart';

/// Configure Dashboard presentation dependencies (stores)
/// Note: Use cases must be registered before calling this (in dashboard_domain)
GetIt configureDashboardPresentationDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<DashboardStore>(
    () => DashboardStore(
      getIt<GetClusterStatsUseCase>(),
      getIt<WatchClusterStatsUseCase>(),
    ),
  );

  return getIt;
}
