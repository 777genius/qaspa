import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/stealth_store.dart';

/// Page to receive stealth (private) payment.
class StealthReceivePage extends StatefulWidget {
  const StealthReceivePage({super.key});

  @override
  State<StealthReceivePage> createState() => _StealthReceivePageState();
}

class _StealthReceivePageState extends State<StealthReceivePage> {
  Timer? _clipboardClearTimer;

  /// Clipboard clear timeout for address (less sensitive than mnemonic).
  static const _clipboardClearTimeout = Duration(seconds: 60);

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<StealthStore>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Private Payment')),
      body: Observer(
        builder: (_) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Share this stealth address to receive private payments.',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
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
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: SelectableText(
                  store.stealthAddress?.value ?? 'Loading...',
                  style: textTheme.bodySmall?.copyWith(
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
                      onPressed: store.stealthAddress != null
                          ? () async {
                              await Clipboard.setData(
                                ClipboardData(text: store.stealthAddress!.value),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Stealth address copied (auto-clears in 60s)'),
                                ),
                              );
                              // Cancel any existing timer and start new one
                              _clipboardClearTimer?.cancel();
                              _clipboardClearTimer = Timer(_clipboardClearTimeout, () {
                                if (mounted) {
                                  Clipboard.setData(const ClipboardData(text: ''));
                                }
                              });
                            }
                          : null,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
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
              FilledButton.icon(
                onPressed: store.isScanning ? null : store.scanForPayments,
                icon: store.isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  store.isScanning ? 'Scanning...' : 'Scan for Incoming Payments',
                ),
              ),
              if (store.isScanning && store.scanTotal > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: store.scanProgress / store.scanTotal,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${store.scanProgress} / ${store.scanTotal} blocks',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
