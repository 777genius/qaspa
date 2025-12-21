import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:admin_domain/admin_domain.dart';

/// WebSocket client for container logs
@lazySingleton
class LogsWebSocketClient {
  final String _baseWsUrl;
  final Map<String, _LogSubscription> _subscriptions = {};

  LogsWebSocketClient({
    @Named('logsWsUrl') required String wsUrl,
  }) : _baseWsUrl = wsUrl;

  Stream<LogEntry> subscribe({
    String? containerId,
    LogLevel? minLevel,
  }) {
    final key = '${containerId ?? 'all'}_${minLevel?.name ?? 'all'}';

    if (!_subscriptions.containsKey(key)) {
      _subscriptions[key] = _LogSubscription(
        baseUrl: _baseWsUrl,
        containerId: containerId,
        minLevel: minLevel,
      );
    }

    return _subscriptions[key]!.stream;
  }

  void unsubscribe({String? containerId, LogLevel? minLevel}) {
    final key = '${containerId ?? 'all'}_${minLevel?.name ?? 'all'}';
    _subscriptions[key]?.dispose();
    _subscriptions.remove(key);
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.dispose();
    }
    _subscriptions.clear();
  }
}

class _LogSubscription {
  final StreamController<LogEntry> _controller;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  static const int _maxReconnectDelay = 30;
  static const int _baseReconnectDelay = 1;

  final String baseUrl;
  final String? containerId;
  final LogLevel? minLevel;

  _LogSubscription({
    required this.baseUrl,
    this.containerId,
    this.minLevel,
  }) : _controller = StreamController<LogEntry>.broadcast() {
    _connect();
  }

  Stream<LogEntry> get stream => _controller.stream;

  void _connect() {
    if (_isDisposed) return;

    // Cancel any pending reconnect and cleanup existing resources to prevent leaks
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    // Build URL safely with proper query parameter encoding to prevent injection
    final baseUri = Uri.parse(baseUrl);
    final queryParams = <String, String>{};
    if (containerId != null) queryParams['container'] = containerId!;
    if (minLevel != null) queryParams['level'] = minLevel!.name;
    final uri = queryParams.isEmpty
        ? baseUri
        : baseUri.replace(queryParameters: queryParams);

    try {
      _channel = WebSocketChannel.connect(uri);

      // Check for race condition: if disposed during channel creation
      if (_isDisposed) {
        _channel?.sink.close();
        _channel = null;
        return;
      }

      _subscription = _channel!.stream.listen(
        (data) {
          // Check if disposed before adding to controller
          if (_isDisposed || _controller.isClosed) return;

          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final logData = json['data'] as Map<String, dynamic>?;
            if (logData != null) {
              _controller.add(LogEntry(
                message: logData['message'] as String? ?? '',
                timestamp: DateTime.tryParse(logData['timestamp'] as String? ?? '') ??
                    DateTime.now(),
                containerId: logData['container_id'] as String?,
                containerName: logData['container_name'] as String?,
              ));
            }
          } on FormatException catch (e) {
            // Log malformed JSON for debugging (using print as data layer)
            // ignore: avoid_print
            print('LogsWebSocket: Malformed JSON received: $e');
          } on TypeError catch (e) {
            // Log unexpected JSON format for debugging (using print as data layer)
            // ignore: avoid_print
            print('LogsWebSocket: Unexpected JSON format: $e');
          }
        },
        onError: (error) {
          // ignore: avoid_print
          print('LogsWebSocket: Stream error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          // Reset attempts on clean connection close, schedule reconnect
          _reconnectAttempts = 0;
          _scheduleReconnect();
        },
      );

      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;

    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _reconnectTimer?.cancel();

    // Exponential backoff with max delay cap
    final delay = (_baseReconnectDelay * (1 << _reconnectAttempts))
        .clamp(1, _maxReconnectDelay);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delay), _connect);
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
