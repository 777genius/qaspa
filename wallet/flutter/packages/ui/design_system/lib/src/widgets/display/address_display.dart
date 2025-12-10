import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens/spacing.dart';
import '../../tokens/radii.dart';
import '../../tokens/typography.dart';

/// Address display widget with copy functionality.
class AddressDisplay extends StatefulWidget {
  final String address;
  final bool showFull;
  final bool showCopyButton;
  final VoidCallback? onTap;

  const AddressDisplay({
    super.key,
    required this.address,
    this.showFull = false,
    this.showCopyButton = true,
    this.onTap,
  });

  @override
  State<AddressDisplay> createState() => _AddressDisplayState();
}

class _AddressDisplayState extends State<AddressDisplay> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  String get _displayAddress {
    if (widget.showFull) return widget.address;
    final parts = widget.address.split(':');
    if (parts.length != 2) return widget.address;
    final prefix = parts[0];
    final payload = parts[1];
    if (payload.length <= 16) return widget.address;
    return '$prefix:${payload.substring(0, 8)}...${payload.substring(payload.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: _copied ? 'Address copied' : 'Wallet address: $_displayAddress',
      hint: widget.showCopyButton ? 'Double tap to copy' : null,
      button: widget.showCopyButton || widget.onTap != null,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.borderRadiusSm,
        child: InkWell(
          onTap: widget.onTap ?? _copyAddress,
          borderRadius: AppRadii.borderRadiusSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _displayAddress,
                    style: AppTypography.mono.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.showCopyButton) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                    color: _copied
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: widget.address));
    setState(() => _copied = true);

    // Cancel any existing timer and start a new one
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }
}
