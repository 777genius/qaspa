import 'package:equatable/equatable.dart';

/// Transaction ID value object.
/// Represents a 32-byte transaction hash as hex string.
class TransactionId extends Equatable {
  final String value;

  const TransactionId._(this.value);

  /// Create from hex string
  factory TransactionId.fromHex(String hex) {
    final normalized = hex.toLowerCase().replaceAll('0x', '');
    if (normalized.length != 64) {
      throw ArgumentError('Transaction ID must be 64 hex characters');
    }
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(normalized)) {
      throw ArgumentError('Transaction ID must be valid hex');
    }
    return TransactionId._(normalized);
  }

  /// Create from raw bytes
  factory TransactionId.fromBytes(List<int> bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Transaction ID must be 32 bytes');
    }
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return TransactionId._(hex);
  }

  /// Get as hex string (without 0x prefix)
  String get hex => value;

  /// Get as hex string with 0x prefix
  String get hexWithPrefix => '0x$value';

  /// Get shortened display string
  String get short => '${value.substring(0, 8)}...${value.substring(56)}';

  /// Convert to bytes
  List<int> toBytes() {
    final result = <int>[];
    for (var i = 0; i < value.length; i += 2) {
      result.add(int.parse(value.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  @override
  String toString() => value;

  @override
  List<Object?> get props => [value];
}
