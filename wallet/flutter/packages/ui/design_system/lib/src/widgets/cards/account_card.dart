import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/radii.dart';

/// Account selection card.
class AccountCard extends StatelessWidget {
  final Account account;
  final bool isSelected;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.account,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.cardTheme.color,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              _AccountIcon(kind: account.kind, isSelected: isSelected),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (account.balance != null) ...[
                      const SizedBox(height: AppSpacing.xxxs),
                      Text(
                        '${account.balance!.availableKas.toStringAsFixed(2)} KAS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountIcon extends StatelessWidget {
  final AccountKind kind;
  final bool isSelected;

  const _AccountIcon({required this.kind, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : AppColors.primary;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadii.borderRadiusSm,
      ),
      child: Icon(_getIcon(), color: color, size: 20),
    );
  }

  IconData _getIcon() {
    return switch (kind) {
      AccountKind.bip32 => Icons.account_balance_wallet_rounded,
      AccountKind.legacy => Icons.key_rounded,
      AccountKind.multisig => Icons.people_rounded,
      AccountKind.stealth => Icons.visibility_off_rounded,
      AccountKind.watchOnly => Icons.remove_red_eye_rounded,
      AccountKind.resident => Icons.security_rounded,
    };
  }
}
