import 'package:flutter/material.dart';

/// Search input field.
class SearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller?.text.isNotEmpty == true
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  controller?.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
              )
            : null,
      ),
      onChanged: onChanged,
    );
  }
}
