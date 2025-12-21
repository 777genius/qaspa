import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';

class AddMinerDialog extends StatefulWidget {
  final Future<void> Function(MinerConfig config) onAdd;

  const AddMinerDialog({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddMinerDialog> createState() => _AddMinerDialogState();
}

class _AddMinerDialogState extends State<AddMinerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetNodeController = TextEditingController(text: 'seed');
  final _payoutAddressController = TextEditingController();
  int _threads = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetNodeController.dispose();
    _payoutAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Miner'),
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
                  labelText: 'Miner Name',
                  hintText: 'e.g., miner-1',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AdminSpacing.md),
              TextFormField(
                controller: _targetNodeController,
                decoration: const InputDecoration(
                  labelText: 'Target Node',
                  hintText: 'Node to connect to',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter target node';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AdminSpacing.md),
              TextFormField(
                controller: _payoutAddressController,
                decoration: const InputDecoration(
                  labelText: 'Payout Address',
                  hintText: 'Kaspa address for rewards',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payout address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AdminSpacing.md),
              Text(
                'Threads: $_threads',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Slider(
                value: _threads.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: '$_threads',
                onChanged: (value) {
                  setState(() {
                    _threads = value.round();
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
      await widget.onAdd(MinerConfig(
        name: _nameController.text,
        targetNode: _targetNodeController.text,
        payoutAddress: _payoutAddressController.text,
        threads: _threads,
      ));
      // Close dialog on success
      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to add miner: $e'),
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
