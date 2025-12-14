import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/stealth_store.dart';

/// Page to send stealth (private) payment.
class StealthSendPage extends StatelessWidget {
  const StealthSendPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<StealthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Send Private Payment')),
      body: Observer(
        builder: (_) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Private payments hide the amount and recipient on the blockchain.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Recipient Stealth Address',
                  hintText: 'qs:... / qstest:...',
                ),
                onChanged: store.setRecipientStealthAddress,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  suffixText: 'KAS',
                  helperText: 'Available: ${store.stealthBalanceInKas.toStringAsFixed(8)} KAS',
                ),
                keyboardType: TextInputType.number,
                onChanged: store.setSendAmount,
              ),
              if (store.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  store.errorMessage!,
                  style: TextStyle(color: AppColors.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: store.canSend
                    ? () => _showPasswordDialog(context, store)
                    : null,
                child: store.isSending
                    ? const CircularProgressIndicator()
                    : const Text('Send Private Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, StealthStore store) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Observer(
        builder: (_) => AlertDialog(
          title: const Text('Confirm Private Payment'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            maxLength: 128,
            enabled: !store.isSending,
            decoration: const InputDecoration(
              labelText: 'Password',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: store.isSending
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: store.isSending
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) return;

                      Object? result;
                      try {
                        // Pass password directly to avoid keeping reference
                        result = await store.sendStealthPayment(
                          password: passwordController.text,
                        );
                      } finally {
                        // Always clear password from memory immediately
                        passwordController.clear();
                      }

                      if (!dialogContext.mounted) return;

                      if (result != null) {
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Private payment sent')),
                          );
                          Navigator.pop(context);
                        }
                      } else if (store.errorMessage != null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Error: ${store.errorMessage}')),
                        );
                      }
                    },
              child: store.isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
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
