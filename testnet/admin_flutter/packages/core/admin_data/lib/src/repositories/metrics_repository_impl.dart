import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

import '../clients/admin_api_client.dart';

@LazySingleton(as: MetricsRepository)
class MetricsRepositoryImpl implements MetricsRepository {
  final AdminApiClient _client;

  MetricsRepositoryImpl(this._client);

  @override
  Future<MinerMetricsHistory> getMinerHistory(
    String minerId, {
    int? from,
    int? to,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (from != null) queryParams['from'] = from.toString();
    if (to != null) queryParams['to'] = to.toString();

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final json = await _client.get('/api/v1/metrics/history/miners/$minerId?$queryString');
    return MinerMetricsHistory.fromJson(json);
  }

  @override
  Future<AggregateMetricsHistory> getAggregateHistory({
    int? from,
    int? to,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (from != null) queryParams['from'] = from.toString();
    if (to != null) queryParams['to'] = to.toString();

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final json = await _client.get('/api/v1/metrics/history?$queryString');
    return AggregateMetricsHistory.fromJson(json);
  }
}
