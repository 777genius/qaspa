import 'package:freezed_annotation/freezed_annotation.dart';

part 'miner_config.freezed.dart';
part 'miner_config.g.dart';

/// Configuration for creating a new miner
@freezed
sealed class MinerConfig with _$MinerConfig {
  const MinerConfig._();

  const factory MinerConfig({
    String? name,
    required String targetNode,
    required String payoutAddress,
    @Default(1) int threads,
    double? targetBps,
  }) = _MinerConfig;

  factory MinerConfig.fromJson(Map<String, dynamic> json) => _$MinerConfigFromJson(json);

  Map<String, dynamic> toRequestJson() => {
        if (name != null) 'name': name,
        'target_node': targetNode,
        'payout_address': payoutAddress,
        'threads': threads,
        if (targetBps != null) 'target_bps': targetBps,
      };
}
