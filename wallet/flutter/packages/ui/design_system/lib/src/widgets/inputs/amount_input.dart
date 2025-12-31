import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

/// Universal amount input field.
///
/// A text field optimized for numeric amount input with optional
/// currency display and max button.
///
/// Example:
/// ```dart
/// AmountInput(
///   currency: 'KAS',
///   availableAmount: '1,234.56',
///   onChanged: (value) => print(value),
/// )
/// ```
class AmountInput extends StatefulWidget {
  const AmountInput({
    super.key,
    this.controller,
    this.onChanged,
    this.currency,
    this.availableAmount,
    this.maxValue,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.onMaxPressed,
    this.decimalPlaces = 8,
  });

  final TextEditingController? controller;

  /// Called when value changes, returns raw string input
  final ValueChanged<String>? onChanged;

  /// Currency symbol to display (e.g., "KAS", "USD")
  final String? currency;

  /// Available amount to display as helper text (pre-formatted)
  final String? availableAmount;

  /// Max value to set when MAX button is pressed (pre-formatted)
  final String? maxValue;

  /// Error message to display
  final String? errorText;

  /// Custom helper text (overrides auto-generated from availableAmount)
  final String? helperText;

  final bool enabled;

  /// Called when MAX button is pressed
  final VoidCallback? onMaxPressed;

  /// Number of decimal places allowed
  final int decimalPlaces;

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
    widget.onChanged?.call(value);
  }

  void _onMaxPressed() {
    if (widget.maxValue != null) {
      _controller.text = widget.maxValue!;
      _onChanged(_controller.text);
    }
    widget.onMaxPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = _controller.text.isEmpty ? '0' : _controller.text;
    final currency = widget.currency ?? '';

    final effectiveHelperText = widget.helperText ??
        (widget.availableAmount != null
            ? 'Available: ${widget.availableAmount}${currency.isNotEmpty ? ' $currency' : ''}'
            : null);

    final decimalPattern = r'^\d*\.?\d{0,' + widget.decimalPlaces.toString() + r'}';

    return Semantics(
      label: 'Amount input: $currentValue${currency.isNotEmpty ? ' $currency' : ''}',
      hint: effectiveHelperText,
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
              FilteringTextInputFormatter.allow(RegExp(decimalPattern)),
            ],
            style: AppTypography.monoLarge,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: AppTypography.monoLarge.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: widget.maxValue != null
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
          if (widget.currency != null) ...[
            const SizedBox(height: AppSpacing.xxxs),
            Center(
              child: ExcludeSemantics(
                child: Text(
                  widget.currency!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (effectiveHelperText != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Center(
              child: ExcludeSemantics(
                child: Text(
                  effectiveHelperText,
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
