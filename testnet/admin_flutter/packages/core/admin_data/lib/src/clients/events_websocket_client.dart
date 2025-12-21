import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for cluster events
@lazySingleton
class EventsWebSocketClient {
  final String _wsUrl;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  static const int _maxReconnectDelay = 30;
  static const int _baseReconnectDelay = 1;
  // Maximum WebSocket message size to prevent OOM (1MB)
  static const int _maxMessageSize = 1024 * 1024;

  EventsWebSocketClient({
    @Named('eventsWsUrl') required String wsUrl,
  }) : _wsUrl = wsUrl;

  Stream<Map<String, dynamic>> get events {
    // Check disposed state first to fail fast
    if (_isDisposed) {
      throw StateError('EventsWebSocketClient has been disposed');
    }

    _ensureConnected();

    // Handle race condition: dispose() could be called between _ensureConnected() and here
    final controller = _controller;
    if (controller == null || controller.isClosed || _isDisposed) {
      throw StateError('EventsWebSocketClient is not connected or has been disposed');
    }
    return controller.stream;
  }

  void _ensureConnected() {
    if (_channel != null) return;

    // Only create new controller if one doesn't exist or is closed
    final controller = _controller;
    if (controller == null || controller.isClosed) {
      _controller = StreamController<Map<String, dynamic>>.broadcast();
    }
    _connect();
  }

  void _connect() {
    if (_isDisposed) return;

    // Cancel any pending reconnect and cleanup existing resources to prevent leaks
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      // Check for race condition: if disposed during channel creation
      if (_isDisposed) {
        _channel?.sink.close();
        _channel = null;
        return;
      }

      _subscription = _channel!.stream.listen(
        (data) {
          // Check if disposed before adding to controller
          if (_isDisposed || (_controller?.isClosed ?? true)) return;

          try {
            final dataStr = data as String;
            // Check message size to prevent OOM on malicious/oversized messages
            if (dataStr.length > _maxMessageSize) {
              // Log dropped oversized message for debugging
              // ignore: avoid_print
              print('EventsWebSocket: Dropped oversized message (${dataStr.length} bytes, max: $_maxMessageSize)');
              return;
            }
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            _controller?.add(json);
          } on FormatException catch (e) {
            // Log malformed JSON for debugging
            // ignore: avoid_print
            print('EventsWebSocket: Malformed JSON received: $e');
          } on TypeError catch (e) {
            // Log unexpected JSON format for debugging
            // ignore: avoid_print
            print('EventsWebSocket: Unexpected JSON format: $e');
          }
        },
        onError: (error) {
          // ignore: avoid_print
          print('EventsWebSocket: Stream error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          // Reset attempts on clean connection close
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
    _controller?.close();
  }
}
