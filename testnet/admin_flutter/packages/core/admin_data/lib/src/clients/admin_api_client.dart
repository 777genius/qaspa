import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:admin_domain/admin_domain.dart';

/// HTTP client for admin API
@lazySingleton
class AdminApiClient {
  final http.Client _client;
  final String _baseUrl;

  /// Default timeout for HTTP requests to prevent hanging connections
  static const Duration _defaultTimeout = Duration(seconds: 30);

  AdminApiClient({
    http.Client? client,
    @Named('adminApiBaseUrl') required String baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_defaultTimeout);
    _checkResponse(response);
    return _decodeJson<Map<String, dynamic>>(response.body);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_defaultTimeout);
    _checkResponse(response);
    return _decodeJson<List<dynamic>>(response.body);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? json.encode(body) : null,
    ).timeout(_defaultTimeout);
    _checkResponse(response);
    if (response.body.isEmpty) return {};
    return _decodeJson<Map<String, dynamic>>(response.body);
  }

  T _decodeJson<T>(String body) {
    try {
      return json.decode(body) as T;
    } on FormatException catch (e) {
      throw NetworkException(
        'Invalid JSON response: ${e.message}',
        statusCode: 0,
      );
    } on TypeError {
      throw NetworkException(
        'Unexpected JSON format',
        statusCode: 0,
      );
    }
  }

  Future<void> delete(String path) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_defaultTimeout);
    _checkResponse(response);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw NetworkException(
        'API error: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Closes the HTTP client.
  /// Called automatically by GetIt when the singleton is disposed.
  @disposeMethod
  void dispose() {
    _client.close();
  }
}
