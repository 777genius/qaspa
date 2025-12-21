import 'package:admin_design_system/admin_design_system.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';

import '../module/logs_module.dart';
import '../stores/logs_store.dart';
import '../widgets/log_entry_tile.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = LogsModule.init();
  }

  @override
  void dispose() {
    LogsModule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Initializing logs...');
        }

        if (snapshot.hasError) {
          return ErrorView(
            title: 'Failed to initialize',
            message: snapshot.error.toString(),
            onRetry: () {
              if (mounted) {
                setState(() {
                  _initFuture = LogsModule.init();
                });
              }
            },
          );
        }

        return const _LogsContent();
      },
    );
  }
}

class _LogsContent extends StatelessWidget {
  const _LogsContent();

  @override
  Widget build(BuildContext context) {
    final store = GetIt.instance<LogsStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _LogsToolbar(store: store, isDark: isDark),
        Expanded(
          child: Observer(
            builder: (_) {
              if (store.error != null && store.logs.isEmpty) {
                return ErrorView(
                  title: 'Connection error',
                  message: store.error,
                  onRetry: store.init,
                );
              }

              if (store.logs.isEmpty) {
                return const EmptyState(
                  title: 'No logs yet',
                  message: 'Logs will appear here as they are generated',
                  icon: Icons.article_outlined,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminSpacing.lg,
                  vertical: AdminSpacing.sm,
                ),
                itemCount: store.logs.length,
                itemBuilder: (context, index) {
                  // Show newest logs at bottom (reverse iteration)
                  final reversedIndex = store.logs.length - 1 - index;
                  final log = store.logs[reversedIndex];
                  // Use timestamp + index for unique key (timestamps can duplicate)
                  return LogEntryTile(
                    key: ValueKey('${log.timestamp.microsecondsSinceEpoch}_$reversedIndex'),
                    log: log,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LogsToolbar extends StatelessWidget {
  final LogsStore store;
  final bool isDark;

  const _LogsToolbar({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AdminColors.surfaceDark : AdminColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AdminColors.borderDark : AdminColors.borderLight,
          ),
        ),
      ),
      child: Observer(
        builder: (_) => LayoutBuilder(
          builder: (context, constraints) {
            // Use responsive layout for narrow screens
            final isNarrow = constraints.maxWidth < 600;

            return Row(
              children: [
                // Make dropdowns flexible on narrow screens
                Flexible(
                  flex: isNarrow ? 1 : 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: isNarrow ? 100 : 200,
                      maxWidth: 200,
                    ),
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(store.selectedContainerId),
                      initialValue: store.selectedContainerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Container',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AdminSpacing.sm,
                          vertical: AdminSpacing.xs,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All containers'),
                        ),
                        ...store.containerIds.map(
                          (id) => DropdownMenuItem(
                            value: id,
                            child: Text(id),
                          ),
                        ),
                      ],
                      onChanged: store.setContainerFilter,
                    ),
                  ),
                ),
                const SizedBox(width: AdminSpacing.md),
                Flexible(
                  flex: isNarrow ? 1 : 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: isNarrow ? 80 : 150,
                      maxWidth: 150,
                    ),
                    child: DropdownButtonFormField<LogLevel?>(
                      key: ValueKey(store.minLevel),
                      initialValue: store.minLevel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Min Level',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AdminSpacing.sm,
                          vertical: AdminSpacing.xs,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: LogLevel.debug,
                          child: Text('Debug'),
                        ),
                        DropdownMenuItem(
                          value: LogLevel.info,
                          child: Text('Info'),
                        ),
                        DropdownMenuItem(
                          value: LogLevel.warn,
                          child: Text('Warning'),
                        ),
                        DropdownMenuItem(
                          value: LogLevel.error,
                          child: Text('Error'),
                        ),
                      ],
                      onChanged: store.setLevelFilter,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: store.isConnected
                      ? AdminColors.success
                      : AdminColors.error,
                ),
                const SizedBox(width: AdminSpacing.xs),
                Text(
                  store.isConnected ? 'Connected' : 'Disconnected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: AdminSpacing.md),
            IconButton(
              onPressed: store.togglePause,
              icon: Icon(
                store.isPaused ? Icons.play_arrow : Icons.pause,
              ),
              tooltip: store.isPaused ? 'Resume' : 'Pause',
            ),
            IconButton(
              onPressed: store.clearLogs,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear logs',
            ),
              ],
            );
          },
        ),
      ),
    );
  }
}
