import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/onboarding_store.dart';

/// Success page shown after wallet creation/import.
class SuccessPage extends StatelessWidget {
  /// Callback to go to wallet home
  final VoidCallback onGoToWallet;

  const SuccessPage({
    super.key,
    required this.onGoToWallet,
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
              const SuccessContent(),
              const Spacer(flex: 3),
              SuccessActions(onGoToWallet: onGoToWallet),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Success content with animation.
class SuccessContent extends StatelessWidget {
  const SuccessContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    final isImport = store.flow == OnboardingFlow.import;
    final walletName = store.createdWallet?.name ?? 'Wallet';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.success.withValues(alpha: 0.3),
                AppColors.success.withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 72,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          isImport ? 'Wallet Imported!' : 'Wallet Created!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '"$walletName" is ready to use',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Observer(
          builder: (_) {
            final network = store.selectedNetwork;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    network.isTestnet
                        ? Icons.science_rounded
                        : Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    network.isTestnet ? 'Testnet' : 'Mainnet',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Action buttons on success page.
class SuccessActions extends StatelessWidget {
  final VoidCallback onGoToWallet;

  const SuccessActions({
    super.key,
    required this.onGoToWallet,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onGoToWallet,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Go to Wallet'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}
