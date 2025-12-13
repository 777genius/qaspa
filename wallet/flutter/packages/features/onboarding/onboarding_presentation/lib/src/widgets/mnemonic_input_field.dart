import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Single mnemonic word input field with BIP-39 autocomplete.
class MnemonicInputField extends StatefulWidget {
  /// The word index (1-based) for display
  final int wordIndex;

  /// Current value of the field
  final String value;

  /// Called when value changes
  final ValueChanged<String> onChanged;

  /// Called when user submits (presses enter or selects suggestion)
  final VoidCallback? onSubmitted;

  /// Function to get word suggestions based on prefix
  final List<String> Function(String prefix) getSuggestions;

  /// Whether the field is read-only
  final bool readOnly;

  /// Whether the word is valid
  final bool? isValid;

  /// Whether to auto-focus this field
  final bool autofocus;

  /// Focus node for this field
  final FocusNode? focusNode;

  const MnemonicInputField({
    super.key,
    required this.wordIndex,
    required this.value,
    required this.onChanged,
    required this.getSuggestions,
    this.onSubmitted,
    this.readOnly = false,
    this.isValid,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<MnemonicInputField> createState() => _MnemonicInputFieldState();
}

class _MnemonicInputFieldState extends State<MnemonicInputField> {
  late final TextEditingController _controller;
  FocusNode? _internalFocusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _isDisposed = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _effectiveFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(MnemonicInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }

    // Handle focus node changes
    if (widget.focusNode != oldWidget.focusNode) {
      // Get the old effective node before any changes
      final oldEffectiveNode = oldWidget.focusNode ?? _internalFocusNode;

      // Remove listener from old effective node
      oldEffectiveNode?.removeListener(_onFocusChanged);

      // Create internal node if needed
      if (widget.focusNode == null && _internalFocusNode == null) {
        _internalFocusNode = FocusNode();
      }

      // Dispose internal node if we no longer need it (widget now provides one)
      if (widget.focusNode != null && _internalFocusNode != null) {
        _internalFocusNode!.dispose();
        _internalFocusNode = null;
      }

      // Add listener to new effective node (only once)
      _effectiveFocusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Hide overlay first before disposing
    _hideOverlay();
    _effectiveFocusNode.removeListener(_onFocusChanged);
    _internalFocusNode?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_isDisposed) return;
    if (_effectiveFocusNode.hasFocus) {
      _updateSuggestions(_controller.text);
    } else {
      _hideOverlay();
    }
  }

  void _onTextChanged(String text) {
    widget.onChanged(text.toLowerCase().trim());
    _updateSuggestions(text);
  }

  void _updateSuggestions(String text) {
    final trimmed = text.toLowerCase().trim();
    if (trimmed.isEmpty) {
      _hideOverlay();
      return;
    }

    _suggestions = widget.getSuggestions(trimmed);
    if (_suggestions.isEmpty) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_isDisposed || !mounted) return;

    // Store reference before hiding to avoid race condition
    final oldEntry = _overlayEntry;
    _overlayEntry = null;
    oldEntry?.remove();

    // Use maybeOf to safely get overlay, avoiding crash if context is invalid
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // Create and insert new entry
    final newEntry = _createOverlayEntry();
    if (newEntry == null) return;
    _overlayEntry = newEntry;
    overlay.insert(newEntry);
  }

  void _hideOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
  }

  void _selectSuggestion(String word) {
    _controller.text = word;
    widget.onChanged(word);
    _hideOverlay();
    widget.onSubmitted?.call();
  }

  OverlayEntry? _createOverlayEntry() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final size = renderObject.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: AppRadii.borderRadiusMd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(suggestion),
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color? borderColor;
    if (widget.isValid == true) {
      borderColor = AppColors.success;
    } else if (widget.isValid == false) {
      borderColor = AppColors.error;
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        label: 'Word ${widget.wordIndex}',
        textField: true,
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: _controller,
            focusNode: _effectiveFocusNode,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: _onTextChanged,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              prefixIcon: Container(
                width: 32,
                alignment: Alignment.center,
                child: Text(
                  '${widget.wordIndex}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: widget.isValid == true
                  ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                  : widget.isValid == false
                      ? const Icon(Icons.error, color: AppColors.error, size: 20)
                      : null,
              border: OutlineInputBorder(
                borderRadius: AppRadii.borderRadiusSm,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderRadiusSm,
                borderSide: BorderSide(
                  color: borderColor ?? theme.colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderRadiusSm,
                borderSide: BorderSide(
                  color: borderColor ?? theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
