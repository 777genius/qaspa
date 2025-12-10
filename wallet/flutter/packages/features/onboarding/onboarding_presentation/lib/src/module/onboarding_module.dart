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
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureOnboardingDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<GenerateMnemonicUseCase>(
      () => GenerateMnemonicUseCase(
        walletRepository: i.parent<WalletRepository>(),
      ),
    );

    i.factory<CreateWalletUseCase>(
      () => CreateWalletUseCase(
        walletRepository: i.parent<WalletRepository>(),
      ),
    );

    i.factory<ImportWalletUseCase>(
      () => ImportWalletUseCase(
        walletRepository: i.parent<WalletRepository>(),
        wordlistService: i.get<Bip39WordlistService>(),
      ),
    );
  }

  @override
  void exports(Binder i) {
    // OnboardingStore (public - for UI)
    i.singleton<OnboardingStore>(
      () => OnboardingStore(
        generateMnemonicUseCase: i.get<GenerateMnemonicUseCase>(),
        validateMnemonicUseCase: i.get<ValidateMnemonicUseCase>(),
        verifyMnemonicUseCase: i.get<VerifyMnemonicUseCase>(),
        createWalletUseCase: i.get<CreateWalletUseCase>(),
        importWalletUseCase: i.get<ImportWalletUseCase>(),
        wordlistService: i.get<Bip39WordlistService>(),
      ),
    );

    // Bip39WordlistService is already registered via injectable in binds()
    // and can be accessed via i.get<Bip39WordlistService>() from bindings
  }

  @override
  void onDispose() {
    // Reset store state when module is disposed
  }
}
