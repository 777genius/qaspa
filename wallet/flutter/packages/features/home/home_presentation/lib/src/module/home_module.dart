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
  HomeStore? _store;

  @override
  List<Type> get expects => [
        WalletRepository,
        AccountRepository,
        TransactionRepository,
      ];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureHomeDomainDependencies,
    );

    // Register presentation layer (HomeStore)
    ModularityInjectableBridge.configureInternal(i, configureHomeDependencies);
  }

  @override
  void exports(Binder i) {
    // Export HomeStore for page access and keep reference for dispose
    _store = i.get<HomeStore>();
    i.singleton<HomeStore>(() => _store!);
  }

  @override
  void onDispose() {
    _store?.dispose();
    _store = null;
  }
}
