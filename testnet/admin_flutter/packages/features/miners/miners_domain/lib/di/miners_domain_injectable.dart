import 'package:admin_domain/admin_domain.dart';
import 'package:get_it/get_it.dart';
import 'package:miners_domain/src/use_cases/add_miner_use_case.dart';
import 'package:miners_domain/src/use_cases/get_miners_use_case.dart';
import 'package:miners_domain/src/use_cases/remove_miner_use_case.dart';
import 'package:miners_domain/src/use_cases/start_miner_use_case.dart';
import 'package:miners_domain/src/use_cases/stop_miner_use_case.dart';
import 'package:miners_domain/src/use_cases/watch_miners_use_case.dart';

/// Configure Miners domain dependencies (use cases)
/// Note: MinerRepository must be registered before calling this (in admin_data)
GetIt configureMinersDomainDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<GetMinersUseCase>(
    () => GetMinersUseCase(getIt<MinerRepository>()),
  );
  getIt.registerLazySingleton<WatchMinersUseCase>(
    () => WatchMinersUseCase(getIt<MinerRepository>()),
  );
  getIt.registerLazySingleton<AddMinerUseCase>(
    () => AddMinerUseCase(getIt<MinerRepository>()),
  );
  getIt.registerLazySingleton<RemoveMinerUseCase>(
    () => RemoveMinerUseCase(getIt<MinerRepository>()),
  );
  getIt.registerLazySingleton<StartMinerUseCase>(
    () => StartMinerUseCase(getIt<MinerRepository>()),
  );
  getIt.registerLazySingleton<StopMinerUseCase>(
    () => StopMinerUseCase(getIt<MinerRepository>()),
  );

  return getIt;
}
