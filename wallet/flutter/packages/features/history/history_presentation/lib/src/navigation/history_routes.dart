import 'package:design_system/design_system.dart';
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
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text('Failed to load history: $error'),
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
              // Validate hex format to prevent TransactionId.fromHex crash
              if (!RegExp(r'^[a-fA-F0-9]+$').hasMatch(transactionId)) {
                return const Scaffold(
                  body: Center(
                    child: Text('Invalid transaction ID format'),
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
