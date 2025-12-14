import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../module/home_module.dart';
import '../pages/home_page.dart';

/// Route paths for home feature.
abstract final class HomeRoutes {
  static const String basePath = '/home';
  static const String main = basePath;

  /// Get all home routes for go_router configuration.
  static List<RouteBase> routes() {
    return [
      ShellRoute(
        builder: (context, state, child) {
          return ModuleScope<HomeModule>(
            module: HomeModule(),
            retentionPolicy: ModuleRetentionPolicy.keepAlive,
            loadingBuilder: (context) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            errorBuilder: (context, error, retry) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text('Failed to load home: $error'),
                    const SizedBox(height: AppSpacing.md),
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
            builder: (context, state) => const HomePage(),
          ),
        ],
      ),
    ];
  }
}
