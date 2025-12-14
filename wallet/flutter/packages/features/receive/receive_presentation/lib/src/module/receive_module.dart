import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:receive_domain/receive_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/receive_injectable.dart';
import '../stores/receive_store.dart';

/// Modularity module for receive feature.
class ReceiveModule extends Module {
  @override
  List<Type> get expects => [AccountRepository];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureReceiveDomainDependencies,
    );

    // Register presentation layer (ReceiveStore)
    ModularityInjectableBridge.configureInternal(i, configureReceiveDependencies);
  }

  @override
  void exports(Binder i) {
    // Export ReceiveStore for page access
    i.singleton<ReceiveStore>(() => i.get<ReceiveStore>());
  }
}
