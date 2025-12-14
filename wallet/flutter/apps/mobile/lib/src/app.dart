import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:history_presentation/history_presentation.dart';
import 'package:home_presentation/home_presentation.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:onboarding_presentation/onboarding_presentation.dart';
import 'package:receive_presentation/receive_presentation.dart';
import 'package:send_presentation/send_presentation.dart';
import 'package:settings_presentation/settings_presentation.dart';
import 'package:stealth_presentation/stealth_presentation.dart';

/// Main app widget with router configuration.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: OnboardingRoutes.welcome,
      observers: [Modularity.observer],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(HomeRoutes.main),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
      routes: [
        ...OnboardingRoutes.routes(
          onComplete: () => _navigateToHome(context),
        ),
        ...HomeRoutes.routes(),
        ...SendRoutes.routes(),
        ...ReceiveRoutes.routes(),
        ...HistoryRoutes.routes(),
        ...SettingsRoutes.routes(),
        ...StealthRoutes.routes(),
      ],
    );

    return MaterialApp.router(
      title: 'Kaspa Wallet',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  void _navigateToHome(BuildContext context) {
    GoRouter.of(context).go(HomeRoutes.main);
  }
}
