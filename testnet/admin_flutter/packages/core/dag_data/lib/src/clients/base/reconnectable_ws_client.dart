import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Base class for reconnectable WebSocket clients
/// Implements exponential backoff reconnection strategy
abstract class ReconnectableWebSocketClient {
  String _wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  static const int _maxReconnectDelay = 30;
  static const int _baseReconnectDelay = 1;
  static const int _maxMessageSize = 1024 * 1024; // 1MB

  ReconnectableWebSocketClient(String wsUrl) : _wsUrl = wsUrl;

  /// Current WebSocket URL
  String get wsUrl => _wsUrl;

  /// Stream of JSON messages
  Stream<Map<String, dynamic>> get messages {
    if (_isDisposed) {
      throw StateError('WebSocket client has been disposed');
    }

    _ensureConnected();

    final controller = _controller;
    if (controller == null || controller.isClosed || _isDisposed) {
      throw StateError('WebSocket client is not connected or has been disposed');
    }
    return controller.stream;
  }

  /// Check if connected
  bool get isConnected => _channel != null && !_isDisposed;

  void _ensureConnected() {
    if (_channel != null) return;

    final controller = _controller;
    if (controller == null || controller.isClosed) {
      _controller = StreamController<Map<String, dynamic>>.broadcast();
    }
    _connect();
  }

  void _connect() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      if (_isDisposed) {
        _channel?.sink.close();
        _channel = null;
        return;
      }

      _subscription = _channel!.stream.listen(
        (data) {
          if (_isDisposed || (_controller?.isClosed ?? true)) {
            return;
          }

          try {
            final dataStr = data as String;
            if (dataStr.length > _maxMessageSize) {
              onOversizedMessage(dataStr.length);
              return;
            }
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            _controller?.add(json);
            onMessage(json);
          } on FormatException catch (e) {
            onMalformedMessage(e);
          } on TypeError catch (e) {
            onUnexpectedFormat(e);
          }
        },
        onError: (error) {
          onError(error);
          _scheduleReconnect();
        },
        onDone: () {
          _reconnectAttempts = 0;
          onDisconnected();
          _scheduleReconnect();
        },
      );

      _reconnectAttempts = 0;
      _channel!.ready.then((_) {
        if (!_isDisposed) {
          onConnected();
        }
      }).catchError((e) {
        onConnectionError(e);
        _scheduleReconnect();
      });
    } catch (e) {
      onConnectionError(e);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;

    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _reconnectTimer?.cancel();

    final delay = (_baseReconnectDelay * (1 << _reconnectAttempts))
        .clamp(1, _maxReconnectDelay);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delay), _connect);
  }

  /// Send JSON message
  void send(Map<String, dynamic> message) {
    if (!isConnected) {
      throw StateError('Not connected');
    }
    _channel?.sink.add(jsonEncode(message));
  }

  /// Close connection
  void close() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }

  /// Reconnect with a new URL
  void reconnectWithUrl(String newUrl) {
    _wsUrl = newUrl;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _reconnectAttempts = 0;

    // Ensure controller exists before connecting
    final controller = _controller;
    if (controller == null || controller.isClosed) {
      _controller = StreamController<Map<String, dynamic>>.broadcast();
    }

    _connect();
  }

  // Override points for subclasses
  void onConnected() {}
  void onDisconnected() {}
  void onMessage(Map<String, dynamic> message) {}
  void onError(Object error) {}
  void onConnectionError(Object error) {}
  void onOversizedMessage(int size) {}
  void onMalformedMessage(FormatException e) {}
  void onUnexpectedFormat(TypeError e) {}
}
