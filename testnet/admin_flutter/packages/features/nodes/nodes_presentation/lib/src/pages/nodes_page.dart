import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:mobx/mobx.dart';

import '../module/nodes_module.dart';
import '../stores/nodes_store.dart';
import '../widgets/node_card.dart';
import '../widgets/add_node_dialog.dart';

class NodesPage extends StatefulWidget {
  const NodesPage({super.key});

  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = NodesModule.init();
  }

  @override
  void dispose() {
    NodesModule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Initializing nodes...');
        }

        if (snapshot.hasError) {
          return ErrorView(
            title: 'Failed to initialize',
            message: snapshot.error.toString(),
            onRetry: () {
              if (mounted) {
                setState(() {
                  _initFuture = NodesModule.init();
                });
              }
            },
          );
        }

        return const _NodesContent();
      },
    );
  }
}

class _NodesContent extends StatefulWidget {
  const _NodesContent();

  @override
  State<_NodesContent> createState() => _NodesContentState();
}

class _NodesContentState extends State<_NodesContent> {
  late final NodesStore _store;
  ReactionDisposer? _errorReaction;

  @override
  void initState() {
    super.initState();
    _store = GetIt.instance<NodesStore>();

    // React to operationError changes and show SnackBar
    _errorReaction = reaction(
      (_) => _store.operationError,
      (String? error) {
        if (error != null && mounted) {
          // Use try-catch to handle case when context is destroyed
          // during async gap between mounted check and showSnackBar
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AdminColors.error,
              ),
            );
          } on FlutterError {
            // Context was destroyed - ignore
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _errorReaction?.call();
    super.dispose();
  }

  /// Wrapper for async node operations with error handling
  void _handleNodeOperation(Future<void> Function() operation) {
    operation().catchError((Object e, StackTrace stack) {
      // Error is already captured in store.operationError via reaction
      // This catchError prevents unhandled exception
      // Log for debugging purposes
      debugPrint('Node operation failed: $e\n$stack');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (_store.isLoading && !_store.hasNodes) {
          return const LoadingIndicator(message: 'Loading nodes...');
        }

        if (_store.error != null && !_store.hasNodes) {
          return ErrorView(
            title: 'Failed to load nodes',
            message: _store.error,
            onRetry: _store.refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _store.refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nodes',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AdminSpacing.xs),
                          Text(
                            '${_store.runningCount} running, ${_store.stoppedCount} stopped',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddNodeDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Node'),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_store.hasNodes)
                SliverFillRemaining(
                  child: EmptyState(
                    title: 'No nodes yet',
                    message: 'Add a node to get started with your testnet',
                    icon: Icons.dns_outlined,
                    action: ElevatedButton.icon(
                      onPressed: () => _showAddNodeDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Node'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.lg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final node = _store.nodes[index];
                        return Padding(
                          key: ValueKey(node.id),
                          padding:
                              const EdgeInsets.only(bottom: AdminSpacing.md),
                          child: NodeCard(
                            node: node,
                            onStart: () => _handleNodeOperation(
                              () => _store.startNode(node.id),
                            ),
                            onStop: () => _handleNodeOperation(
                              () => _store.stopNode(node.id),
                            ),
                            onRestart: () => _handleNodeOperation(
                              () => _store.restartNode(node.id),
                            ),
                            onRemove: () => _confirmRemoveNode(
                              context,
                              node.id,
                              node.name,
                            ),
                          ),
                        );
                      },
                      childCount: _store.nodes.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddNodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddNodeDialog(
        onAdd: (config) async {
          try {
            await _store.addNode(config);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          } catch (e) {
            // Error shown via operationError reaction
          }
        },
      ),
    );
  }

  void _confirmRemoveNode(
    BuildContext context,
    String nodeId,
    String nodeName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Node'),
        content: Text('Are you sure you want to remove "$nodeName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _store.removeNode(nodeId);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                // Error shown via operationError reaction
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
