import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Card for selecting a network (mainnet/testnet).
class NetworkOptionCard extends StatelessWidget {
  /// The network this card represents
  final NetworkId networkId;

  /// Whether this network is selected
  final bool isSelected;

  /// Called when card is tapped
  final VoidCallback onTap;

  /// Whether this is the recommended option
  final bool isRecommended;

  const NetworkOptionCard({
    super.key,
    required this.networkId,
    required this.isSelected,
    required this.onTap,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _getNetworkInfo(networkId);

    return Semantics(
      button: true,
      label: '${info.name} network${isRecommended ? ', recommended' : ''}',
      selected: isSelected,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderRadiusMd,
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                NetworkIcon(
                  networkId: networkId,
                  isSelected: isSelected,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            info.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: AppRadii.borderRadiusSm,
                              ),
                              child: Text(
                                'Recommended',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxxs),
                      Text(
                        info.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _NetworkInfo _getNetworkInfo(NetworkId networkId) {
    if (networkId == NetworkId.mainnet) {
      return const _NetworkInfo(
        name: 'Mainnet',
        description: 'Real KAS with actual value. Use for regular transactions.',
      );
    } else if (networkId == NetworkId.testnet10) {
      return const _NetworkInfo(
        name: 'Testnet 10',
        description: 'Test network with no real value. For development only.',
      );
    } else if (networkId == NetworkId.testnet11) {
      return const _NetworkInfo(
        name: 'Testnet 11',
        description: 'Test network with no real value. For development only.',
      );
    } else if (networkId == NetworkId.simnet) {
      return const _NetworkInfo(
        name: 'Simnet',
        description: 'Simulation network for local testing.',
      );
    } else if (networkId == NetworkId.devnet) {
      return const _NetworkInfo(
        name: 'Devnet',
        description: 'Development network for testing new features.',
      );
    } else {
      return _NetworkInfo(
        name: networkId.toString(),
        description: 'Custom network configuration.',
      );
    }
  }
}

class _NetworkInfo {
  final String name;
  final String description;

  const _NetworkInfo({
    required this.name,
    required this.description,
  });
}

/// Icon representing a network.
class NetworkIcon extends StatelessWidget {
  final NetworkId networkId;
  final bool isSelected;

  const NetworkIcon({
    super.key,
    required this.networkId,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMainnet = networkId.isMainnet;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isMainnet
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isMainnet
            ? Icons.account_balance_wallet_rounded
            : Icons.science_rounded,
        color: isMainnet ? AppColors.success : AppColors.warning,
        size: 24,
      ),
    );
  }
}
