// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:history_domain/src/usecases/get_transaction_details_usecase.dart'
    as _i65;
import 'package:history_domain/src/usecases/get_transaction_history_usecase.dart'
    as _i703;
import 'package:history_domain/src/usecases/watch_transaction_history_usecase.dart'
    as _i853;
import 'package:injectable/injectable.dart' as _i526;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i853.WatchTransactionHistoryUseCase>(
    () => _i853.WatchTransactionHistoryUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  gh.factory<_i703.GetTransactionHistoryUseCase>(
    () => _i703.GetTransactionHistoryUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  gh.factory<_i65.GetTransactionDetailsUseCase>(
    () => _i65.GetTransactionDetailsUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  return getIt;
}
