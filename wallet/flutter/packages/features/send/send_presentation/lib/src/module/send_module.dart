import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:send_domain/send_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/send_injectable.dart';
import '../stores/send_store.dart';

/// Modularity module for send feature.
class SendModule extends Module {
  @override
  List<Type> get expects => [AccountRepository, TransactionRepository];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureSendDomainDependencies,
    );

    // Register presentation layer (SendStore)
    ModularityInjectableBridge.configureInternal(i, configureSendDependencies);
  }

  @override
  void exports(Binder i) {
    // Export SendStore for page access
    i.singleton<SendStore>(() => i.get<SendStore>());
  }
}
