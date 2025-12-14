import 'dart:developer' as developer;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/send_store.dart';

/// Send transaction page.
class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final store = ModuleProvider.of(context).get<SendStore>();
        // TODO: Get actual account ID from wallet state
        store.setAccountId('default');
      } catch (e) {
        developer.log(
          'SendPage initState error',
          error: e,
          name: 'SendPage',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<SendStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Send KAS')),
      body: Observer(
        builder: (_) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Recipient Address',
                  hintText: 'kaspa:...',
                  counterText: '',
                  errorText: store.recipientAddress.isNotEmpty && !store.isAddressValid
                      ? 'Invalid Kaspa address'
                      : null,
                ),
                maxLength: 80,
                onChanged: (value) => store.setRecipientAddress(value.trim()),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  suffixText: 'KAS',
                  errorText: store.amount.isNotEmpty && !store.isAmountValid
                      ? 'Enter a valid amount greater than 0'
                      : null,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => store.setAmount(value.trim()),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (store.estimatedFee != null)
                Text('Estimated fee: ${store.estimatedFee} sompi'),
              if (store.errorMessage != null)
                Text(
                  store.errorMessage!,
                  style: TextStyle(color: AppColors.error),
                ),
              const Spacer(),
              FilledButton(
                onPressed: store.canSend
                    ? () => _showPasswordDialog(context, store)
                    : null,
                child: store.isSending
                    ? const CircularProgressIndicator()
                    : const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, SendStore store) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Observer(
        builder: (_) => AlertDialog(
          title: const Text('Confirm Transaction'),
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
                      if (passwordController.text.trim().isEmpty) return;

                      try {
                        // Pass password directly to avoid keeping reference
                        await store.sendTransaction(
                          password: passwordController.text,
                        );
                      } finally {
                        // Always clear password from memory immediately
                        passwordController.clear();
                      }

                      if (!dialogContext.mounted) return;

                      if (store.sentTransactionId != null) {
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transaction sent!')),
                          );
                          Navigator.pop(context);
                        }
                      } else if (store.errorMessage != null) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Error: ${store.errorMessage}')),
                          );
                        }
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
