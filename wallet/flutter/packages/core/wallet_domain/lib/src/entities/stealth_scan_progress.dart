import 'package:freezed_annotation/freezed_annotation.dart';

part 'stealth_scan_progress.freezed.dart';
part 'stealth_scan_progress.g.dart';

/// Stealth address scan progress.
@freezed
sealed class StealthScanProgress with _$StealthScanProgress {
  const StealthScanProgress._();

  const factory StealthScanProgress({
    required int scannedBlocks,
    required int totalBlocks,
    required int foundPayments,
    required bool isComplete,
    DateTime? startedAt,
    DateTime? completedAt,
  }) = _StealthScanProgress;

  factory StealthScanProgress.fromJson(Map<String, dynamic> json) =>
      _$StealthScanProgressFromJson(json);

  /// Progress percentage (0.0 - 1.0)
  double get progress {
    if (totalBlocks == 0) return 0.0;
    return (scannedBlocks / totalBlocks).clamp(0.0, 1.0);
  }

  /// Progress percentage as int (0-100)
  int get progressPercent => (progress * 100).round();

  /// Estimated time remaining based on elapsed time.
  /// Returns null if progress is too small (< 2%) for stable estimation.
  Duration? get estimatedTimeRemaining {
    final start = startedAt;
    final currentProgress = progress;
    // Need at least 2% progress for stable time estimation
    if (start == null || currentProgress < 0.02 || isComplete) return null;

    final elapsed = DateTime.now().difference(start);
    final remainingProgress = 1.0 - currentProgress;
    final estimatedTotal = elapsed.inMilliseconds / currentProgress;
    final remaining = (estimatedTotal * remainingProgress).round();

    return Duration(milliseconds: remaining);
  }
}
