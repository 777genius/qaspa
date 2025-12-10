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
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureSendDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<EstimateTransactionUseCase>(
      () => EstimateTransactionUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );

    i.factory<SendTransactionUseCase>(
      () => SendTransactionUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );

    i.factory<ValidateAddressUseCase>(
      () => ValidateAddressUseCase(),
    );
  }

  @override
  void exports(Binder i) {
    // Note: dispose() should be called manually when module scope is destroyed
    i.singleton<SendStore>(
      () => SendStore(
        estimateTransactionUseCase: i.get<EstimateTransactionUseCase>(),
        sendTransactionUseCase: i.get<SendTransactionUseCase>(),
        validateAddressUseCase: i.get<ValidateAddressUseCase>(),
      ),
    );
  }
}
