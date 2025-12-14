import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../module/stealth_module.dart';
import '../pages/stealth_page.dart';
import '../pages/stealth_send_page.dart';
import '../pages/stealth_receive_page.dart';

/// Route paths for stealth (privacy) feature.
abstract final class StealthRoutes {
  static const String basePath = '/stealth';
  static const String main = basePath;
  static const String send = '$basePath/send';
  static const String receive = '$basePath/receive';

  static List<RouteBase> routes() {
    return [
      ShellRoute(
        builder: (context, state, child) {
          return ModuleScope<StealthModule>(
            module: StealthModule(),
            retentionPolicy: ModuleRetentionPolicy.routeBound,
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
                    Text('Failed to load stealth: $error'),
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
            builder: (context, state) => const StealthPage(),
          ),
          GoRoute(
            path: send,
            builder: (context, state) => const StealthSendPage(),
          ),
          GoRoute(
            path: receive,
            builder: (context, state) => const StealthReceivePage(),
          ),
        ],
      ),
    ];
  }
}
