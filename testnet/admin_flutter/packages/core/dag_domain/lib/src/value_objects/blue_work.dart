import 'package:freezed_annotation/freezed_annotation.dart';

part 'blue_work.freezed.dart';

/// Type-safe Blue Work value object
/// Represents 192-bit cumulative work as hex string
/// Used for chain selection (higher blue work = stronger chain)
@freezed
sealed class BlueWork with _$BlueWork {
  const BlueWork._();

  const factory BlueWork(String hexValue) = _BlueWork;

  /// Create from hex string
  factory BlueWork.fromHex(String hex) => BlueWork(hex);

  /// Compare two BlueWork values
  /// Returns: negative if this < other, zero if equal, positive if this > other
  int compareTo(BlueWork other) {
    if (hexValue.isEmpty && other.hexValue.isEmpty) return 0;
    if (hexValue.isEmpty) return -1;
    if (other.hexValue.isEmpty) return 1;

    try {
      final a = BigInt.parse(hexValue, radix: 16);
      final b = BigInt.parse(other.hexValue, radix: 16);
      return a.compareTo(b);
    } catch (_) {
      return hexValue.compareTo(other.hexValue);
    }
  }

  /// Check if this BlueWork is greater than other
  bool isGreaterThan(BlueWork other) => compareTo(other) > 0;

  /// Check if this BlueWork is less than other
  bool isLessThan(BlueWork other) => compareTo(other) < 0;

  /// Short representation for display
  String get short {
    if (hexValue.length <= 8) return hexValue;
    // Safe substring with length validation
    final prefixLen = hexValue.length >= 4 ? 4 : hexValue.length;
    final suffixLen = hexValue.length >= 4 ? 4 : hexValue.length;
    return '${hexValue.substring(0, prefixLen)}...${hexValue.substring(hexValue.length - suffixLen)}';
  }

  factory BlueWork.fromJson(dynamic json) {
    if (json is String) return BlueWork(json);
    throw ArgumentError('BlueWork.fromJson expects a String, got ${json.runtimeType}');
  }

  String toJson() => hexValue;

  /// Empty blue work constant
  static const empty = BlueWork('0');
}
