import 'dart:convert';

import 'package:dag_data/src/mappers/dag_block_mapper.dart';
import 'package:dag_data/src/mappers/dag_state_mapper.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

/// HTTP API client for DAG data
@injectable
class DagApiClient {
  static const _timeout = Duration(seconds: 30);

  final http.Client _httpClient;
  final String _baseUrl;
  final DagBlockMapper _blockMapper;
  final DagStateMapper _stateMapper;

  DagApiClient(
    http.Client httpClient,
    DagBlockMapper blockMapper,
    DagStateMapper stateMapper,
    @Named('controllerBaseUrl') String baseUrl,
  )   : _httpClient = httpClient,
        _baseUrl = baseUrl,
        _blockMapper = blockMapper,
        _stateMapper = stateMapper;

  /// Get DAG info for a node
  Future<DagState> getDagInfo(String nodeId) async {
    final response = await _httpClient
        .get(Uri.parse('$_baseUrl/api/v1/nodes/$nodeId/dag'))
        .timeout(_timeout);

    _checkResponse(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _stateMapper.fromJson(json);
  }

  /// Get blocks for a node
  Future<List<DagBlock>> getBlocks(
    String nodeId, {
    int limit = 100,
    int? fromDaaScore,
  }) async {
    var url = '$_baseUrl/api/v1/nodes/$nodeId/dag/blocks?limit=$limit';
    if (fromDaaScore != null) {
      url += '&from_daa_score=$fromDaaScore';
    }

    final response = await _httpClient.get(Uri.parse(url)).timeout(_timeout);
    _checkResponse(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final blocksJson = json['blocks'] as List? ?? [];

    return blocksJson
        .map((b) => _blockMapper.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific block by hash
  Future<DagBlock?> getBlock(String nodeId, String hash) async {
    final response = await _httpClient
        .get(Uri.parse('$_baseUrl/api/v1/nodes/$nodeId/dag/blocks/$hash'))
        .timeout(_timeout);

    if (response.statusCode == 404) {
      return null;
    }

    _checkResponse(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _blockMapper.fromJson(json);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw DagApiException(
        'API error: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
