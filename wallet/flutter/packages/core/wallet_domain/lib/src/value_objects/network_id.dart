import 'package:equatable/equatable.dart';

/// Network identifier for Kaspa networks.
/// Maps to Rust `NetworkId` from `kaspa-consensus-core`.
enum NetworkType {
  mainnet,
  testnet,
  devnet,
  simnet,
}

/// Network ID value object.
class NetworkId extends Equatable {
  final NetworkType type;
  final int? suffix;

  const NetworkId._(this.type, [this.suffix]);

  /// Mainnet network
  static const mainnet = NetworkId._(NetworkType.mainnet);

  /// Testnet-10
  static const testnet10 = NetworkId._(NetworkType.testnet, 10);

  /// Testnet-11
  static const testnet11 = NetworkId._(NetworkType.testnet, 11);

  /// Devnet
  static const devnet = NetworkId._(NetworkType.devnet);

  /// Simnet
  static const simnet = NetworkId._(NetworkType.simnet);

  /// Create from string representation
  factory NetworkId.fromString(String value) {
    final lower = value.toLowerCase();
    if (lower == 'mainnet') return mainnet;
    if (lower == 'testnet-10') return testnet10;
    if (lower == 'testnet-11') return testnet11;
    if (lower == 'devnet') return devnet;
    if (lower == 'simnet') return simnet;

    // Parse custom testnet suffix
    final match = RegExp(r'testnet-(\d+)').firstMatch(lower);
    if (match != null) {
      final suffixStr = match.group(1);
      if (suffixStr != null) {
        return NetworkId._(NetworkType.testnet, int.parse(suffixStr));
      }
    }

    throw ArgumentError('Invalid network ID: $value');
  }

  /// Whether this is mainnet
  bool get isMainnet => type == NetworkType.mainnet;

  /// Whether this is a testnet
  bool get isTestnet => type == NetworkType.testnet;

  /// Address prefix for this network
  String get addressPrefix => switch (type) {
        NetworkType.mainnet => 'kaspa',
        NetworkType.testnet => 'kaspatest',
        NetworkType.devnet => 'kaspadev',
        NetworkType.simnet => 'kaspasim',
      };

  @override
  String toString() => switch (type) {
        NetworkType.mainnet => 'mainnet',
        NetworkType.testnet => 'testnet-${suffix ?? 10}',
        NetworkType.devnet => 'devnet',
        NetworkType.simnet => 'simnet',
      };

  @override
  List<Object?> get props => [type, suffix];
}
