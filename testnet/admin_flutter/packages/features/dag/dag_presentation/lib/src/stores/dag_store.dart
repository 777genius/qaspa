import 'dart:async';

import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:nodes_domain/nodes_domain.dart';

part 'dag_store.g.dart';

/// Maximum number of blocks to keep in memory
const int kMaxBlocksInMemory = 200;

@lazySingleton
class DagStore = _DagStore with _$DagStore;

abstract class _DagStore with Store {
  final GetDagStateUseCase _getDagStateUseCase;
  final WatchDagUpdatesUseCase _watchDagUpdatesUseCase;
  final ConnectToNodeUseCase _connectToNodeUseCase;
  final GetNodesUseCase _getNodesUseCase;

  _DagStore(
    this._getDagStateUseCase,
    this._watchDagUpdatesUseCase,
    this._connectToNodeUseCase,
    this._getNodesUseCase,
  );

  StreamSubscription<DagState>? _stateSubscription;
  StreamSubscription<DagBlock>? _blockSubscription;
  StreamSubscription<VirtualChainChanged>? _chainSubscription;

  /// Timers for new block highlight animations (for proper cleanup)
  final List<Timer> _highlightTimers = [];

  /// Subscription version to prevent race conditions
  int _subscriptionVersion = 0;

  @observable
  String? connectedNodeId;

  @observable
  DagState? dagState;

  @observable
  ObservableMap<String, DagBlock> blocks = ObservableMap<String, DagBlock>();

  @observable
  bool isConnecting = false;

  @observable
  bool isLoading = false;

  @observable
  String? error;

  @observable
  bool isLiveMode = true;

  @observable
  double zoomLevel = 1.0;

  @observable
  String? selectedBlockHash;

  @observable
  String? hoveredBlockHash;

  @observable
  Set<String> newBlockHashes = <String>{};

  /// Auto-follow mode: automatically scroll to latest block
  @observable
  bool isAutoFollowEnabled = true;

  @computed
  bool get isConnected => connectedNodeId != null;

  @computed
  List<DagBlock> get sortedBlocks {
    final list = blocks.values.toList();
    list.sort((a, b) => b.daaScore.value.compareTo(a.daaScore.value));
    return list;
  }

  @computed
  List<DagBlock> get tipBlocks {
    final state = dagState;
    if (state == null) return [];
    return state.tipHashes
        .where((h) => blocks.containsKey(h.value))
        .map((h) => blocks[h.value])
        .whereType<DagBlock>()
        .toList();
  }

  @computed
  DagBlock? get sinkBlock {
    final state = dagState;
    if (state == null) return null;
    return blocks[state.sinkHash.value];
  }

  @computed
  DagBlock? get selectedBlock {
    if (selectedBlockHash == null) return null;
    return blocks[selectedBlockHash];
  }

  @action
  Future<void> connect(String nodeId) async {
    if (isConnecting) return;

    isConnecting = true;
    error = null;

    try {
      await _connectToNodeUseCase(nodeId);
      connectedNodeId = nodeId;
      await loadInitialState();
      _subscribeToUpdates();
    } catch (e) {
      error = e.toString();
      connectedNodeId = null;
    } finally {
      isConnecting = false;
    }
  }

  /// Auto-connect to the first available running node
  @action
  Future<void> autoConnect() async {
    if (isConnecting || isConnected) return;

    isConnecting = true;
    error = null;

    try {
      final nodes = await _getNodesUseCase();

      // Find first running and synced node, or just first running node
      final syncedNode = nodes.where((n) => n.isRunning && n.isSynced).firstOrNull;
      final runningNode = nodes.where((n) => n.isRunning).firstOrNull;
      final targetNode = syncedNode ?? runningNode;

      if (targetNode == null) {
        error = 'No running nodes available';
        return;
      }

      await _connectToNodeUseCase(targetNode.id);
      connectedNodeId = targetNode.id;
      await loadInitialState();
      _subscribeToUpdates();
    } catch (e) {
      error = e.toString();
      connectedNodeId = null;
    } finally {
      isConnecting = false;
    }
  }

  @action
  Future<void> disconnect() async {
    _cancelSubscriptions();
    connectedNodeId = null;
    dagState = null;
    blocks.clear();
    newBlockHashes.clear();
    selectedBlockHash = null;
    hoveredBlockHash = null;
  }

  @action
  Future<void> loadInitialState() async {
    isLoading = true;
    error = null;

    try {
      final state = await _getDagStateUseCase();
      _updateState(state);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  void _subscribeToUpdates() {
    _cancelSubscriptions();
    final currentVersion = ++_subscriptionVersion;

    // Only update metadata (tips, sink, daa score) - don't replace blocks map
    _stateSubscription = _watchDagUpdatesUseCase().listen(
      (state) {
        if (currentVersion != _subscriptionVersion) return;
        _updateStateMetadata(state);
      },
      onError: (e) {
        if (currentVersion != _subscriptionVersion) return;
        error = e.toString();
      },
    );

    // Incremental block additions - primary source of truth
    _blockSubscription = _watchDagUpdatesUseCase.watchBlocks().listen(
      (block) {
        if (currentVersion != _subscriptionVersion) return;
        _addBlock(block);
      },
      onError: (e) {
        if (currentVersion != _subscriptionVersion) return;
        debugPrint('DagStore: Block stream error: $e');
      },
    );

    _chainSubscription = _watchDagUpdatesUseCase.watchReorgs().listen(
      (event) {
        if (currentVersion != _subscriptionVersion) return;
        _handleChainChange(event);
      },
      onError: (e) {
        if (currentVersion != _subscriptionVersion) return;
        debugPrint('DagStore: Chain reorg stream error: $e');
      },
    );
  }

  /// Initial state load - populates blocks map
  @action
  void _updateState(DagState state) {
    dagState = state;
    for (final entry in state.blocks.entries) {
      blocks[entry.key] = entry.value;
    }
    _trimOldBlocks();
  }

  /// Live updates - only update metadata, blocks come from block stream
  @action
  void _updateStateMetadata(DagState state) {
    dagState = state;
    // Don't replace blocks - they're managed by _addBlock
  }

  @action
  void _addBlock(DagBlock block) {
    if (!isLiveMode) return;

    // Heuristic: if block has single parent that is chain block, mark as chain block
    // This handles the common case where VirtualChainChanged arrives late
    var blockToAdd = block;
    if (!block.isChainBlock && block.parentHashes.length == 1) {
      final parentHash = block.parentHashes.first;
      final parent = blocks[parentHash.value];
      if (parent != null && parent.isChainBlock) {
        blockToAdd = block.copyWith(isChainBlock: true);
      }
    }

    blocks[blockToAdd.hash.value] = blockToAdd;
    newBlockHashes = {...newBlockHashes, blockToAdd.hash.value};

    // Clear new block indicator after animation with proper cleanup
    final blockHash = blockToAdd.hash.value;
    late final Timer timer;
    timer = Timer(const Duration(seconds: 2), () {
      newBlockHashes = {...newBlockHashes}..remove(blockHash);
      _highlightTimers.remove(timer);
    });
    _highlightTimers.add(timer);

    _trimOldBlocks();
  }

  @action
  void _handleChainChange(VirtualChainChanged event) {
    // Update blocks that were removed from chain (now red)
    for (final hash in event.removedHashes) {
      final block = blocks[hash.value];
      if (block != null) {
        blocks[hash.value] = block.copyWith(isChainBlock: false);
      }
    }

    // Update blocks that were added to chain (now blue)
    for (final hash in event.addedHashes) {
      final block = blocks[hash.value];
      if (block != null) {
        blocks[hash.value] = block.copyWith(isChainBlock: true);
      }
    }
  }

  void _trimOldBlocks() {
    if (blocks.length <= kMaxBlocksInMemory) return;

    // Collect all parent hashes that must be kept for graph connectivity
    final requiredParents = <String>{};
    for (final block in blocks.values) {
      for (final parentHash in block.parentHashes) {
        requiredParents.add(parentHash.value);
      }
    }

    // Sort by DAA score (newest first)
    final sorted = blocks.entries.toList()
      ..sort((a, b) => b.value.daaScore.value.compareTo(a.value.daaScore.value));

    // Remove only blocks that:
    // 1. Are beyond the limit
    // 2. Are NOT parents of other blocks (to preserve graph connectivity)
    int kept = 0;
    final toRemove = <String>[];
    for (final entry in sorted) {
      if (kept < kMaxBlocksInMemory || requiredParents.contains(entry.key)) {
        kept++;
      } else {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      blocks.remove(key);
    }
  }

  void _cancelSubscriptions() {
    _stateSubscription?.cancel();
    _blockSubscription?.cancel();
    _chainSubscription?.cancel();
    _stateSubscription = null;
    _blockSubscription = null;
    _chainSubscription = null;

    // Cancel all highlight timers to prevent memory leaks
    for (final timer in _highlightTimers) {
      timer.cancel();
    }
    _highlightTimers.clear();
  }

  @action
  void toggleLiveMode() {
    isLiveMode = !isLiveMode;
  }

  @action
  void zoomIn() {
    if (zoomLevel < 2.0) {
      zoomLevel += 0.1;
    }
  }

  @action
  void zoomOut() {
    if (zoomLevel > 0.5) {
      zoomLevel -= 0.1;
    }
  }

  @action
  void resetZoom() {
    zoomLevel = 1.0;
  }

  @action
  void selectBlock(String? hash) {
    selectedBlockHash = hash;
  }

  @action
  void hoverBlock(String? hash) {
    hoveredBlockHash = hash;
  }

  /// Disable auto-follow (called when user manually pans)
  @action
  void disableAutoFollow() {
    isAutoFollowEnabled = false;
  }

  /// Enable auto-follow and jump to latest block
  @action
  void enableAutoFollow() {
    isAutoFollowEnabled = true;
  }

  void dispose() {
    _cancelSubscriptions();
  }
}
