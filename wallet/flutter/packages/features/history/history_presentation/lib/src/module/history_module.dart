import 'package:history_domain/history_domain.dart';
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/history_injectable.dart';
import '../stores/history_store.dart';

/// Modularity module for history feature.
class HistoryModule extends Module {
  @override
  List<Type> get expects => [TransactionRepository];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureHistoryDomainDependencies,
    );

    // Register presentation layer (HistoryStore)
    ModularityInjectableBridge.configureInternal(i, configureHistoryDependencies);
  }

  @override
  void exports(Binder i) {
    // Export HistoryStore for page access
    i.singleton<HistoryStore>(() => i.get<HistoryStore>());
  }
}
