import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/receive_store.dart';

/// Receive KAS page with QR code and address display.
class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  Timer? _clipboardClearTimer;

  /// Clipboard clear timeout for address (less sensitive than mnemonic).
  static const _clipboardClearTimeout = Duration(seconds: 60);

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final store = ModuleProvider.of(context).get<ReceiveStore>();
        // TODO: Get actual account ID from wallet state
        store.setAccountId('default');
      } catch (e) {
        debugPrint('ReceivePage initState error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<ReceiveStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Receive KAS')),
      body: Observer(
        builder: (_) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (store.errorMessage != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(store.errorMessage!),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: store.loadAddress,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (store.currentAddress != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: const Center(
                    child: Icon(Icons.qr_code_2, size: 200),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: SelectableText(
                    store.currentAddress!.value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: store.currentAddress!.value),
                          );
                          store.setAddressCopied(true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied (auto-clears in 60s)'),
                              ),
                            );
                          }
                          // Cancel any existing timer and start new one
                          _clipboardClearTimer?.cancel();
                          _clipboardClearTimer = Timer(_clipboardClearTimeout, () {
                            Clipboard.setData(const ClipboardData(text: ''));
                          });
                        },
                        icon: Icon(
                          store.addressCopied ? Icons.check : Icons.copy,
                        ),
                        label: Text(store.addressCopied ? 'Copied' : 'Copy'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement share functionality
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: store.generateNewAddress,
                  child: const Text('Generate New Address'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
