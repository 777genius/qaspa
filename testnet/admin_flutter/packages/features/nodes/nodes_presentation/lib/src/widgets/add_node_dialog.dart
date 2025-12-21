import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';

class AddNodeDialog extends StatefulWidget {
  final Future<void> Function(NodeConfig config) onAdd;

  const AddNodeDialog({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddNodeDialog> createState() => _AddNodeDialogState();
}

class _AddNodeDialogState extends State<AddNodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _role = 'peer';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Node'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Node Name',
                  hintText: 'e.g., peer-3',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AdminSpacing.md),
              Text(
                'Role',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: AdminSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'peer', label: Text('Peer')),
                  ButtonSegment(value: 'seed', label: Text('Seed')),
                ],
                selected: {_role},
                onSelectionChanged: (value) {
                  setState(() {
                    _role = value.firstOrNull ?? _role;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
    });

    // Capture navigator and messenger before async gap to avoid context issues
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.onAdd(NodeConfig(
        name: _nameController.text,
        role: _role,
      ));
      // Close dialog on success
      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to add node: $e'),
            backgroundColor: AdminColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
