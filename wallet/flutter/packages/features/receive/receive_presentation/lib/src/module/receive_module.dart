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
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureReceiveDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<GetReceiveAddressUseCase>(
      () => GetReceiveAddressUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );

    i.factory<GenerateNewAddressUseCase>(
      () => GenerateNewAddressUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );
  }

  @override
  void exports(Binder i) {
    // Note: dispose() should be called manually when module scope is destroyed
    i.singleton<ReceiveStore>(
      () => ReceiveStore(
        getReceiveAddressUseCase: i.get<GetReceiveAddressUseCase>(),
        generateNewAddressUseCase: i.get<GenerateNewAddressUseCase>(),
      ),
    );
  }
}
