import 'dart:async';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import '../clients/admin_api_client.dart';
import '../clients/events_websocket_client.dart';

@LazySingleton(as: MinerRepository)
class MinerRepositoryImpl implements MinerRepository {
  final AdminApiClient _apiClient;
  final EventsWebSocketClient _wsClient;

  MinerRepositoryImpl({
    required AdminApiClient apiClient,
    required EventsWebSocketClient wsClient,
  })  : _apiClient = apiClient,
        _wsClient = wsClient;

  @override
  Future<List<MinerInstance>> getMiners() async {
    final response = await _apiClient.getList('/api/v1/miners');
    return response
        .map((m) => _parseMiner(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MinerInstance> getMiner(String minerId) async {
    final response = await _apiClient.get('/api/v1/miners/$minerId');
    return _parseMiner(response);
  }

  @override
  Stream<List<MinerInstance>> watchMiners() {
    return _wsClient.events
        .where((msg) => msg['type'] == 'ClusterUpdated')
        .map((msg) {
      try {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final miners = data['miners'] as Map<String, dynamic>? ?? {};
        return miners.values
            .map((m) => _parseMiner(m as Map<String, dynamic>))
            .toList();
      } catch (e, stackTrace) {
        debugPrint('MinerRepository: Error parsing miners: $e\n$stackTrace');
        return <MinerInstance>[];
      }
    });
  }

  @override
  Future<MinerInstance> addMiner(MinerConfig config) async {
    final response = await _apiClient.post(
      '/api/v1/miners',
      body: config.toRequestJson(),
    );
    return MinerInstance(
      id: response['id'] as String? ?? '',
      name: response['name'] as String? ?? config.name ?? 'miner',
      status: 'starting',
      targetNode: config.targetNode,
      hashrate: 0,
      blocksFound: 0,
    );
  }

  @override
  Future<void> removeMiner(String minerId) async {
    await _apiClient.delete('/api/v1/miners/$minerId');
  }

  @override
  Future<void> startMiner(String minerId) async {
    await _apiClient.post('/api/v1/miners/$minerId/start');
  }

  @override
  Future<void> stopMiner(String minerId) async {
    await _apiClient.post('/api/v1/miners/$minerId/stop');
  }

  MinerInstance _parseMiner(Map<String, dynamic> json) {
    return MinerInstance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'unknown',
      targetNode: json['target_node'] as String? ?? '',
      hashrate: (json['hashrate'] as num?)?.toDouble() ?? 0,
      blocksFound: json['blocks_found'] as int? ?? 0,
    );
  }
}
