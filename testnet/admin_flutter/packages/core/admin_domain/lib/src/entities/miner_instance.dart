import 'package:freezed_annotation/freezed_annotation.dart';

part 'miner_instance.freezed.dart';
part 'miner_instance.g.dart';

/// Miner status enum
enum MinerStatus {
  creating,
  starting,
  running,
  stopping,
  stopped,
  error,
}

/// Represents a miner agent instance
@freezed
sealed class MinerInstance with _$MinerInstance {
  const MinerInstance._();

  const factory MinerInstance({
    required String id,
    required String name,
    required String status,
    required String targetNode,
    required double hashrate,
    required int blocksFound,
  }) = _MinerInstance;

  factory MinerInstance.fromJson(Map<String, dynamic> json) => _$MinerInstanceFromJson(json);

  bool get isRunning => status == 'running';

  String get hashrateFormatted {
    if (hashrate >= 1e9) {
      return '${(hashrate / 1e9).toStringAsFixed(2)} GH/s';
    } else if (hashrate >= 1e6) {
      return '${(hashrate / 1e6).toStringAsFixed(2)} MH/s';
    } else if (hashrate >= 1e3) {
      return '${(hashrate / 1e3).toStringAsFixed(2)} KH/s';
    } else {
      return '${hashrate.toStringAsFixed(2)} H/s';
    }
  }
}
