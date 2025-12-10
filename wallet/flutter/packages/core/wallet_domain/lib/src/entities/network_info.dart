import 'package:freezed_annotation/freezed_annotation.dart';

import '../converters/bigint_converter.dart';
import '../value_objects/network_id.dart';

part 'network_info.freezed.dart';
part 'network_info.g.dart';

/// Network information from connected node.
@freezed
sealed class NetworkInfo with _$NetworkInfo {
  const NetworkInfo._();

  const factory NetworkInfo({
    @NetworkIdConverter() required NetworkId networkId,
    required int blockCount,
    required int headerCount,
    required int daaScore,
    required int difficulty,
    required String nodeVersion,
    required bool isSynced,
    int? peerCount,
    int? mempoolSize,
  }) = _NetworkInfo;

  factory NetworkInfo.fromJson(Map<String, dynamic> json) =>
      _$NetworkInfoFromJson(json);

  /// Progress percentage (0.0 - 1.0)
  double get syncProgress {
    if (headerCount == 0) return 0.0;
    return (blockCount / headerCount).clamp(0.0, 1.0);
  }
}
