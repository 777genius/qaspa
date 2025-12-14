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
import 'package:stealth_domain/src/usecases/get_stealth_address_usecase.dart'
    as _i965;
import 'package:stealth_domain/src/usecases/get_stealth_balance_usecase.dart'
    as _i524;
import 'package:stealth_domain/src/usecases/get_stealth_transactions_usecase.dart'
    as _i920;
import 'package:stealth_domain/src/usecases/scan_stealth_payments_usecase.dart'
    as _i1051;
import 'package:stealth_domain/src/usecases/send_stealth_payment_usecase.dart'
    as _i513;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i524.GetStealthBalanceUseCase>(
    () => _i524.GetStealthBalanceUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  gh.factory<_i1051.ScanStealthPaymentsUseCase>(
    () => _i1051.ScanStealthPaymentsUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  gh.factory<_i965.GetStealthAddressUseCase>(
    () => _i965.GetStealthAddressUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  gh.factory<_i920.GetStealthTransactionsUseCase>(
    () => _i920.GetStealthTransactionsUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  gh.factory<_i513.SendStealthPaymentUseCase>(
    () => _i513.SendStealthPaymentUseCase(
      transactionRepository: gh<_i375.TransactionRepository>(),
    ),
  );
  return getIt;
}
