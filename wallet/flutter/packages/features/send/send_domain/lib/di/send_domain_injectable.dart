import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'send_domain_injectable.config.dart';

/// Configures send domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureSendDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
