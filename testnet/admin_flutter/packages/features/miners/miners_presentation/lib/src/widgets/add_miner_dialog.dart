import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

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
                _buildTargetNodeField(),
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
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add, size: 18),
          label: Text(_isLoading ? 'Adding...' : 'Add Miner'),
        ),
      ],
    );
  }

  Widget _buildTargetNodeField() {
    if (_isLoadingData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AdminSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AdminSpacing.sm),
            Text('Loading nodes...'),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(AdminSpacing.sm),
        decoration: BoxDecoration(
          color: AdminColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AdminColors.error, size: 20),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: Text(
                'Failed to load data: $_loadError',
                style: const TextStyle(color: AdminColors.error, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoadingData = true;
                  _loadError = null;
                });
                _loadData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_nodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AdminSpacing.sm),
        decoration: BoxDecoration(
          color: AdminColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: AdminColors.warning, size: 20),
            SizedBox(width: AdminSpacing.sm),
            Text(
              'No nodes available. Create a node first.',
              style: TextStyle(color: AdminColors.warning),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<NodeInstance>(
          initialValue: TextEditingValue(text: _selectedNode?.name ?? ''),
          displayStringForOption: (node) => node.name,
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return _nodes;
            final query = textEditingValue.text.toLowerCase();
            return _nodes.where(
              (node) => node.name.toLowerCase().contains(query),
            );
          },
          onSelected: (node) {
            _targetNodeController.text = node.id;
            setState(() => _selectedNode = node);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Target Node',
                hintText: 'Select node',
                prefixIcon: const Icon(Icons.dns_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                helperText:
                    '${_nodes.where((n) => n.isRunning).length} running of ${_nodes.length} nodes',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (!_nodes.any((n) => n.name == value)) {
                  return 'Select a valid node';
                }
                return null;
              },
              onChanged: (value) {
                final node =
                    _nodes.where((n) => n.name == value).firstOrNull;
                if (node != null) {
                  _targetNodeController.text = node.id;
                  setState(() => _selectedNode = node);
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 418,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final node = options.elementAt(index);
                      final isSelected = _selectedNode?.id == node.id;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        leading: Icon(
                          node.isRunning
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: node.isRunning
                              ? AdminColors.success
                              : AdminColors.stopped,
                          size: 20,
                        ),
                        title: Text(
                          node.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${node.role} • ${node.status}${node.isSynced ? ' • synced' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Text(
                          'P2P:${node.p2pPort}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => onSelected(node),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        // Warning if selected node is not running
        if (_selectedNode != null && !_selectedNode!.isRunning) ...[
          const SizedBox(height: AdminSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.sm,
              vertical: AdminSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AdminColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AdminColors.warning,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  'Node is not running',
                  style: TextStyle(
                    color: AdminColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
