import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:onboarding_data/onboarding_data.dart';
import 'package:onboarding_domain/onboarding_domain.dart';

import 'onboarding_injectable.config.dart';

@InjectableInit(asExtension: false)
GetIt configureOnboardingDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(getIt, environment: environment, environmentFilter: environmentFilter);

/// Module for registering external dependencies and factories.
@module
abstract class OnboardingInjectableModule {
  /// Register Bip39WordlistService with wordlist from onboarding_data.
  @lazySingleton
  Bip39WordlistService get wordlistService =>
      Bip39WordlistService(wordlist: bip39EnglishWordlist);
}
