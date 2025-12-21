import 'package:get_it/get_it.dart';
import 'package:miners_domain/miners_domain.dart';
import 'package:miners_presentation/src/stores/miners_store.dart';

/// Configure Miners presentation dependencies (stores)
/// Note: Use cases must be registered before calling this (in miners_domain)
GetIt configureMinersPresentationDependencies(
  GetIt getIt, {
  String? environment,
}) {
  getIt.registerLazySingleton<MinersStore>(
    () => MinersStore(
      getIt<GetMinersUseCase>(),
      getIt<WatchMinersUseCase>(),
      getIt<AddMinerUseCase>(),
      getIt<RemoveMinerUseCase>(),
      getIt<StartMinerUseCase>(),
      getIt<StopMinerUseCase>(),
    ),
  );

  return getIt;
}
