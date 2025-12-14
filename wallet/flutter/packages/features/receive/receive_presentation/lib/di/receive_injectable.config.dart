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
import 'package:receive_domain/receive_domain.dart' as _i671;
import 'package:receive_presentation/src/stores/receive_store.dart' as _i84;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  gh.lazySingleton<_i84.ReceiveStore>(
    () => _i84.ReceiveStore(
      getReceiveAddressUseCase: gh<_i671.GetReceiveAddressUseCase>(),
      generateNewAddressUseCase: gh<_i671.GenerateNewAddressUseCase>(),
    ),
  );
  return getIt;
}
