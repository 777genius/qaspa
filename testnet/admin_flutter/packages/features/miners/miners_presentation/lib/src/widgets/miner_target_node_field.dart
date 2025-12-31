import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';

class MinerTargetNodeField extends StatelessWidget {
  final bool isLoading;
  final String? loadError;
  final List<NodeInstance> nodes;
  final NodeInstance? selectedNode;
  final VoidCallback onRetry;
  final ValueChanged<NodeInstance> onNodeSelected;

  const MinerTargetNodeField({
    super.key,
    required this.isLoading,
    required this.loadError,
    required this.nodes,
    required this.selectedNode,
    required this.onRetry,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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

    if (loadError != null) {
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
                'Failed to load data: $loadError',
                style: const TextStyle(color: AdminColors.error, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (nodes.isEmpty) {
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
          initialValue: TextEditingValue(text: selectedNode?.name ?? ''),
          displayStringForOption: (node) => node.name,
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return nodes;
            final query = textEditingValue.text.toLowerCase();
            return nodes.where(
              (node) => node.name.toLowerCase().contains(query),
            );
          },
          onSelected: onNodeSelected,
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
                    '${nodes.where((n) => n.isRunning).length} running of ${nodes.length} nodes',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (!nodes.any((n) => n.name == value)) {
                  return 'Select a valid node';
                }
                return null;
              },
              onChanged: (value) {
                final node = nodes.where((n) => n.name == value).firstOrNull;
                if (node != null) {
                  onNodeSelected(node);
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
                      final isSelected = selectedNode?.id == node.id;
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
        if (selectedNode != null && !selectedNode!.isRunning) ...[
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
}







