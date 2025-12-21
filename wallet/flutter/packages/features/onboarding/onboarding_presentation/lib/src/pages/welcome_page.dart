import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';

/// Welcome page - entry point for onboarding.
///
/// Shows two options:
/// - Create new wallet
/// - Import existing wallet
class WelcomePage extends StatelessWidget {
  /// Callback when user selects create wallet
  final VoidCallback onCreateWallet;

  /// Callback when user selects import wallet
  final VoidCallback onImportWallet;

  const WelcomePage({
    super.key,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const WelcomeHeader(),
              const Spacer(flex: 3),
              WelcomeActions(
                onCreateWallet: onCreateWallet,
                onImportWallet: onImportWallet,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header section with logo and welcome text.
class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.kaspaGreen,
                AppColors.kaspaTeal,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 48,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Welcome to Kaspa',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The fastest, most scalable\nlayer-1 blockchain',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Action buttons section.
class WelcomeActions extends StatelessWidget {
  final VoidCallback onCreateWallet;
  final VoidCallback onImportWallet;

  const WelcomeActions({
    super.key,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              store.selectFlow(OnboardingFlow.create);
              onCreateWallet();
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Create New Wallet'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              store.selectFlow(OnboardingFlow.import);
              onImportWallet();
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Import Existing Wallet'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
