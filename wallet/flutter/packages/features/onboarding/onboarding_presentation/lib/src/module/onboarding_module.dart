import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:onboarding_domain/onboarding_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/onboarding_injectable.dart';
import '../stores/onboarding_store.dart';

/// Modularity module for onboarding feature.
///
/// Provides OnboardingStore and BIP-39 wordlist service for the onboarding flow.
/// Requires WalletRepository from parent scope.
class OnboardingModule extends Module {
  @override
  List<Type> get expects => [WalletRepository];

  @override
  void binds(Binder i) {
    // Register domain use cases (with auto parent scope resolution)
    ModularityInjectableBridge.configureInternal(
      i,
      configureOnboardingDomainDependencies,
    );

    // Register presentation layer (OnboardingStore)
    ModularityInjectableBridge.configureInternal(i, configureOnboardingDependencies);
  }

  @override
  void exports(Binder i) {
    // Export OnboardingStore for page access
    i.singleton<OnboardingStore>(() => i.get<OnboardingStore>());
  }

  @override
  void onDispose() {
    // Reset store state when module is disposed
  }
}
