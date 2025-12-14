import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'home_domain_injectable.config.dart';

/// Configures home domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureHomeDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
