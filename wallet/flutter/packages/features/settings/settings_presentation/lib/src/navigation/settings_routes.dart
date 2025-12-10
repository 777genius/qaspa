import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../module/settings_module.dart';
import '../pages/settings_page.dart';
import '../pages/export_mnemonic_page.dart';
import '../pages/change_password_page.dart';

/// Route paths for settings feature.
abstract final class SettingsRoutes {
  static const String basePath = '/settings';
  static const String main = basePath;
  static const String exportMnemonic = '$basePath/export-mnemonic';
  static const String changePassword = '$basePath/change-password';

  static List<RouteBase> routes() {
    return [
      ShellRoute(
        builder: (context, state, child) {
          return ModuleScope<SettingsModule>(
            module: SettingsModule(),
            retentionPolicy: ModuleRetentionPolicy.routeBound,
            loadingBuilder: (context) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            errorBuilder: (context, error, retry) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Failed to load settings: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: retry, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: main,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: exportMnemonic,
            builder: (context, state) => const ExportMnemonicPage(),
          ),
          GoRoute(
            path: changePassword,
            builder: (context, state) => const ChangePasswordPage(),
          ),
        ],
      ),
    ];
  }
}
