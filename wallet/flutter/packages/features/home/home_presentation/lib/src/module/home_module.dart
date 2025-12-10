import 'package:home_domain/home_domain.dart';
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/home_injectable.dart';
import '../stores/home_store.dart';

/// Modularity module for home feature.
///
/// Provides HomeStore and use cases for the home screen.
/// Requires WalletRepository, AccountRepository, and TransactionRepository
/// from parent scope.
class HomeModule extends Module {
  @override
  List<Type> get expects => [
        WalletRepository,
        AccountRepository,
        TransactionRepository,
      ];

  @override
  void binds(Binder i) {
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureHomeDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<GetBalanceUseCase>(
      () => GetBalanceUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );

    i.factory<GetRecentTransactionsUseCase>(
      () => GetRecentTransactionsUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );

    i.factory<WatchBalanceUseCase>(
      () => WatchBalanceUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );
  }

  @override
  void exports(Binder i) {
    // HomeStore (singleton - one per module lifecycle)
    // Note: dispose() should be called manually when module scope is destroyed
    i.singleton<HomeStore>(
      () => HomeStore(
        getBalanceUseCase: i.get<GetBalanceUseCase>(),
        getRecentTransactionsUseCase: i.get<GetRecentTransactionsUseCase>(),
        watchBalanceUseCase: i.get<WatchBalanceUseCase>(),
      ),
    );
  }
}
