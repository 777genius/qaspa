import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:settings_domain/settings_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../di/settings_injectable.dart';
import '../stores/settings_store.dart';

/// Modularity module for settings feature.
class SettingsModule extends Module {
  @override
  List<Type> get expects => [WalletRepository];

  @override
  void binds(Binder i) {
    // Auto-register services without parent dependencies via injectable
    ModularityInjectableBridge.configureInternal(i, configureSettingsDependencies);

    // Use cases with parent dependencies (manual registration)
    i.factory<GetWalletInfoUseCase>(
      () => GetWalletInfoUseCase(
        walletRepository: i.parent<WalletRepository>(),
      ),
    );

    i.factory<ExportMnemonicUseCase>(
      () => ExportMnemonicUseCase(
        walletRepository: i.parent<WalletRepository>(),
      ),
    );

    i.factory<ChangePasswordUseCase>(
      () => ChangePasswordUseCase(
        walletRepository: i.parent<WalletRepository>(),
      ),
    );

    i.factory<DeleteWalletUseCase>(
      () => DeleteWalletUseCase(
        walletRepository: i.parent<WalletRepository>(),
      ),
    );
  }

  @override
  void exports(Binder i) {
    // Note: dispose() should be called manually when module scope is destroyed
    i.singleton<SettingsStore>(
      () => SettingsStore(
        getWalletInfoUseCase: i.get<GetWalletInfoUseCase>(),
        exportMnemonicUseCase: i.get<ExportMnemonicUseCase>(),
        changePasswordUseCase: i.get<ChangePasswordUseCase>(),
        deleteWalletUseCase: i.get<DeleteWalletUseCase>(),
      ),
    );
  }
}
