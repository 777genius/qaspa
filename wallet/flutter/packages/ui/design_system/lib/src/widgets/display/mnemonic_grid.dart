import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens/spacing.dart';
import 'mnemonic_word_chip.dart';

/// Grid display for mnemonic words.
class MnemonicGrid extends StatelessWidget {
  final List<String> words;
  final bool isHidden;
  final int columns;
  final bool showCopyButton;
  final ValueChanged<int>? onWordTap;

  const MnemonicGrid({
    super.key,
    required this.words,
    this.isHidden = false,
    this.columns = 3,
    this.showCopyButton = true,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.xxs,
            mainAxisSpacing: AppSpacing.xxs,
            childAspectRatio: 2.5,
          ),
          itemCount: words.length,
          itemBuilder: (context, index) {
            return MnemonicWordChip(
              key: ValueKey('word_$index'),
              index: index + 1,
              word: words[index],
              isHidden: isHidden,
              onTap: onWordTap != null ? () => onWordTap!(index) : null,
            );
          },
        ),
        if (showCopyButton && !isHidden) ...[
          const SizedBox(height: AppSpacing.sm),
          _CopyAllButton(words: words),
        ],
      ],
    );
  }
}

class _CopyAllButton extends StatefulWidget {
  final List<String> words;

  const _CopyAllButton({required this.words});

  @override
  State<_CopyAllButton> createState() => _CopyAllButtonState();
}

class _CopyAllButtonState extends State<_CopyAllButton> {
  bool _copied = false;
  Timer? _resetTimer;
  bool _hasCopied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    // Security: Clear clipboard if mnemonic was copied
    if (_hasCopied) {
      Clipboard.setData(const ClipboardData(text: ''));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton.icon(
      onPressed: _copyToClipboard,
      icon: Icon(
        _copied ? Icons.check_rounded : Icons.copy_rounded,
        size: 18,
      ),
      label: Text(_copied ? 'Copied!' : 'Copy all words'),
      style: TextButton.styleFrom(
        foregroundColor: _copied
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.words.join(' ')));
    _hasCopied = true;
    setState(() => _copied = true);

    // Cancel any existing timer and start a new one
    _resetTimer?.cancel();
    // Security: Clear clipboard after 10 seconds (mnemonic is sensitive)
    _resetTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _copied = false);
        Clipboard.setData(const ClipboardData(text: ''));
        _hasCopied = false;
      }
    });
  }
}
