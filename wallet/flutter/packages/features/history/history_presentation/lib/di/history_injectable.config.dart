// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:history_domain/history_domain.dart' as _i206;
import 'package:history_presentation/src/stores/history_store.dart' as _i608;
import 'package:injectable/injectable.dart' as _i526;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.lazySingleton<_i608.HistoryStore>(
    () => _i608.HistoryStore(
      getTransactionHistoryUseCase: gh<_i206.GetTransactionHistoryUseCase>(),
      watchTransactionHistoryUseCase:
          gh<_i206.WatchTransactionHistoryUseCase>(),
      getTransactionDetailsUseCase: gh<_i206.GetTransactionDetailsUseCase>(),
    ),
  );
  return getIt;
}
