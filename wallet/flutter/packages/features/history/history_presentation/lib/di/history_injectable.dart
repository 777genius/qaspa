import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'history_injectable.config.dart';

@InjectableInit(asExtension: false)
GetIt configureHistoryDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(getIt, environment: environment, environmentFilter: environmentFilter);
