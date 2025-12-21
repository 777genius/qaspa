import 'package:freezed_annotation/freezed_annotation.dart';

part 'node_config.freezed.dart';
part 'node_config.g.dart';

/// Configuration for creating a new node
@freezed
sealed class NodeConfig with _$NodeConfig {
  const NodeConfig._();

  const factory NodeConfig({
    String? name,
    @Default('peer') String role,
    String? connectTo,
    @Default(false) bool utxoindex,
  }) = _NodeConfig;

  factory NodeConfig.fromJson(Map<String, dynamic> json) => _$NodeConfigFromJson(json);

  Map<String, dynamic> toRequestJson() => {
        if (name != null) 'name': name,
        'role': role,
        if (connectTo != null) 'connect_to': connectTo,
        'utxoindex': utxoindex,
      };
}
