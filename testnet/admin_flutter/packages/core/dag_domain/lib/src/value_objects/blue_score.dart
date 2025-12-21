import 'package:freezed_annotation/freezed_annotation.dart';

part 'blue_score.freezed.dart';

/// Type-safe Blue Score value object
/// Represents the consensus ordering number of a block
@freezed
sealed class BlueScore with _$BlueScore {
  const BlueScore._();

  const factory BlueScore(int value) = _BlueScore;

  /// Comparison operators
  bool operator >(BlueScore other) => value > other.value;
  bool operator <(BlueScore other) => value < other.value;
  bool operator >=(BlueScore other) => value >= other.value;
  bool operator <=(BlueScore other) => value <= other.value;

  factory BlueScore.fromJson(dynamic json) {
    if (json is int) return BlueScore(json);
    if (json is String) {
      final parsed = int.tryParse(json);
      if (parsed != null) return BlueScore(parsed);
      throw FormatException('BlueScore.fromJson: invalid number format "$json"');
    }
    throw ArgumentError('BlueScore.fromJson expects int or String, got ${json.runtimeType}');
  }

  int toJson() => value;

  /// Zero blue score constant
  static const zero = BlueScore(0);
}
