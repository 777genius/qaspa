import 'dart:async';
import 'package:admin_domain/admin_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import '../clients/admin_api_client.dart';
import '../clients/events_websocket_client.dart';

@LazySingleton(as: ClusterRepository)
class ClusterRepositoryImpl implements ClusterRepository {
  final AdminApiClient _apiClient;
  final EventsWebSocketClient _wsClient;

  ClusterRepositoryImpl({
    required AdminApiClient apiClient,
    required EventsWebSocketClient wsClient,
  })  : _apiClient = apiClient,
        _wsClient = wsClient;

  @override
  Future<Cluster> getCluster() async {
    final response = await _apiClient.get('/api/v1/cluster');
    return Cluster(
      status: _parseStatus(response['status'] as String?),
      nodeCount: (response['nodes'] as List?)?.length ?? 0,
      minerCount: (response['miners'] as List?)?.length ?? 0,
      txgenRunning: response['txgen_running'] as bool? ?? false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<ClusterStats> getStats() async {
    final response = await _apiClient.get('/api/v1/cluster');
    final aggregate = response['aggregate'] as Map<String, dynamic>? ?? {};
    return ClusterStats(
      totalNodes: aggregate['total_nodes'] as int? ?? 0,
      runningNodes: aggregate['running_nodes'] as int? ?? 0,
      syncedNodes: aggregate['synced_nodes'] as int? ?? 0,
      totalMiners: aggregate['total_miners'] as int? ?? 0,
      runningMiners: aggregate['running_miners'] as int? ?? 0,
      totalBlockCount: aggregate['total_block_count'] as int? ?? 0,
      virtualDaaScore: aggregate['virtual_daa_score'] as int? ?? 0,
      totalPeers: aggregate['total_peers'] as int? ?? 0,
      totalMempoolSize: aggregate['total_mempool_size'] as int? ?? 0,
      totalHashrate: (aggregate['total_hashrate'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<ClusterStats> watchStats() {
    return _wsClient.events
        .where((msg) => msg['type'] == 'ClusterUpdated')
        .map((msg) {
      try {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final nodes = data['nodes'] as Map<String, dynamic>? ?? {};
        final miners = data['miners'] as Map<String, dynamic>? ?? {};

      // Aggregate node metrics (same logic as Rust get_aggregate_metrics)
      int syncedNodes = 0;
      int totalBlockCount = 0;
      int virtualDaaScore = 0;
      int totalPeers = 0;
      int totalMempoolSize = 0;

      for (final nodeData in nodes.values) {
        if (nodeData is! Map<String, dynamic>) continue;
        final node = nodeData;
        final metrics = node['metrics'] as Map<String, dynamic>?;
        if (metrics != null) {
          final blockCount = metrics['block_count'] as int? ?? 0;
          final daaScore = metrics['virtual_daa_score'] as int? ?? 0;
          final peerCount = metrics['peer_count'] as int? ?? 0;
          final mempoolSize = metrics['mempool_size'] as int? ?? 0;
          final isSynced = metrics['is_synced'] as bool? ?? false;

          // Use max for block_count and daa_score
          if (blockCount > totalBlockCount) totalBlockCount = blockCount;
          if (daaScore > virtualDaaScore) virtualDaaScore = daaScore;
          // Sum peers and mempool
          totalPeers += peerCount;
          totalMempoolSize += mempoolSize;
          if (isSynced) syncedNodes++;
        }
      }

      // Aggregate miner hashrate
      double totalHashrate = 0;
      for (final minerData in miners.values) {
        if (minerData is! Map<String, dynamic>) continue;
        final miner = minerData;
        final hashrate = (miner['hashrate'] as num?)?.toDouble() ?? 0;
        if (hashrate.isFinite && hashrate >= 0) {
          totalHashrate += hashrate;
        }
      }

      return ClusterStats(
        totalNodes: nodes.length,
        runningNodes: nodes.values
            .whereType<Map<String, dynamic>>()
            .where((n) => n['status'] == 'running')
            .length,
        syncedNodes: syncedNodes,
        totalMiners: miners.length,
        runningMiners: miners.values
            .whereType<Map<String, dynamic>>()
            .where((m) => m['status'] == 'running')
            .length,
        totalBlockCount: totalBlockCount,
        virtualDaaScore: virtualDaaScore,
        totalPeers: totalPeers,
        totalMempoolSize: totalMempoolSize,
        totalHashrate: totalHashrate,
        timestamp: DateTime.now(),
      );
      } catch (e, stackTrace) {
        debugPrint('ClusterRepository: Error parsing stats: $e\n$stackTrace');
        return ClusterStats.empty();
      }
    });
  }

  @override
  Future<void> startCluster() async {
    // Cluster is started via docker-compose, not API
    throw UnimplementedError('Use docker-compose to start cluster');
  }

  @override
  Future<void> stopCluster() async {
    // Cluster is stopped via docker-compose, not API
    throw UnimplementedError('Use docker-compose to stop cluster');
  }

  ClusterStatus _parseStatus(String? status) {
    return switch (status) {
      'starting' => ClusterStatus.starting,
      'running' => ClusterStatus.running,
      'degraded' => ClusterStatus.degraded,
      'stopping' => ClusterStatus.stopping,
      'stopped' => ClusterStatus.stopped,
      _ => () {
        if (status != null) {
          debugPrint('ClusterRepository: Unknown status "$status", defaulting to stopped');
        }
        return ClusterStatus.stopped;
      }(),
    };
  }
}
