import 'package:freezed_annotation/freezed_annotation.dart';

part 'block_hash.freezed.dart';

/// Type-safe block hash value object
@freezed
sealed class BlockHash with _$BlockHash {
  const BlockHash._();

  const factory BlockHash(String value) = _BlockHash;

  /// Short hash for display (first 8 characters)
  String get short => value.length > 8 ? value.substring(0, 8) : value;

  /// Very short hash for compact display (first 2 characters)
  String get veryShort => value.length > 2 ? value.substring(0, 2) : value;

  /// Check if hash is empty
  bool get isEmpty => value.isEmpty;

  /// Check if hash is not empty
  bool get isNotEmpty => value.isNotEmpty;

  factory BlockHash.fromJson(dynamic json) {
    if (json is String) return BlockHash(json);
    throw ArgumentError('BlockHash.fromJson expects a String, got ${json.runtimeType}');
  }

  String toJson() => value;

  /// Empty block hash constant
  static const empty = BlockHash('');
}
