// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:home_domain/home_domain.dart' as _i622;
import 'package:home_presentation/src/stores/home_store.dart' as _i82;
import 'package:injectable/injectable.dart' as _i526;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.lazySingleton<_i82.HomeStore>(
    () => _i82.HomeStore(
      getBalanceUseCase: gh<_i622.GetBalanceUseCase>(),
      getRecentTransactionsUseCase: gh<_i622.GetRecentTransactionsUseCase>(),
      watchBalanceUseCase: gh<_i622.WatchBalanceUseCase>(),
    ),
  );
  return getIt;
}
