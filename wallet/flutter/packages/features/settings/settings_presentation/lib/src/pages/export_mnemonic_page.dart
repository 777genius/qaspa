import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/settings_store.dart';

/// Page to export wallet mnemonic phrase.
class ExportMnemonicPage extends StatefulWidget {
  const ExportMnemonicPage({super.key});

  @override
  State<ExportMnemonicPage> createState() => _ExportMnemonicPageState();
}

class _ExportMnemonicPageState extends State<ExportMnemonicPage> {
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<SettingsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Export Recovery Phrase')),
      body: Observer(
        builder: (_) {
          if (store.exportedMnemonic != null) {
            return _MnemonicDisplay(
              mnemonic: store.exportedMnemonic!,
              onDone: () {
                store.clearExportedMnemonic();
                Navigator.pop(context);
              },
            );
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Card(
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Never share your recovery phrase with anyone. Store it securely.',
                                style: TextStyle(
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  maxLength: 128,
                  decoration: InputDecoration(
                    labelText: 'Enter Password',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                    ),
                  ),
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
                  onPressed: store.isProcessing
                      ? null
                      : () {
                          final password = _passwordController.text.trim();
                          if (password.isEmpty) return;
                          store.exportMnemonic(password: password);
                        },
                  child: store.isProcessing
                      ? const CircularProgressIndicator()
                      : const Text('Show Recovery Phrase'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MnemonicDisplay extends StatefulWidget {
  final String mnemonic;
  final VoidCallback onDone;

  const _MnemonicDisplay({
    required this.mnemonic,
    required this.onDone,
  });

  @override
  State<_MnemonicDisplay> createState() => _MnemonicDisplayState();
}

class _MnemonicDisplayState extends State<_MnemonicDisplay> {
  Timer? _clipboardClearTimer;
  bool _copied = false;

  /// Clipboard clear timeout - 10 seconds for security
  static const _clipboardClearTimeout = Duration(seconds: 10);

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    // Clear clipboard on dispose for security
    Clipboard.setData(const ClipboardData(text: ''));
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.mnemonic));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard (auto-clears in 10s)'),
      ),
    );

    // Cancel any existing timer
    _clipboardClearTimer?.cancel();
    // Auto-clear clipboard after timeout for security
    _clipboardClearTimer = Timer(_clipboardClearTimeout, () {
      Clipboard.setData(const ClipboardData(text: ''));
      if (mounted) {
        setState(() => _copied = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard cleared')),
        );
      }
    });
  }

  void _clearClipboardNow() {
    _clipboardClearTimer?.cancel();
    Clipboard.setData(const ClipboardData(text: ''));
    if (mounted) {
      setState(() => _copied = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.mnemonic.split(' ');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Write down these words in order and store them safely.',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: words.length,
              itemBuilder: (context, index) {
                return Card(
                  child: Center(
                    child: Text(
                      '${index + 1}. ${words[index]}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              if (_copied) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearClipboardNow,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: widget.onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
