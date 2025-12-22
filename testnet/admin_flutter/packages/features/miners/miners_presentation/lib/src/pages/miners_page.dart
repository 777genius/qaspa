import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:mobx/mobx.dart';

import '../module/miners_module.dart';
import '../stores/miners_store.dart';
import '../widgets/miner_card.dart';
import '../widgets/add_miner_dialog.dart';

class MinersPage extends StatefulWidget {
  const MinersPage({super.key});

  @override
  State<MinersPage> createState() => _MinersPageState();
}

class _MinersPageState extends State<MinersPage> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = MinersModule.init();
  }

  @override
  void dispose() {
    MinersModule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Initializing miners...');
        }

        if (snapshot.hasError) {
          return ErrorView(
            title: 'Failed to initialize',
            message: snapshot.error.toString(),
            onRetry: () {
              if (mounted) {
                setState(() {
                  _initFuture = MinersModule.init();
                });
              }
            },
          );
        }

        return const _MinersContent();
      },
    );
  }
}

class _MinersContent extends StatefulWidget {
  const _MinersContent();

  @override
  State<_MinersContent> createState() => _MinersContentState();
}

class _MinersContentState extends State<_MinersContent> {
  late final MinersStore _store;
  ReactionDisposer? _errorReaction;

  @override
  void initState() {
    super.initState();
    _store = GetIt.instance<MinersStore>();

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

  /// Wrapper for async miner operations with error handling
  void _handleMinerOperation(Future<void> Function() operation) {
    operation().catchError((Object e, StackTrace stack) {
      // Error is already captured in store.operationError via reaction
      // This catchError prevents unhandled exception
      // Log for debugging purposes
      debugPrint('Miner operation failed: $e\n$stack');
    });
  }

  String _formatHashrate(double hashrate) {
    // Handle NaN/Infinity to prevent display issues
    if (!hashrate.isFinite || hashrate < 0) {
      return '0.00 H/s';
    }
    if (hashrate >= 1e12) {
      return '${(hashrate / 1e12).toStringAsFixed(2)} TH/s';
    }
    if (hashrate >= 1e9) {
      return '${(hashrate / 1e9).toStringAsFixed(2)} GH/s';
    }
    if (hashrate >= 1e6) {
      return '${(hashrate / 1e6).toStringAsFixed(2)} MH/s';
    }
    if (hashrate >= 1e3) {
      return '${(hashrate / 1e3).toStringAsFixed(2)} KH/s';
    }
    return '${hashrate.toStringAsFixed(2)} H/s';
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (_store.isLoading && !_store.hasMiners) {
          return const LoadingIndicator(message: 'Loading miners...');
        }

        if (_store.error != null && !_store.hasMiners) {
          return ErrorView(
            title: 'Failed to load miners',
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
                            'Miners',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AdminSpacing.xs),
                          Row(
                            children: [
                              AnimatedValueText(
                                value: '${_store.runningCount} running',
                                highlightColor: AdminColors.success,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                              ),
                              Text(
                                ' • ',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                              ),
                              AnimatedValueText(
                                value: _formatHashrate(_store.totalHashrate),
                                highlightColor: AdminColors.warning,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                              ),
                              Text(
                                ' • ',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                              ),
                              AnimatedValueText(
                                value: '${_store.totalBlocksFound} blocks found',
                                highlightColor: AdminColors.success,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AdminColors.textSecondaryDark
                                          : AdminColors.textSecondaryLight,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddMinerDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Miner'),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_store.hasMiners)
                SliverFillRemaining(
                  child: EmptyState(
                    title: 'No miners yet',
                    message: 'Add a miner to start mining on your testnet',
                    icon: Icons.memory_outlined,
                    action: ElevatedButton.icon(
                      onPressed: () => _showAddMinerDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Miner'),
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
                        final miner = _store.miners[index];
                        return Padding(
                          key: ValueKey(miner.id),
                          padding:
                              const EdgeInsets.only(bottom: AdminSpacing.md),
                          child: MinerCard(
                            miner: miner,
                            onStart: () => _handleMinerOperation(
                              () => _store.startMiner(miner.id),
                            ),
                            onStop: () => _handleMinerOperation(
                              () => _store.stopMiner(miner.id),
                            ),
                            onRemove: () => _confirmRemoveMiner(
                              context,
                              miner.id,
                              miner.name,
                            ),
                          ),
                        );
                      },
                      childCount: _store.miners.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMinerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddMinerDialog(
        onAdd: (config) => _store.addMiner(config),
      ),
    );
  }

  void _confirmRemoveMiner(
    BuildContext context,
    String minerId,
    String minerName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Miner'),
        content: Text('Are you sure you want to remove "$minerName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _store.removeMiner(minerId);
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
