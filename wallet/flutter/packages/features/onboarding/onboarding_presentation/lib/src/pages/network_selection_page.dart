import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../stores/onboarding_store.dart';
import '../widgets/network_option_card.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/security_warning_card.dart';
import '../widgets/step_indicator.dart';

/// Page for selecting the network.
class NetworkSelectionPage extends StatelessWidget {
  /// Callback when wallet creation starts
  final VoidCallback onContinue;

  /// Callback when user wants to go back
  final VoidCallback onBack;

  const NetworkSelectionPage({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<OnboardingStore>();

    return OnboardingScaffold(
      title: 'Select Network',
      onBack: onBack,
      bottomActions: Observer(
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (store.errorMessage != null) ...[
              Text(
                store.errorMessage!,
                style: TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: store.isLoading
                    ? null
                    : () async {
                        await store.createWallet();
                        if (store.createdWallet != null) {
                          onContinue();
                        }
                      },
                child: store.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        store.flow == OnboardingFlow.create
                            ? 'Create Wallet'
                            : 'Import Wallet',
                      ),
              ),
            ),
          ],
        ),
      ),
      child: Observer(
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepIndicator(
              currentStep: store.currentStepNumber,
              totalSteps: store.totalSteps,
            ),
            const SizedBox(height: AppSpacing.xl),
            const NetworkSelectionHeader(),
            const SizedBox(height: AppSpacing.lg),
            NetworkOptionCard(
              networkId: NetworkId.mainnet,
              isSelected: store.selectedNetwork == NetworkId.mainnet,
              isRecommended: true,
              onTap: () => store.selectNetwork(NetworkId.mainnet),
            ),
            const SizedBox(height: AppSpacing.sm),
            NetworkOptionCard(
              networkId: NetworkId.testnet11,
              isSelected: store.selectedNetwork == NetworkId.testnet11,
              onTap: () => store.selectNetwork(NetworkId.testnet11),
            ),
            if (store.selectedNetwork != NetworkId.mainnet) ...[
              const SizedBox(height: AppSpacing.lg),
              SecurityWarningCard.testnetWarning(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Header for network selection.
class NetworkSelectionHeader extends StatelessWidget {
  const NetworkSelectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Network',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Select which Kaspa network to connect to.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
