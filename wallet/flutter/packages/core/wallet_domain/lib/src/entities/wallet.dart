import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/network_id.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

/// Wallet entity representing a user's wallet.
/// Maps to Rust `Wallet` from `wallet/core/src/wallet/mod.rs`
@freezed
sealed class Wallet with _$Wallet {
  const Wallet._();

  const factory Wallet({
    /// Unique wallet identifier
    required String id,

    /// Wallet name (user-defined)
    required String name,

    /// Network ID (mainnet/testnet)
    required String networkId,

    /// Whether wallet is currently open/unlocked
    @Default(false) bool isOpen,

    /// Wallet creation timestamp
    required int createdAt,

    /// Last accessed timestamp
    int? lastAccessedAt,

    /// Account IDs belonging to this wallet
    @Default([]) List<String> accountIds,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  /// Parse network ID
  NetworkId get network => NetworkId.fromString(networkId);

  /// Whether this is a mainnet wallet
  bool get isMainnet => network.isMainnet;

  /// Creation date
  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  /// Last access date
  DateTime? get lastAccessedDate => lastAccessedAt != null
      ? DateTime.fromMillisecondsSinceEpoch(lastAccessedAt!)
      : null;

  /// Number of accounts
  int get accountCount => accountIds.length;

  /// Default account ID (first account, or null if no accounts)
  String? get defaultAccountId => accountIds.isNotEmpty ? accountIds.first : null;
}

/// Wallet descriptor for listing wallets without full data.
@freezed
sealed class WalletDescriptor with _$WalletDescriptor {
  const WalletDescriptor._();

  const factory WalletDescriptor({
    required String id,
    required String name,
    required String networkId,
    required int createdAt,
  }) = _WalletDescriptor;

  factory WalletDescriptor.fromJson(Map<String, dynamic> json) =>
      _$WalletDescriptorFromJson(json);

  /// Parse network ID
  NetworkId get network => NetworkId.fromString(networkId);
}
