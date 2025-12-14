import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'history_domain_injectable.config.dart';

/// Configures history domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureHistoryDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
