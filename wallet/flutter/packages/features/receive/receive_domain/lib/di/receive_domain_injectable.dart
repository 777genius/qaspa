import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'receive_domain_injectable.config.dart';

/// Configures receive domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureReceiveDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
