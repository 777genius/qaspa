import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens/spacing.dart';
import '../../tokens/radii.dart';

/// PIN input widget for password entry.
class PinInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool autofocus;
  final String? errorText;

  const PinInput({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.obscureText = true,
    this.autofocus = true,
    this.errorText,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<FocusNode> _keyboardListenerNodes;
  String _pin = '';

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _keyboardListenerNodes = List.generate(widget.length, (_) => FocusNode());

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    // Unfocus before dispose to properly release keyboard focus
    for (final node in _focusNodes) {
      node.unfocus();
      node.dispose();
    }
    for (final node in _keyboardListenerNodes) {
      node.unfocus();
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      final chars = value.split('');
      for (var i = 0; i < chars.length && index + i < widget.length; i++) {
        _controllers[index + i].text = chars[i];
      }
      final nextIndex = (index + chars.length).clamp(0, widget.length - 1);
      _focusNodes[nextIndex].requestFocus();
    } else if (value.isNotEmpty) {
      // Single character
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }

    _updatePin();
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _updatePin();
    }
  }

  void _updatePin() {
    _pin = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(_pin);

    if (_pin.length == widget.length) {
      widget.onCompleted?.call(_pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxs),
              child: SizedBox(
                width: 48,
                height: 56,
                child: KeyboardListener(
                  focusNode: _keyboardListenerNodes[index],
                  onKeyEvent: (event) => _onKeyEvent(index, event),
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    obscureText: widget.obscureText,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: theme.textTheme.headlineMedium,
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadii.borderRadiusSm,
                        borderSide: BorderSide(
                          color: hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadii.borderRadiusSm,
                        borderSide: BorderSide(
                          color: hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onChanged: (value) => _onChanged(index, value),
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
