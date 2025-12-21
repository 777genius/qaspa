import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';

import '../module/dag_module.dart';
import '../stores/dag_store.dart';
import '../canvas/dag_canvas_widget.dart';

/// DAG visualization page
class DagPage extends StatefulWidget {
  final String? initialNodeId;

  const DagPage({super.key, this.initialNodeId});

  @override
  State<DagPage> createState() => _DagPageState();
}

class _DagPageState extends State<DagPage> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    await DagModule.init();
    if (widget.initialNodeId != null) {
      await DagModule.store.connect(widget.initialNodeId!);
    } else {
      // Auto-connect to first available node
      await DagModule.store.autoConnect();
    }
  }

  @override
  void dispose() {
    DagModule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Initializing DAG view...');
        }

        if (snapshot.hasError) {
          return ErrorView(
            title: 'Failed to initialize',
            message: snapshot.error.toString(),
            onRetry: () {
              if (mounted) {
                setState(() {
                  _initFuture = _initialize();
                });
              }
            },
          );
        }

        return const _DagContent();
      },
    );
  }
}

class _DagContent extends StatelessWidget {
  const _DagContent();

  @override
  Widget build(BuildContext context) {
    final store = GetIt.instance<DagStore>();

    return Observer(
      builder: (_) {
        if (!store.isConnected) {
          return _NodeSelector(store: store);
        }

        return DagCanvasWidget(store: store);
      },
    );
  }
}

/// Node selection view when not connected
class _NodeSelector extends StatelessWidget {
  final DagStore store;

  const _NodeSelector({required this.store});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  size: 64,
                  color: AdminColors.primary,
                ),
                const SizedBox(height: AdminSpacing.lg),
                Text(
                  'DAG Visualization',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AdminSpacing.sm),
                const Text(
                  'Select a node to view its BlockDAG',
                  style: TextStyle(color: AdminColors.textSecondaryLight),
                ),
                const SizedBox(height: AdminSpacing.xl),
                if (store.isConnecting)
                  const LoadingIndicator(message: 'Connecting...')
                else if (store.error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                    child: Text(
                      error,
                      style: const TextStyle(color: AdminColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: AdminSpacing.md),
                _NodeIdInput(
                  onConnect: (nodeId) => store.connect(nodeId),
                  isLoading: store.isConnecting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeIdInput extends StatefulWidget {
  final void Function(String nodeId) onConnect;
  final bool isLoading;

  const _NodeIdInput({
    required this.onConnect,
    required this.isLoading,
  });

  @override
  State<_NodeIdInput> createState() => _NodeIdInputState();
}

class _NodeIdInputState extends State<_NodeIdInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    final nodeId = _controller.text.trim();
    if (nodeId.isNotEmpty) {
      widget.onConnect(nodeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Node ID',
              hintText: 'e.g., node-1',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _connect(),
            enabled: !widget.isLoading,
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
        ElevatedButton(
          onPressed: widget.isLoading ? null : _connect,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.lg,
              vertical: AdminSpacing.md,
            ),
          ),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
