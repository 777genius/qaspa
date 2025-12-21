import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';
import '../clients/admin_api_client.dart';
import '../clients/logs_websocket_client.dart';

@LazySingleton(as: LogRepository)
class LogRepositoryImpl implements LogRepository {
  final AdminApiClient _apiClient;
  final LogsWebSocketClient _wsClient;

  LogRepositoryImpl({
    required AdminApiClient apiClient,
    required LogsWebSocketClient wsClient,
  })  : _apiClient = apiClient,
        _wsClient = wsClient;

  @override
  Future<List<LogEntry>> getLogs({
    String? containerId,
    LogLevel? minLevel,
    DateTime? since,
    int limit = 100,
  }) async {
    // For now, just return empty list - logs are streamed via WebSocket
    return [];
  }

  @override
  Stream<LogEntry> watchLogs({
    String? containerId,
    LogLevel? minLevel,
  }) {
    return _wsClient.subscribe(
      containerId: containerId,
      minLevel: minLevel,
    );
  }

  @override
  Future<List<String>> getContainerIds() async {
    final response = await _apiClient.get('/api/v1/cluster');
    final nodes = response['nodes'] as List? ?? [];
    final miners = response['miners'] as List? ?? [];
    return [
      ...nodes
          .whereType<Map<String, dynamic>>()
          .map((n) => n['id'] as String? ?? '')
          .where((id) => id.isNotEmpty),
      ...miners
          .whereType<Map<String, dynamic>>()
          .map((m) => m['id'] as String? ?? '')
          .where((id) => id.isNotEmpty),
    ];
  }
}
