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
import 'package:stealth_domain/stealth_domain.dart' as _i1042;
import 'package:stealth_presentation/src/stores/stealth_store.dart' as _i454;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.lazySingleton<_i454.StealthStore>(
    () => _i454.StealthStore(
      getStealthAddressUseCase: gh<_i1042.GetStealthAddressUseCase>(),
      scanStealthPaymentsUseCase: gh<_i1042.ScanStealthPaymentsUseCase>(),
      sendStealthPaymentUseCase: gh<_i1042.SendStealthPaymentUseCase>(),
      getStealthBalanceUseCase: gh<_i1042.GetStealthBalanceUseCase>(),
      getStealthTransactionsUseCase: gh<_i1042.GetStealthTransactionsUseCase>(),
    ),
  );
  return getIt;
}
