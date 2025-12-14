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
import 'package:receive_domain/src/usecases/generate_new_address_usecase.dart'
    as _i35;
import 'package:receive_domain/src/usecases/get_receive_address_usecase.dart'
    as _i394;
import 'package:wallet_domain/wallet_domain.dart' as _i375;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.factory<_i35.GenerateNewAddressUseCase>(
    () => _i35.GenerateNewAddressUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  gh.factory<_i394.GetReceiveAddressUseCase>(
    () => _i394.GetReceiveAddressUseCase(
      accountRepository: gh<_i375.AccountRepository>(),
    ),
  );
  return getIt;
}
