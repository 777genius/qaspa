import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'stealth_domain_injectable.config.dart';

/// Configures stealth domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureStealthDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
