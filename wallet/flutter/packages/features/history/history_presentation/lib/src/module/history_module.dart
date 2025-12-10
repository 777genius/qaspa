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
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureHistoryDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<GetTransactionHistoryUseCase>(
      () => GetTransactionHistoryUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );

    i.factory<WatchTransactionHistoryUseCase>(
      () => WatchTransactionHistoryUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );

    i.factory<GetTransactionDetailsUseCase>(
      () => GetTransactionDetailsUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );
  }

  @override
  void exports(Binder i) {
    // Note: dispose() should be called manually when module scope is destroyed
    i.singleton<HistoryStore>(
      () => HistoryStore(
        getTransactionHistoryUseCase: i.get<GetTransactionHistoryUseCase>(),
        watchTransactionHistoryUseCase: i.get<WatchTransactionHistoryUseCase>(),
        getTransactionDetailsUseCase: i.get<GetTransactionDetailsUseCase>(),
      ),
    );
  }
}
