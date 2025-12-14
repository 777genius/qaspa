import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

/// Amount input field for KAS values.
class AmountInput extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<double>? onChanged;
  final double? maxAmount;
  final String? errorText;
  final bool enabled;
  final VoidCallback? onMaxPressed;

  const AmountInput({
    super.key,
    this.controller,
    this.onChanged,
    this.maxAmount,
    this.errorText,
    this.enabled = true,
    this.onMaxPressed,
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value) {
    final amount = double.tryParse(value) ?? 0;
    widget.onChanged?.call(amount);
  }

  void _onMaxPressed() {
    final maxAmount = widget.maxAmount;
    if (maxAmount != null) {
      _controller.text = maxAmount.toStringAsFixed(8);
      _onChanged(_controller.text);
    }
    widget.onMaxPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = _controller.text.isEmpty ? '0' : _controller.text;
    final maxAmount = widget.maxAmount;
    final availableText = maxAmount != null
        ? 'Available: ${maxAmount.toStringAsFixed(2)} KAS'
        : null;

    return Semantics(
      label: 'Amount input: $currentValue KAS',
      hint: availableText,
      textField: true,
      enabled: widget.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}')),
            ],
            style: AppTypography.monoLarge,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: AppTypography.monoLarge.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: widget.maxAmount != null
                  ? Semantics(
                      button: true,
                      label: 'Use maximum amount',
                      child: TextButton(
                        onPressed: widget.enabled ? _onMaxPressed : null,
                        child: const Text('MAX'),
                      ),
                    )
                  : null,
              errorText: widget.errorText,
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: AppSpacing.xxxs),
          Center(
            child: ExcludeSemantics(
              child: Text(
                'KAS',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (widget.maxAmount != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Center(
              child: ExcludeSemantics(
                child: Text(
                  availableText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
