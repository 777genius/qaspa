/// Base exception for admin operations
sealed class AdminException implements Exception {
  final String message;
  final Object? cause;

  const AdminException(this.message, [this.cause]);

  @override
  String toString() => 'AdminException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Network error
class NetworkException extends AdminException {
  final int? statusCode;

  const NetworkException(String message, {this.statusCode, Object? cause})
      : super(message, cause);

  @override
  String toString() =>
      'NetworkException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Entity not found
class NotFoundException extends AdminException {
  final String entityType;
  final String entityId;

  const NotFoundException(this.entityType, this.entityId)
      : super('$entityType not found: $entityId');
}

/// Operation failed
class OperationException extends AdminException {
  const OperationException(super.message, [super.cause]);
}

/// Connection error
class ConnectionException extends AdminException {
  const ConnectionException(super.message, [super.cause]);
}
