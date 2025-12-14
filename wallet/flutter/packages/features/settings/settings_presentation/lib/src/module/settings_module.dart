import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:settings_domain/settings_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/settings_injectable.dart';
import '../stores/settings_store.dart';

/// Modularity module for settings feature.
class SettingsModule extends Module {
  SettingsStore? _store;

  @override
  List<Type> get expects => [WalletRepository];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureSettingsDomainDependencies,
    );

    // Register presentation layer (SettingsStore)
    ModularityInjectableBridge.configureInternal(i, configureSettingsDependencies);
  }

  @override
  void exports(Binder i) {
    // Export SettingsStore for page access and keep reference for dispose
    _store = i.get<SettingsStore>();
    i.singleton<SettingsStore>(() => _store!);
  }

  @override
  void onDispose() {
    _store?.dispose();
    _store = null;
  }
}
