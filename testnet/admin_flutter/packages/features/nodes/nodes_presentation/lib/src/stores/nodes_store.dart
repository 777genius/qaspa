import 'dart:async';
import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:nodes_domain/nodes_domain.dart';

part 'nodes_store.g.dart';

@lazySingleton
class NodesStore = _NodesStore with _$NodesStore;

abstract class _NodesStore with Store {
  final GetNodesUseCase _getNodesUseCase;
  final WatchNodesUseCase _watchNodesUseCase;
  final AddNodeUseCase _addNodeUseCase;
  final RemoveNodeUseCase _removeNodeUseCase;
  final StartNodeUseCase _startNodeUseCase;
  final StopNodeUseCase _stopNodeUseCase;
  final RestartNodeUseCase _restartNodeUseCase;

  _NodesStore(
    this._getNodesUseCase,
    this._watchNodesUseCase,
    this._addNodeUseCase,
    this._removeNodeUseCase,
    this._startNodeUseCase,
    this._stopNodeUseCase,
    this._restartNodeUseCase,
  );

  StreamSubscription<List<NodeInstance>>? _nodesSubscription;

  /// Subscription version to prevent race conditions when re-subscribing.
  /// Old stream events are ignored if their version doesn't match current.
  int _subscriptionVersion = 0;

  @observable
  ObservableList<NodeInstance> nodes = ObservableList<NodeInstance>();

  @observable
  bool isLoading = false;

  @observable
  String? error;

  @observable
  String? operationError;

  @observable
  bool isOperating = false;

  @computed
  bool get hasNodes => nodes.isNotEmpty;

  @computed
  int get runningCount => nodes.where((n) => n.status == 'running').length;

  @computed
  int get stoppedCount => nodes.where((n) => n.status == 'stopped').length;

  @action
  Future<void> init() async {
    await loadNodes();
    _subscribeToUpdates();
  }

  @action
  Future<void> loadNodes() async {
    isLoading = true;
    error = null;

    try {
      final result = await _getNodesUseCase();
      // Use clear+addAll to preserve list reference and avoid stale observers
      nodes.clear();
      nodes.addAll(result);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  void _subscribeToUpdates() {
    // Cancel existing subscription to prevent memory leak on re-init
    _nodesSubscription?.cancel();

    // Increment version to invalidate any pending events from old subscription
    final currentVersion = ++_subscriptionVersion;

    _nodesSubscription = _watchNodesUseCase().listen(
      (newNodes) {
        // Ignore events from stale subscriptions (race condition protection)
        if (currentVersion != _subscriptionVersion) return;

        // Skip update if nothing changed (avoids O(N) clear+addAll on frequent updates)
        if (!_hasNodeChanges(newNodes)) return;

        // Merge new data with existing, preserving static fields (ports)
        final mergedNodes = _mergeNodes(newNodes);

        // Use clear+addAll to preserve list reference and avoid stale observers
        nodes.clear();
        nodes.addAll(mergedNodes);
        error = null;
      },
      onError: (e) {
        // Ignore errors from stale subscriptions
        if (currentVersion != _subscriptionVersion) return;

        error = e.toString();
      },
      onDone: () {
        // Ignore done from stale subscriptions
        if (currentVersion != _subscriptionVersion) return;

        error = 'Connection closed';
      },
    );
  }

  @action
  Future<void> addNode(NodeConfig config) async {
    isOperating = true;
    operationError = null;

    try {
      final node = await _addNodeUseCase(config);
      nodes.add(node);
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> removeNode(String nodeId) async {
    isOperating = true;
    operationError = null;

    try {
      await _removeNodeUseCase(nodeId);
      nodes.removeWhere((n) => n.id == nodeId);
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> startNode(String nodeId) async {
    isOperating = true;
    operationError = null;

    try {
      await _startNodeUseCase(nodeId);
      _updateNodeStatus(nodeId, 'starting');
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> stopNode(String nodeId) async {
    isOperating = true;
    operationError = null;

    try {
      await _stopNodeUseCase(nodeId);
      _updateNodeStatus(nodeId, 'stopping');
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> restartNode(String nodeId) async {
    isOperating = true;
    operationError = null;

    try {
      await _restartNodeUseCase(nodeId);
      _updateNodeStatus(nodeId, 'restarting');
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  void _updateNodeStatus(String nodeId, String status) {
    final index = nodes.indexWhere((n) => n.id == nodeId);
    if (index >= 0) {
      final node = nodes[index];
      nodes[index] = NodeInstance(
        id: node.id,
        name: node.name,
        role: node.role,
        status: status,
        p2pPort: node.p2pPort,
        grpcPort: node.grpcPort,
        metrics: node.metrics,
      );
    }
  }

  /// Merge new nodes with existing, preserving static fields (ports) if missing
  List<NodeInstance> _mergeNodes(List<NodeInstance> newNodes) {
    return newNodes.map((newNode) {
      // Find existing node by ID
      final existingIndex = nodes.indexWhere((n) => n.id == newNode.id);
      if (existingIndex < 0) return newNode;

      final existing = nodes[existingIndex];

      // If new node has zero ports but existing has valid ports, preserve them
      final p2pPort = newNode.p2pPort != 0 ? newNode.p2pPort : existing.p2pPort;
      final grpcPort = newNode.grpcPort != 0 ? newNode.grpcPort : existing.grpcPort;

      // Return merged node
      return NodeInstance(
        id: newNode.id,
        name: newNode.name,
        role: newNode.role,
        status: newNode.status,
        p2pPort: p2pPort,
        grpcPort: grpcPort,
        metrics: newNode.metrics,
      );
    }).toList();
  }

  /// Check if newNodes differ from current nodes (by ID, status, and metrics)
  bool _hasNodeChanges(List<NodeInstance> newNodes) {
    if (nodes.length != newNodes.length) return true;

    // Build a map of new nodes by ID for O(1) lookup (order-independent)
    final newNodesMap = {for (final n in newNodes) n.id: n};

    for (final current in nodes) {
      final updated = newNodesMap[current.id];
      // Node was removed or ID changed
      if (updated == null) return true;
      // Check status
      if (current.status != updated.status) return true;
      // Check metrics changes (null-safe comparison)
      final currentMetrics = current.metrics;
      final updatedMetrics = updated.metrics;
      if ((currentMetrics == null) != (updatedMetrics == null)) {
        return true;
      }
      if (currentMetrics != null && updatedMetrics != null) {
        if (currentMetrics.blockCount != updatedMetrics.blockCount ||
            currentMetrics.peerCount != updatedMetrics.peerCount ||
            currentMetrics.isSynced != updatedMetrics.isSynced) {
          return true;
        }
      }
    }
    return false;
  }

  @action
  Future<void> refresh() async {
    await loadNodes();
  }

  void dispose() {
    _nodesSubscription?.cancel();
  }
}
