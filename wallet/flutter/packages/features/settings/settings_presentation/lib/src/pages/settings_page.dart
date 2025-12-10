import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../navigation/settings_routes.dart';
import '../stores/settings_store.dart';

/// Main settings page.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<SettingsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Observer(
        builder: (_) {
          if (store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              _SettingsSection(
                title: 'Security',
                children: [
                  _SettingsTile(
                    icon: Icons.key,
                    title: 'Export Recovery Phrase',
                    subtitle: 'Back up your wallet',
                    onTap: () => context.push(SettingsRoutes.exportMnemonic),
                  ),
                  _SettingsTile(
                    icon: Icons.lock,
                    title: 'Change Password',
                    subtitle: 'Update your wallet password',
                    onTap: () => context.push(SettingsRoutes.changePassword),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsSection(
                title: 'Network',
                children: [
                  _SettingsTile(
                    icon: Icons.wifi,
                    title: 'Network',
                    subtitle: store.wallet?.network.toString() ?? 'Mainnet',
                    onTap: () {
                      // TODO: Implement network selection
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsSection(
                title: 'About',
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Version',
                    subtitle: '1.0.0',
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton(
                onPressed: () => _showDeleteWalletDialog(context, store),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                ),
                child: const Text('Delete Wallet'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteWalletDialog(BuildContext context, SettingsStore store) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Observer(
        builder: (_) => AlertDialog(
          title: const Text('Delete Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone. Make sure you have backed up your recovery phrase.',
                style: TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: passwordController,
                obscureText: true,
                enabled: !store.isProcessing,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: store.isProcessing
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: store.isProcessing
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.isEmpty) return;

                      try {
                        final success = await store.deleteWallet(password: password);

                        // Check mounted before any UI updates
                        if (!dialogContext.mounted) return;

                        if (success) {
                          Navigator.pop(dialogContext);
                          if (context.mounted) {
                            context.go('/onboarding/welcome');
                          }
                        }
                      } finally {
                        // Always clear password from memory for security
                        passwordController.clear();
                      }
                    },
              child: store.isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    ).then((_) {
      passwordController.clear();
      passwordController.dispose();
    });
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
