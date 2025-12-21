import 'package:freezed_annotation/freezed_annotation.dart';

part 'daa_score.freezed.dart';

/// Type-safe DAA (Difficulty Adjustment Algorithm) score value object
/// Used for block ordering and timeline positioning
@freezed
sealed class DaaScore with _$DaaScore {
  const DaaScore._();

  const factory DaaScore(int value) = _DaaScore;

  /// Comparison operators
  bool operator >(DaaScore other) => value > other.value;
  bool operator <(DaaScore other) => value < other.value;
  bool operator >=(DaaScore other) => value >= other.value;
  bool operator <=(DaaScore other) => value <= other.value;

  /// Arithmetic operations
  DaaScore operator +(int delta) => DaaScore(value + delta);
  DaaScore operator -(int delta) => DaaScore(value - delta);

  /// Difference between two scores
  int difference(DaaScore other) => (value - other.value).abs();

  factory DaaScore.fromJson(dynamic json) {
    if (json is int) return DaaScore(json);
    if (json is String) {
      final parsed = int.tryParse(json);
      if (parsed != null) return DaaScore(parsed);
      throw FormatException('DaaScore.fromJson: invalid number format "$json"');
    }
    throw ArgumentError('DaaScore.fromJson expects int or String, got ${json.runtimeType}');
  }

  int toJson() => value;

  /// Zero DAA score constant
  static const zero = DaaScore(0);
}
