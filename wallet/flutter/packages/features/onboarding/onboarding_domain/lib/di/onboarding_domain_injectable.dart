import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'onboarding_domain_injectable.config.dart';

/// Configures onboarding domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureOnboardingDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
