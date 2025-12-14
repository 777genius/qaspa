// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:home_domain/src/usecases/get_balance_usecase.dart' as _i290;
import 'package:home_domain/src/usecases/get_recent_transactions_usecase.dart'
    as _i794;
import 'package:home_domain/src/usecases/watch_balance_usecase.dart' as _i229;
import 'package:injectable/injectable.dart' as _i526;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i290.GetBalanceUseCase>(
    () => _i290.GetBalanceUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  gh.factory<_i229.WatchBalanceUseCase>(
    () => _i229.WatchBalanceUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  gh.factory<_i794.GetRecentTransactionsUseCase>(
    () => _i794.GetRecentTransactionsUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  return getIt;
}
