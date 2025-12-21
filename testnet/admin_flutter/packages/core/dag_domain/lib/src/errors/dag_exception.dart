/// Base exception for all DAG-related errors
sealed class DagException implements Exception {
  final String message;
  final Object? cause;

  const DagException(this.message, [this.cause]);

  @override
  String toString() => 'DagException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Exception when connection to node fails
final class DagConnectionException extends DagException {
  final String? nodeId;

  const DagConnectionException(String message, {this.nodeId, Object? cause})
      : super(message, cause);

  factory DagConnectionException.timeout(String nodeId) =>
      DagConnectionException('Connection timeout', nodeId: nodeId);

  factory DagConnectionException.refused(String nodeId) =>
      DagConnectionException('Connection refused', nodeId: nodeId);

  factory DagConnectionException.notConnected() =>
      const DagConnectionException('Not connected to any node');

  @override
  String toString() =>
      'DagConnectionException: $message${nodeId != null ? ' (node: $nodeId)' : ''}';
}

/// Exception when block is not found
final class DagBlockNotFoundException extends DagException {
  final String hash;

  const DagBlockNotFoundException(this.hash)
      : super('Block not found: $hash');

  @override
  String toString() => 'DagBlockNotFoundException: Block $hash not found';
}

/// Exception when DAG API returns an error
final class DagApiException extends DagException {
  final int? statusCode;

  const DagApiException(String message, {this.statusCode, Object? cause})
      : super(message, cause);

  factory DagApiException.serverError(int statusCode, String message) =>
      DagApiException('Server error: $message', statusCode: statusCode);

  factory DagApiException.invalidResponse(String details) =>
      DagApiException('Invalid response: $details');

  @override
  String toString() =>
      'DagApiException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Exception for WebSocket errors
final class DagWebSocketException extends DagException {
  const DagWebSocketException(super.message, [super.cause]);

  factory DagWebSocketException.disconnected() =>
      const DagWebSocketException('WebSocket disconnected');

  factory DagWebSocketException.messageError(String details) =>
      DagWebSocketException('Message error: $details');
}

/// Exception for cache errors
final class DagCacheException extends DagException {
  const DagCacheException(super.message, [super.cause]);

  factory DagCacheException.full() =>
      const DagCacheException('Cache is full');

  factory DagCacheException.invalidState() =>
      const DagCacheException('Cache in invalid state');
}
