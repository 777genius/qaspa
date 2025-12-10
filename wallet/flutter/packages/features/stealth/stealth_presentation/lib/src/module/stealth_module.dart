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
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureStealthDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<GetStealthAddressUseCase>(
      () => GetStealthAddressUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );

    i.factory<ScanStealthPaymentsUseCase>(
      () => ScanStealthPaymentsUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );

    i.factory<SendStealthPaymentUseCase>(
      () => SendStealthPaymentUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );

    i.factory<GetStealthBalanceUseCase>(
      () => GetStealthBalanceUseCase(
        accountRepository: i.parent<AccountRepository>(),
      ),
    );

    i.factory<GetStealthTransactionsUseCase>(
      () => GetStealthTransactionsUseCase(
        transactionRepository: i.parent<TransactionRepository>(),
      ),
    );
  }

  @override
  void exports(Binder i) {
    // Note: dispose() should be called manually when module scope is destroyed
    i.singleton<StealthStore>(
      () => StealthStore(
        getStealthAddressUseCase: i.get<GetStealthAddressUseCase>(),
        scanStealthPaymentsUseCase: i.get<ScanStealthPaymentsUseCase>(),
        sendStealthPaymentUseCase: i.get<SendStealthPaymentUseCase>(),
        getStealthBalanceUseCase: i.get<GetStealthBalanceUseCase>(),
        getStealthTransactionsUseCase: i.get<GetStealthTransactionsUseCase>(),
      ),
    );
  }
}
