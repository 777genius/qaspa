import 'package:admin_domain/admin_domain.dart';
import 'package:dashboard_domain/src/use_cases/get_cluster_stats_use_case.dart';
import 'package:dashboard_domain/src/use_cases/watch_cluster_stats_use_case.dart';
import 'package:get_it/get_it.dart';

/// Configure Dashboard domain dependencies (use cases)
/// Note: ClusterRepository must be registered before calling this (in admin_data)
GetIt configureDashboardDomainDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<GetClusterStatsUseCase>(
    () => GetClusterStatsUseCase(getIt<ClusterRepository>()),
  );
  getIt.registerLazySingleton<WatchClusterStatsUseCase>(
    () => WatchClusterStatsUseCase(getIt<ClusterRepository>()),
  );

  return getIt;
}
