import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:stealth_domain/stealth_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/stealth_injectable.dart';
import '../stores/stealth_store.dart';

/// Modularity module for stealth (privacy) feature.
class StealthModule extends Module {
  @override
  List<Type> get expects => [AccountRepository, TransactionRepository];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureStealthDomainDependencies,
    );

    // Register presentation layer (StealthStore)
    ModularityInjectableBridge.configureInternal(i, configureStealthDependencies);
  }

  @override
  void exports(Binder i) {
    // Export StealthStore for page access
    i.singleton<StealthStore>(() => i.get<StealthStore>());
  }
}
