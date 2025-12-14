import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'settings_domain_injectable.config.dart';

/// Configures settings domain dependencies using injectable.
@InjectableInit(asExtension: false)
GetIt configureSettingsDomainDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(
      getIt,
      environment: environment,
      environmentFilter: environmentFilter,
    );
