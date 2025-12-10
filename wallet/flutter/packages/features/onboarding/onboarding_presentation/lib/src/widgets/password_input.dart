import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Password input field with visibility toggle.
class PasswordInput extends StatefulWidget {
  /// Label for the field
  final String label;

  /// Hint text
  final String? hint;

  /// Current value
  final String value;

  /// Called when value changes
  final ValueChanged<String> onChanged;

  /// Error message to display
  final String? errorText;

  /// Whether to auto-focus
  final bool autofocus;

  /// Text input action
  final TextInputAction textInputAction;

  /// Called when submitted
  final VoidCallback? onSubmitted;

  const PasswordInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  late final TextEditingController _controller;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(PasswordInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: widget.label,
      textField: true,
      obscured: _obscureText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            autofocus: widget.autofocus,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
                tooltip: _obscureText ? 'Show password' : 'Hide password',
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadii.borderRadiusMd,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
