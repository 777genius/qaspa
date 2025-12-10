import 'package:history_presentation/history_presentation.dart';
import 'package:home_presentation/home_presentation.dart';
import 'package:modularity_core/modularity_core.dart';
import 'package:modularity_injectable/modularity_injectable.dart';
import 'package:onboarding_presentation/onboarding_presentation.dart';
import 'package:receive_presentation/receive_presentation.dart';
import 'package:send_presentation/send_presentation.dart';
import 'package:settings_presentation/settings_presentation.dart';
import 'package:stealth_presentation/stealth_presentation.dart';
import 'package:wallet_data/wallet_data.dart';

import '../di/app_injectable.dart';

/// Root module for the Kaspa Wallet app.
///
/// Provides core infrastructure services and repositories.
/// All feature modules are declared as submodules for graph visualization.
class AppModule extends Module {
  /// Declare all feature modules as submodules for graph visualization.
  /// These modules are created via ModuleScope in routes, not here.
  @override
  List<Module> get submodules => [
        OnboardingModule(),
        HomeModule(),
        SendModule(),
        ReceiveModule(),
        HistoryModule(),
        SettingsModule(),
        StealthModule(),
      ];

  @override
  void binds(Binder i) {
    // Auto-register services via injectable (wallet_data dependencies)
    ModularityInjectableBridge.configureInternal(i, configureAppDependencies);

    // Also configure wallet_data internal dependencies
    ModularityInjectableBridge.configureInternal(i, configureWalletDataDependencies);
  }

  @override
  void exports(Binder i) {
    // Export repositories via injectable (with modularityExportEnv filter)
    ModularityInjectableBridge.configureExports(i, configureWalletDataDependencies);
  }

  @override
  Future<void> onInit() async {
    // WalletBridge initialization will be done in Phase 3
    // when we have actual Rust integration
  }

  @override
  void onDispose() {
    // Cleanup resources
  }
}
