import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../module/send_module.dart';
import '../pages/send_page.dart';

/// Route paths for send feature.
abstract final class SendRoutes {
  static const String basePath = '/send';
  static const String main = basePath;

  static List<RouteBase> routes() {
    return [
      ShellRoute(
        builder: (context, state, child) {
          return ModuleScope<SendModule>(
            module: SendModule(),
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
                    Text('Failed to load send: $error'),
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
            builder: (context, state) => const SendPage(),
          ),
        ],
      ),
    ];
  }
}
