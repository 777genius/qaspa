import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../module/onboarding_module.dart';
import '../pages/backup_mnemonic_page.dart';
import '../pages/generate_mnemonic_page.dart';
import '../pages/import_mnemonic_page.dart';
import '../pages/network_selection_page.dart';
import '../pages/set_password_page.dart';
import '../pages/success_page.dart';
import '../pages/verify_mnemonic_page.dart';
import '../pages/welcome_page.dart';
import '../stores/onboarding_store.dart';

/// Route paths for onboarding flow.
abstract final class OnboardingRoutes {
  static const String basePath = '/onboarding';

  static const String welcome = '$basePath/welcome';
  static const String generate = '$basePath/generate';
  static const String backup = '$basePath/backup';
  static const String verify = '$basePath/verify';
  static const String import = '$basePath/import';
  static const String password = '$basePath/password';
  static const String network = '$basePath/network';
  static const String success = '$basePath/success';

  /// Get all onboarding routes for go_router configuration.
  ///
  /// Routes are wrapped in ModuleScope for proper DI lifecycle management.
  ///
  /// Usage:
  /// ```dart
  /// final router = GoRouter(
  ///   observers: [Modularity.observer],
  ///   routes: [
  ///     ...OnboardingRoutes.routes(
  ///       onComplete: () => context.go('/home'),
  ///     ),
  ///   ],
  /// );
  /// ```
  static List<RouteBase> routes({
    required VoidCallback onComplete,
  }) {
    return [
      ShellRoute(
        builder: (context, state, child) {
          return ModuleScope<OnboardingModule>(
            module: OnboardingModule(),
            retentionPolicy: ModuleRetentionPolicy.routeBound,
            loadingBuilder: (context) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            errorBuilder: (context, error, retry) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Failed to initialize onboarding',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Please try again later',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: welcome,
            builder: (context, state) => WelcomePage(
              onCreateWallet: () => context.go(generate),
              onImportWallet: () => context.go(import),
            ),
          ),
          GoRoute(
            path: generate,
            builder: (context, state) => GenerateMnemonicPage(
              onContinue: () => context.go(backup),
              onBack: () => context.go(welcome),
            ),
          ),
          GoRoute(
            path: backup,
            builder: (context, state) => BackupMnemonicPage(
              onContinue: () => context.go(verify),
              onBack: () => context.go(generate),
            ),
          ),
          GoRoute(
            path: verify,
            builder: (context, state) => VerifyMnemonicPage(
              onContinue: () => context.go(password),
              onBack: () => context.go(backup),
            ),
          ),
          GoRoute(
            path: import,
            builder: (context, state) => ImportMnemonicPage(
              onContinue: () => context.go(password),
              onBack: () => context.go(welcome),
            ),
          ),
          GoRoute(
            path: password,
            builder: (context, state) => SetPasswordPage(
              onContinue: () => context.go(network),
              onBack: () {
                final store = ModuleProvider.of(context).get<OnboardingStore>();
                if (store.flow == OnboardingFlow.create) {
                  context.go(verify);
                } else {
                  context.go(import);
                }
              },
            ),
          ),
          GoRoute(
            path: network,
            builder: (context, state) => NetworkSelectionPage(
              onContinue: () => context.go(success),
              onBack: () => context.go(password),
            ),
          ),
          GoRoute(
            path: success,
            builder: (context, state) => SuccessPage(
              onGoToWallet: onComplete,
            ),
          ),
        ],
      ),
    ];
  }

  /// Create a standalone GoRouter for the onboarding flow.
  ///
  /// Useful for testing or when onboarding is the only flow.
  static GoRouter createRouter({
    required VoidCallback onComplete,
  }) {
    return GoRouter(
      initialLocation: welcome,
      observers: [Modularity.observer],
      routes: routes(onComplete: onComplete),
    );
  }
}
