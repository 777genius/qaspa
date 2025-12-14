import 'dart:developer' as developer;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/address.dart';
import 'balance.dart';

part 'account.freezed.dart';
part 'account.g.dart';

/// Account kind enumeration.
/// Maps to Rust account variants from `wallet/core/src/account/variants/`
enum AccountKind {
  /// BIP-32 derived account
  bip32,

  /// Legacy account (single keypair)
  legacy,

  /// Multi-signature account
  multisig,

  /// Stealth address account
  stealth,

  /// Watch-only account
  watchOnly,

  /// Resident account (hardware wallet)
  resident,
}

/// Account entity representing a wallet account.
/// Maps to Rust `Account` trait from `wallet/core/src/account/mod.rs`
@freezed
sealed class Account with _$Account {
  const Account._();

  const factory Account({
    /// Unique account identifier
    required String id,

    /// Parent wallet ID
    required String walletId,

    /// Account name (user-defined)
    required String name,

    /// Account kind/type
    required AccountKind kind,

    /// Account index in derivation path
    required int accountIndex,

    /// Whether account is active/enabled
    @Default(true) bool isActive,

    /// Receive address index (for BIP-32)
    @Default(0) int receiveAddressIndex,

    /// Change address index (for BIP-32)
    @Default(0) int changeAddressIndex,

    /// Current balance (may be null if not loaded)
    Balance? balance,

    /// Current receive address
    String? receiveAddress,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  /// Whether this is a stealth account
  bool get isStealth => kind == AccountKind.stealth;

  /// Whether this is a watch-only account
  bool get isWatchOnly => kind == AccountKind.watchOnly;

  /// Whether this account can sign transactions
  bool get canSign => kind != AccountKind.watchOnly;

  /// Parse receive address.
  /// Returns null if address is null or cannot be parsed.
  Address? get receiveAddressParsed {
    if (receiveAddress == null) return null;
    try {
      return Address.fromString(receiveAddress!);
    } catch (e) {
      developer.log(
        'Failed to parse address: $receiveAddress',
        error: e,
        name: 'Account',
      );
      return null;
    }
  }

  /// Display name with index
  String get displayName => name.isNotEmpty ? name : 'Account ${accountIndex + 1}';

  /// Short ID for display
  String get shortId => id.length > 8 ? '${id.substring(0, 8)}...' : id;
}

/// Account descriptor for listing accounts without full balance data.
@freezed
sealed class AccountDescriptor with _$AccountDescriptor {
  const AccountDescriptor._();

  const factory AccountDescriptor({
    required String id,
    required String walletId,
    required String name,
    required AccountKind kind,
    required int accountIndex,
  }) = _AccountDescriptor;

  factory AccountDescriptor.fromJson(Map<String, dynamic> json) =>
      _$AccountDescriptorFromJson(json);
}
