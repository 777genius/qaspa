import 'dart:async';

import 'package:dag_data/src/cache/dag_block_cache.dart';
import 'package:dag_data/src/clients/dag_api_client.dart';
import 'package:dag_data/src/clients/dag_websocket_client.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Implementation of DagRepository
/// Combines API client, WebSocket client, and cache
@LazySingleton(as: DagRepository)
class DagRepositoryImpl implements DagRepository {
  final DagApiClient _apiClient;
  final DagWebSocketClient _wsClient;
  final DagBlockCache _cache;

  final _dagStateController = StreamController<DagState>.broadcast();

  String? _currentNodeId;
  DagState _currentState = DagState.initial();
  StreamSubscription<DagBlock>? _blockAddedSub;
  StreamSubscription<VirtualChainChanged>? _chainChangedSub;
  bool _isDisposed = false;

  DagRepositoryImpl(
    DagApiClient apiClient,
    DagWebSocketClient wsClient,
    DagBlockCache cache,
  )   : _apiClient = apiClient,
        _wsClient = wsClient,
        _cache = cache;

  // === DagConnectionManager ===

  @override
  String? get currentNodeId => _currentNodeId;

  @override
  bool get isConnected => _currentNodeId != null && _wsClient.isConnected;

  @override
  Stream<bool> get connectionState => _wsClient.connectionState;

  @override
  Future<void> connect(String nodeId) async {
    if (_currentNodeId == nodeId && isConnected) {
      return;
    }

    _currentNodeId = nodeId;

    _blockAddedSub?.cancel();
    _chainChangedSub?.cancel();

    _blockAddedSub = _wsClient.blockAdded.listen(_onBlockAdded);
    _chainChangedSub = _wsClient.virtualChainChanged.listen(_onChainChanged);

    // Connect WebSocket to specific node and subscribe
    _wsClient.connectToNode(nodeId);

    await getDagState();
  }

  @override
  Future<void> disconnect() async {
    _blockAddedSub?.cancel();
    _chainChangedSub?.cancel();
    _blockAddedSub = null;
    _chainChangedSub = null;
    _currentNodeId = null;

    _currentState = _currentState.copyWith(isConnected: false);
    if (!_dagStateController.isClosed) {
      _dagStateController.add(_currentState);
    }
  }

  // === DagReader ===

  @override
  Future<DagState> getDagState() async {
    if (_currentNodeId == null) {
      return _currentState;
    }

    try {
      final state = await _apiClient.getDagInfo(_currentNodeId!);
      final blocks = await _apiClient.getBlocks(_currentNodeId!);

      _cache.putAll(blocks);
      _updateChildrenRelations(blocks);

      _currentState = state.copyWith(
        blocks: _cache.allAsMap,
        isConnected: true,
      );

      if (!_dagStateController.isClosed) {
        _dagStateController.add(_currentState);
      }
      return _currentState;
    } on DagApiException catch (e) {
      throw DagConnectionException(
        'Failed to get DAG state',
        nodeId: _currentNodeId,
        cause: e,
      );
    }
  }

  @override
  Future<DagBlock?> getBlock(BlockHash hash) async {
    final cached = _cache.get(hash);
    if (cached != null) {
      return cached;
    }

    if (_currentNodeId == null) {
      throw const DagConnectionException(
        'Not connected to any node',
      );
    }

    final block = await _apiClient.getBlock(_currentNodeId!, hash.value);
    if (block != null) {
      _cache.put(block);
    }
    return block;
  }

  @override
  Future<List<DagBlock>> getBlocks({
    int limit = 100,
    DaaScore? fromDaaScore,
  }) async {
    if (_currentNodeId == null) {
      return _cache.sortedByDaaScore;
    }

    final blocks = await _apiClient.getBlocks(
      _currentNodeId!,
      limit: limit,
      fromDaaScore: fromDaaScore?.value,
    );
    _cache.putAll(blocks);
    _updateChildrenRelations(blocks);

    return _cache.sortedByDaaScore;
  }

  @override
  Future<List<DagBlock>> getTips() async {
    final tips = <DagBlock>[];
    for (final tipHash in _currentState.tipHashes) {
      final block = _cache.get(tipHash);
      if (block != null) {
        tips.add(block);
      }
    }
    return tips;
  }

  @override
  Future<DagBlock?> getSink() async {
    return _cache.get(_currentState.sinkHash);
  }

  // === DagWatcher ===

  @override
  Stream<DagBlock> watchBlockAdded() => _wsClient.blockAdded;

  @override
  Stream<VirtualChainChanged> watchVirtualChainChanged() =>
      _wsClient.virtualChainChanged;

  @override
  Stream<DagState> watchDagState() => _dagStateController.stream;

  // === Dispose ===

  @override
  void dispose() {
    _isDisposed = true;
    // Use try-finally for each operation to ensure all resources are cleaned up
    // even if one throws
    try {
      _blockAddedSub?.cancel();
    } finally {
      try {
        _chainChangedSub?.cancel();
      } finally {
        try {
          _dagStateController.close();
        } finally {
          try {
            _wsClient.close();
          } finally {
            _apiClient.dispose();
          }
        }
      }
    }
  }

  // === Private methods ===

  void _onBlockAdded(DagBlock block) {
    if (_isDisposed || _dagStateController.isClosed) return;
    try {
      _cache.put(block);

      for (final parentHash in block.parentHashes) {
        _cache.addChild(parentHash, block.hash);
      }

      final updatedBlocks = _cache.allAsMap;

      final updatedTips = List<BlockHash>.from(_currentState.tipHashes);
      for (final parentHash in block.parentHashes) {
        updatedTips.remove(parentHash);
      }
      if (!updatedTips.contains(block.hash)) {
        updatedTips.add(block.hash);
      }

      _currentState = _currentState.copyWith(
        blocks: updatedBlocks,
        tipHashes: updatedTips,
        blockCount: _currentState.blockCount + 1,
      );


      if (!_dagStateController.isClosed) {
        _dagStateController.add(_currentState);
      }
    } catch (e, stackTrace) {
    }
  }

  void _onChainChanged(VirtualChainChanged event) {
    if (_isDisposed || _dagStateController.isClosed) return;
    try {
      for (final hash in event.removedHashes) {
        _cache.markAsChainBlock(hash, false);
      }

      for (final hash in event.addedHashes) {
        _cache.markAsChainBlock(hash, true);
      }

      _currentState = _currentState.copyWith(
        blocks: _cache.allAsMap,
      );

      if (!_dagStateController.isClosed) {
        _dagStateController.add(_currentState);
      }
    } catch (e, stackTrace) {
    }
  }

  void _updateChildrenRelations(List<DagBlock> blocks) {
    for (final block in blocks) {
      for (final parentHash in block.parentHashes) {
        _cache.addChild(parentHash, block.hash);
      }
    }
  }
}
