import 'package:json_annotation/json_annotation.dart';

import '../value_objects/network_id.dart';
import '../value_objects/transaction_id.dart';

/// Maximum value for Rust u64 (2^64 - 1).
/// Used to validate BigInt values before passing to Rust FFI.
final BigInt _maxU64 = BigInt.parse('18446744073709551615');

/// JSON converter for BigInt values.
/// Converts BigInt to/from String for JSON serialization.
/// This is necessary because JSON doesn't support BigInt natively.
///
/// Validates that:
/// - Input is a valid numeric string
/// - Value is non-negative (for SOMPI amounts)
/// - Value fits in Rust u64 range (0 to 2^64 - 1)
class BigIntConverter implements JsonConverter<BigInt, String> {
  const BigIntConverter();

  @override
  BigInt fromJson(String json) {
    if (json.isEmpty) {
      throw FormatException('BigInt cannot be empty', json);
    }
    try {
      final value = BigInt.parse(json);
      if (value.isNegative) {
        throw FormatException('BigInt cannot be negative for SOMPI amounts', json);
      }
      if (value > _maxU64) {
        throw FormatException(
          'BigInt exceeds maximum u64 value: $value > $_maxU64',
          json,
        );
      }
      return value;
    } on FormatException {
      throw FormatException('Invalid BigInt format: "$json"', json);
    }
  }

  @override
  String toJson(BigInt object) {
    if (object.isNegative) {
      throw ArgumentError.value(object, 'object', 'Cannot serialize negative BigInt');
    }
    if (object > _maxU64) {
      throw ArgumentError.value(object, 'object', 'Value exceeds u64 range');
    }
    return object.toString();
  }
}

/// JSON converter for nullable BigInt values.
/// Same validation as [BigIntConverter] but allows null.
class NullableBigIntConverter implements JsonConverter<BigInt?, String?> {
  const NullableBigIntConverter();

  @override
  BigInt? fromJson(String? json) {
    if (json == null) return null;
    if (json.isEmpty) {
      throw FormatException('BigInt cannot be empty', json);
    }
    try {
      final value = BigInt.parse(json);
      if (value.isNegative) {
        throw FormatException('BigInt cannot be negative for SOMPI amounts', json);
      }
      if (value > _maxU64) {
        throw FormatException(
          'BigInt exceeds maximum u64 value: $value > $_maxU64',
          json,
        );
      }
      return value;
    } on FormatException {
      throw FormatException('Invalid BigInt format: "$json"', json);
    }
  }

  @override
  String? toJson(BigInt? object) {
    if (object == null) return null;
    if (object.isNegative) {
      throw ArgumentError.value(object, 'object', 'Cannot serialize negative BigInt');
    }
    if (object > _maxU64) {
      throw ArgumentError.value(object, 'object', 'Value exceeds u64 range');
    }
    return object.toString();
  }
}

/// JSON converter for NetworkId values.
class NetworkIdConverter implements JsonConverter<NetworkId, String> {
  const NetworkIdConverter();

  @override
  NetworkId fromJson(String json) => NetworkId.fromString(json);

  @override
  String toJson(NetworkId object) => object.toString();
}

/// JSON converter for TransactionId values.
class TransactionIdConverter implements JsonConverter<TransactionId, String> {
  const TransactionIdConverter();

  @override
  TransactionId fromJson(String json) => TransactionId.fromHex(json);

  @override
  String toJson(TransactionId object) => object.hex;
}
