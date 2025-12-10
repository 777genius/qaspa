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
import 'package:onboarding_domain/onboarding_domain.dart' as _i439;
import 'package:onboarding_presentation/di/onboarding_injectable.dart' as _i488;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final onboardingInjectableModule = _$OnboardingInjectableModule();
  gh.lazySingleton<_i439.Bip39WordlistService>(
    () => onboardingInjectableModule.wordlistService,
  );
  return getIt;
}

class _$OnboardingInjectableModule extends _i488.OnboardingInjectableModule {}
