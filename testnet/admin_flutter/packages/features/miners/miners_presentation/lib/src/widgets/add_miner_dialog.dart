import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import 'package:miners_presentation/src/widgets/miner_target_node_field.dart';

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
  static const _maxNameLength = 64;
  static const _maxThreads = 128;
  static const _minTargetBps = 0.1;
  static const _maxTargetBps = 100.0;
  static const _namePattern = r'^[a-zA-Z0-9-]*$';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetNodeController = TextEditingController();
  final _payoutAddressController = TextEditingController();
  final _threadsController = TextEditingController(text: '1');
  final _targetBpsController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;
  List<NodeInstance> _nodes = [];
  NetworkInfo? _networkInfo;
  String? _loadError;
  String? _submitError;
  NodeInstance? _selectedNode;
  bool _useTargetBps = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final nodeRepo = GetIt.instance<NodeRepository>();
      final clusterRepo = GetIt.instance<ClusterRepository>();

      // Load nodes and network info in parallel
      final results = await Future.wait([
        nodeRepo.getNodes(),
        clusterRepo.getNetworkInfo(),
      ]);

      final nodes = results[0] as List<NodeInstance>;
      final networkInfo = results[1] as NetworkInfo;

      if (mounted) {
        // Sort: running first, then by name
        nodes.sort((a, b) {
          if (a.isRunning && !b.isRunning) return -1;
          if (!a.isRunning && b.isRunning) return 1;
          return a.name.compareTo(b.name);
        });

        setState(() {
          _nodes = nodes;
          _networkInfo = networkInfo;
          _isLoadingData = false;

          // Set default address based on network type
          _payoutAddressController.text = networkInfo.defaultAddress;

          // Auto-select first running node, or first node if none running
          final runningNode = nodes.where((n) => n.isRunning).firstOrNull;
          final firstNode = runningNode ?? nodes.firstOrNull;
          if (firstNode != null) {
            _targetNodeController.text = firstNode.id;
            _selectedNode = firstNode;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetNodeController.dispose();
    _payoutAddressController.dispose();
    _threadsController.dispose();
    _targetBpsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline, size: 24),
          SizedBox(width: AdminSpacing.sm),
          Text('Add Miner'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner
                if (_submitError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AdminSpacing.sm),
                    decoration: BoxDecoration(
                      color: AdminColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AdminColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: Text(
                            _submitError!,
                            style: const TextStyle(color: AdminColors.error),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _submitError = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.md),
                ],

                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Miner Name',
                    hintText: 'e.g., miner-1',
                    prefixIcon: Icon(Icons.label_outline),
                    helperText: 'Optional. Auto-generated if empty.',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (value.length > _maxNameLength) {
                      return 'Max $_maxNameLength characters';
                    }
                    if (!RegExp(_namePattern).hasMatch(value)) {
                      return 'Only letters, numbers, and hyphens';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AdminSpacing.lg),

                // Target Node field
                MinerTargetNodeField(
                  isLoading: _isLoadingData,
                  loadError: _loadError,
                  nodes: _nodes,
                  selectedNode: _selectedNode,
                  onRetry: () {
                    setState(() {
                      _isLoadingData = true;
                      _loadError = null;
                    });
                    _loadData();
                  },
                  onNodeSelected: (node) {
                    _targetNodeController.text = node.id;
                    setState(() => _selectedNode = node);
                  },
                ),
                const SizedBox(height: AdminSpacing.lg),

                // Payout Address field
                TextFormField(
                  controller: _payoutAddressController,
                  decoration: InputDecoration(
                    labelText: 'Payout Address',
                    hintText: '${_networkInfo?.addressPrefix ?? 'kaspa:'}...',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy address',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: _payoutAddressController.text,
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.paste, size: 20),
                          tooltip: 'Paste from clipboard',
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              _payoutAddressController.text = data!.text!;
                            }
                          },
                        ),
                      ],
                    ),
                    helperText: _networkInfo != null
                        ? '${_networkInfo!.networkType.displayName} address for mining rewards'
                        : 'Loading network info...',
                  ),
                  validator: (value) {
                    if (_networkInfo == null) {
                      return 'Loading network info...';
                    }
                    return _networkInfo!.validateAddress(value);
                  },
                ),
                const SizedBox(height: AdminSpacing.lg),

                // Threads field
                TextFormField(
                  controller: _threadsController,
                  decoration: const InputDecoration(
                    labelText: 'Threads',
                    hintText: '1',
                    prefixIcon: Icon(Icons.memory),
                    helperText: 'Number of mining threads (1-128)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final threads = int.tryParse(value);
                    if (threads == null) {
                      return 'Invalid number';
                    }
                    if (threads < 1 || threads > _maxThreads) {
                      return 'Must be 1-$_maxThreads';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AdminSpacing.md),

                // Target BPS toggle
                SwitchListTile(
                  title: const Text('Rate Limit'),
                  subtitle: const Text('Limit blocks per second'),
                  value: _useTargetBps,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => setState(() => _useTargetBps = value),
                ),

                // Target BPS field (conditional)
                if (_useTargetBps) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  TextFormField(
                    controller: _targetBpsController,
                    decoration: const InputDecoration(
                      labelText: 'Target BPS',
                      hintText: '1.0',
                      prefixIcon: Icon(Icons.speed),
                      helperText: 'Target blocks per second (0.1-100)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!_useTargetBps) return null;
                      if (value == null || value.isEmpty) {
                        return 'Required when rate limit is enabled';
                      }
                      final bps = double.tryParse(value);
                      if (bps == null) {
                        return 'Invalid number';
                      }
                      if (bps < _minTargetBps || bps > _maxTargetBps) {
                        return 'Must be $_minTargetBps-$_maxTargetBps';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isLoading || _isLoadingData ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.add, size: 18),
          label: Text(_isLoading ? 'Adding...' : 'Add Miner'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);

    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);

    try {
      final name = _nameController.text.trim();
      final targetBps = _useTargetBps && _targetBpsController.text.isNotEmpty
          ? double.tryParse(_targetBpsController.text)
          : null;

      await widget.onAdd(MinerConfig(
        name: name.isEmpty ? null : name,
        targetNode: _targetNodeController.text,
        payoutAddress: _payoutAddressController.text.trim(),
        threads: int.parse(_threadsController.text),
        targetBps: targetBps,
      ));

      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
