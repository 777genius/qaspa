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
import 'package:onboarding_domain/src/services/bip39_wordlist_service.dart'
    as _i727;
import 'package:onboarding_domain/src/usecases/create_wallet_usecase.dart'
    as _i217;
import 'package:onboarding_domain/src/usecases/generate_mnemonic_usecase.dart'
    as _i271;
import 'package:onboarding_domain/src/usecases/import_wallet_usecase.dart'
    as _i64;
import 'package:onboarding_domain/src/usecases/validate_mnemonic_usecase.dart'
    as _i540;
import 'package:onboarding_domain/src/usecases/verify_mnemonic_usecase.dart'
    as _i1011;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i217.CreateWalletUseCase>(
    () => _i217.CreateWalletUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
    ),
  );
  gh.factory<_i271.GenerateMnemonicUseCase>(
    () => _i271.GenerateMnemonicUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
    ),
  );
  gh.factory<_i64.ImportWalletUseCase>(
    () => _i64.ImportWalletUseCase(
      walletRepository: gh<_i375.WalletRepository>(),
      wordlistService: gh<_i727.Bip39WordlistService>(),
    ),
  );
  gh.factory<_i540.ValidateMnemonicUseCase>(
    () => _i540.ValidateMnemonicUseCase(gh<_i727.Bip39WordlistService>()),
  );
  gh.factory<_i1011.VerifyMnemonicUseCase>(
    () => _i1011.VerifyMnemonicUseCase(gh<_i727.Bip39WordlistService>()),
  );
  return getIt;
}
