// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:send_domain/send_domain.dart' as _i876;
import 'package:send_presentation/src/stores/send_store.dart' as _i514;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.lazySingleton<_i514.SendStore>(
    () => _i514.SendStore(
      estimateTransactionUseCase: gh<_i876.EstimateTransactionUseCase>(),
      sendTransactionUseCase: gh<_i876.SendTransactionUseCase>(),
      validateAddressUseCase: gh<_i876.ValidateAddressUseCase>(),
    ),
  );
  return getIt;
}
