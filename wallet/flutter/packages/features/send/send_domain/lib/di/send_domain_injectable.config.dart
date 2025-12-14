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
import 'package:send_domain/src/usecases/estimate_transaction_usecase.dart'
    as _i455;
import 'package:send_domain/src/usecases/send_transaction_usecase.dart'
    as _i1014;
import 'package:send_domain/src/usecases/validate_address_usecase.dart'
    as _i540;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i540.ValidateAddressUseCase>(
    () => _i540.ValidateAddressUseCase(),
  );
  gh.factory<_i1014.SendTransactionUseCase>(
    () => _i1014.SendTransactionUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  gh.factory<_i455.EstimateTransactionUseCase>(
    () => _i455.EstimateTransactionUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  return getIt;
}
