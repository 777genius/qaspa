import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../module/history_module.dart';
import '../pages/history_page.dart';
import '../pages/transaction_details_page.dart';

/// Route paths for history feature.
abstract final class HistoryRoutes {
  static const String basePath = '/history';
  static const String main = basePath;
  static const String details = '$basePath/details/:transactionId';

  static List<RouteBase> routes() {
    return [
      ShellRoute(
        builder: (context, state, child) {
          return ModuleScope<HistoryModule>(
            module: HistoryModule(),
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
                    Text('Failed to load history: $error'),
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
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: details,
            builder: (context, state) {
              final transactionId = state.pathParameters['transactionId'];
              if (transactionId == null || transactionId.isEmpty) {
                return const Scaffold(
                  body: Center(
                    child: Text('Transaction ID not found'),
                  ),
                );
              }
              return TransactionDetailsPage(transactionId: transactionId);
            },
          ),
        ],
      ),
    ];
  }
}
