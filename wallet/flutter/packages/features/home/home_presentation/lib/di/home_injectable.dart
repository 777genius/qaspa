import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'home_injectable.config.dart';

@InjectableInit(asExtension: false)
GetIt configureHomeDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(getIt, environment: environment, environmentFilter: environmentFilter);
