import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:modularity_get_it/modularity_get_it.dart';

import 'src/app.dart';
import 'src/app_module.dart';

void main() {
  // Enable debug logging in development
  if (kDebugMode) {
    Modularity.enableDebugLogging();
  }

  runApp(const KaspaWalletApp());
}

/// Root widget of the Kaspa Wallet application.
class KaspaWalletApp extends StatelessWidget {
  const KaspaWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      binderFactory: const GetItBinderFactory(),
      child: ModuleScope<AppModule>(
        module: AppModule(),
        retentionPolicy: ModuleRetentionPolicy.strict,
        loadingBuilder: (context) => const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        errorBuilder: (context, error, retry) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: const App(),
      ),
    );
  }
}
