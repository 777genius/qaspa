import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'stealth_injectable.config.dart';

@InjectableInit(asExtension: false)
GetIt configureStealthDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(getIt, environment: environment, environmentFilter: environmentFilter);
