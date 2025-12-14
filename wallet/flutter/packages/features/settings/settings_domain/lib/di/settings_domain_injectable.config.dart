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
import 'package:settings_domain/src/usecases/change_password_usecase.dart'
    as _i567;
import 'package:settings_domain/src/usecases/delete_wallet_usecase.dart'
    as _i155;
import 'package:settings_domain/src/usecases/export_mnemonic_usecase.dart'
    as _i224;
import 'package:settings_domain/src/usecases/get_wallet_info_usecase.dart'
    as _i43;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i155.DeleteWalletUseCase>(
    () => _i155.DeleteWalletUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
    ),
  );
  gh.factory<_i224.ExportMnemonicUseCase>(
    () => _i224.ExportMnemonicUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
    ),
  );
  gh.factory<_i43.GetWalletInfoUseCase>(
    () => _i43.GetWalletInfoUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
    ),
  );
  gh.factory<_i567.ChangePasswordUseCase>(
    () => _i567.ChangePasswordUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
    ),
  );
  return getIt;
}
