import 'dart:async';

import 'package:dag_data/src/clients/base/reconnectable_ws_client.dart';
import 'package:dag_data/src/mappers/dag_block_mapper.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:injectable/injectable.dart';

/// WebSocket message types
enum DagWsMessageType {
  subscribe,
  blockAdded,
  virtualChainChanged,
  error,
}

/// WebSocket client for DAG notifications
@injectable
class DagWebSocketClient extends ReconnectableWebSocketClient {
  final DagBlockMapper _blockMapper;
  final String _baseWsUrl;

  final _blockAddedController = StreamController<DagBlock>.broadcast();
  final _chainChangedController = StreamController<VirtualChainChanged>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  bool _isSubscribed = false;
  String? _currentNodeId;

  DagWebSocketClient(
    DagBlockMapper blockMapper,
    @Named('dagWsUrl') String wsUrl,
  )   : _blockMapper = blockMapper,
        _baseWsUrl = wsUrl,
        super(wsUrl);

  /// Stream of new blocks
  Stream<DagBlock> get blockAdded => _blockAddedController.stream;

  /// Stream of chain changes (reorgs)
  Stream<VirtualChainChanged> get virtualChainChanged => _chainChangedController.stream;

  /// Stream of connection state changes
  Stream<bool> get connectionState => _connectionController.stream;

  /// Connect to a specific node
  void connectToNode(String nodeId) {
    if (_currentNodeId == nodeId && isConnected) {
      return;
    }
    _currentNodeId = nodeId;
    _isSubscribed = false;
    final url = '$_baseWsUrl?node_id=$nodeId';
    reconnectWithUrl(url);
  }

  /// Subscribe to DAG notifications
  void subscribe() {
    if (_isSubscribed || !isConnected) {
      return;
    }

    send({
      'type': 'Subscribe',
      'scopes': ['block_added', 'virtual_chain_changed'],
    });
    _isSubscribed = true;
  }

  @override
  void onConnected() {
    _connectionController.add(true);
    if (_currentNodeId != null) {
      _isSubscribed = false;
      subscribe();
    }
  }

  @override
  void onDisconnected() {
    _connectionController.add(false);
  }

  @override
  void onMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'BlockAdded':
        final data = message['data'] as Map<String, dynamic>?;
        if (data != null) {
          final block = _blockMapper.fromJson(data);
          _blockAddedController.add(block);
        }

      case 'VirtualChainChanged':
        final data = message['data'] as Map<String, dynamic>?;
        if (data != null) {
          final removed = (data['removed'] as List?)
              ?.map((h) => BlockHash(h as String))
              .toList() ?? [];
          final added = (data['added'] as List?)
              ?.map((h) => BlockHash(h as String))
              .toList() ?? [];

          _chainChangedController.add(VirtualChainChanged(
            removedHashes: removed,
            addedHashes: added,
          ));
        }

      case 'Subscribed':
        break;

      case 'Error':
        final error = message['error'] as String?;
        if (error != null) {
          _blockAddedController.addError(DagWebSocketException(error));
        }
    }
  }

  @override
  void close() {
    _blockAddedController.close();
    _chainChangedController.close();
    _connectionController.close();
    super.close();
  }
}
