import 'dart:async';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import '../clients/admin_api_client.dart';
import '../clients/events_websocket_client.dart';

@LazySingleton(as: NodeRepository)
class NodeRepositoryImpl implements NodeRepository {
  final AdminApiClient _apiClient;
  final EventsWebSocketClient _wsClient;

  NodeRepositoryImpl({
    required AdminApiClient apiClient,
    required EventsWebSocketClient wsClient,
  })  : _apiClient = apiClient,
        _wsClient = wsClient;

  @override
  Future<List<NodeInstance>> getNodes() async {
    final response = await _apiClient.getList('/api/v1/nodes');
    return response
        .map((n) => _parseNode(n as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NodeInstance> getNode(String nodeId) async {
    final response = await _apiClient.get('/api/v1/nodes/$nodeId');
    return _parseNode(response);
  }

  @override
  Stream<List<NodeInstance>> watchNodes() {
    return _wsClient.events
        .where((msg) => msg['type'] == 'ClusterUpdated')
        .map((msg) {
      try {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final nodes = data['nodes'] as Map<String, dynamic>? ?? {};
        return nodes.values
            .map((n) => _parseNode(n as Map<String, dynamic>))
            .toList();
      } catch (e, stackTrace) {
        debugPrint('NodeRepository: Error parsing nodes: $e\n$stackTrace');
        return <NodeInstance>[];
      }
    });
  }

  @override
  Future<NodeInstance> addNode(NodeConfig config) async {
    final response = await _apiClient.post(
      '/api/v1/nodes',
      body: config.toRequestJson(),
    );
    return NodeInstance(
      id: response['id'] as String? ?? '',
      name: response['name'] as String? ?? '',
      role: 'peer',
      status: 'starting',
      p2pPort: (response['ports'] as Map<String, dynamic>?)?['p2p'] as int? ?? 0,
      grpcPort: (response['ports'] as Map<String, dynamic>?)?['grpc'] as int? ?? 0,
    );
  }

  @override
  Future<void> removeNode(String nodeId) async {
    await _apiClient.delete('/api/v1/nodes/$nodeId');
  }

  @override
  Future<void> startNode(String nodeId) async {
    await _apiClient.post('/api/v1/nodes/$nodeId/start');
  }

  @override
  Future<void> stopNode(String nodeId) async {
    await _apiClient.post('/api/v1/nodes/$nodeId/stop');
  }

  @override
  Future<void> restartNode(String nodeId) async {
    await _apiClient.post('/api/v1/nodes/$nodeId/restart');
  }

  NodeInstance _parseNode(Map<String, dynamic> json) {
    final ports = json['ports'] as Map<String, dynamic>? ?? {};
    final metricsJson = json['metrics'] as Map<String, dynamic>?;

    return NodeInstance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'peer',
      status: json['status'] as String? ?? 'unknown',
      p2pPort: _safeParseInt(ports['p2p']),
      grpcPort: _safeParseInt(ports['grpc']),
      metrics: metricsJson != null
          ? NodeMetrics(
              blockCount: _safeParseInt(metricsJson['block_count']),
              headerCount: _safeParseInt(metricsJson['header_count']),
              virtualDaaScore: _safeParseInt(metricsJson['virtual_daa_score']),
              peerCount: _safeParseInt(metricsJson['peer_count']),
              mempoolSize: _safeParseInt(metricsJson['mempool_size']),
              isSynced: metricsJson['is_synced'] as bool? ?? false,
            )
          : null,
    );
  }

  /// Safely parse an int from dynamic value (handles String, int, or null)
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}
