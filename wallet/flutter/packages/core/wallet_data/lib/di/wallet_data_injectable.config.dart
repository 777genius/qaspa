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
import 'package:wallet_data/di/wallet_data_injectable.dart' as _i183;
import 'package:wallet_data/src/database/history_database.dart' as _i362;
import 'package:wallet_data/src/datasources/local_datasource.dart' as _i252;
import 'package:wallet_data/src/datasources/rust_datasource.dart' as _i47;
import 'package:wallet_data/src/repositories/account_repository_impl.dart'
    as _i953;
import 'package:wallet_data/src/repositories/transaction_repository_impl.dart'
    as _i511;
import 'package:wallet_data/src/repositories/wallet_repository_impl.dart'
    as _i965;
import 'package:wallet_domain/wallet_domain.dart' as _i375;
import 'package:wallet_rust_bridge/wallet_rust_bridge.dart' as _i507;

const String _modularity_export = 'modularity_export';

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  final walletDataModule = _$WalletDataModule();
  gh.lazySingleton<_i507.WalletBridge>(() => walletDataModule.walletBridge);
  gh.lazySingleton<_i362.HistoryDatabase>(
      () => walletDataModule.historyDatabase);
  gh.lazySingleton<_i252.LocalDatasource>(
      () => _i252.LocalDatasource(gh<_i362.HistoryDatabase>()));
  gh.lazySingleton<_i47.RustDatasource>(
      () => _i47.RustDatasource(gh<_i507.WalletBridge>()));
  gh.lazySingleton<_i375.TransactionRepository>(
    () => _i511.TransactionRepositoryImpl(
      gh<_i47.RustDatasource>(),
      gh<_i252.LocalDatasource>(),
    ),
    registerFor: {_modularity_export},
  );
  gh.lazySingleton<_i375.AccountRepository>(
    () => _i953.AccountRepositoryImpl(gh<_i47.RustDatasource>()),
    registerFor: {_modularity_export},
  );
  gh.lazySingleton<_i375.WalletRepository>(
    () => _i965.WalletRepositoryImpl(gh<_i47.RustDatasource>()),
    registerFor: {_modularity_export},
  );
  return getIt;
}

class _$WalletDataModule extends _i183.WalletDataModule {}
