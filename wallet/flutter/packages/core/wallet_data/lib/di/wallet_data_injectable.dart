import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:wallet_rust_bridge/wallet_rust_bridge.dart';

import '../src/database/history_database.dart';
import 'wallet_data_injectable.config.dart';

@InjectableInit(asExtension: false)
GetIt configureWalletDataDependencies(
  GetIt getIt, {
  String? environment,
  EnvironmentFilter? environmentFilter,
}) =>
    init(getIt, environment: environment, environmentFilter: environmentFilter);

/// Module for registering external dependencies and factories.
@module
abstract class WalletDataModule {
  /// Register WalletBridge singleton instance.
  @lazySingleton
  WalletBridge get walletBridge => WalletBridge.instance;

  /// Register HistoryDatabase via factory constructor.
  @lazySingleton
  HistoryDatabase get historyDatabase => HistoryDatabase.open();
}
