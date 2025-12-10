import 'package:freezed_annotation/freezed_annotation.dart';

import '../converters/bigint_converter.dart';

part 'balance.freezed.dart';
part 'balance.g.dart';

/// Balance entity representing wallet/account balance.
/// Maps 1:1 to Rust `Balance` struct from `wallet/core/src/utxo/balance.rs`
///
/// Uses BigInt for SOMPI values to support the full u64 range from Rust
/// (max ~18.4 quintillion SOMPI = ~184 billion KAS)
@freezed
sealed class Balance with _$Balance {
  const Balance._();

  const factory Balance({
    /// Confirmed/mature balance in SOMPI (1 KAS = 100,000,000 SOMPI)
    @BigIntConverter() required BigInt mature,

    /// Pending incoming balance in SOMPI
    @BigIntConverter() required BigInt pending,

    /// Outgoing balance (being sent) in SOMPI
    @BigIntConverter() required BigInt outgoing,

    /// Number of mature UTXOs
    required int matureUtxoCount,

    /// Number of pending UTXOs
    required int pendingUtxoCount,

    /// Number of stasis UTXOs (coinbase during maturity period)
    required int stasisUtxoCount,
  }) = _Balance;

  factory Balance.fromJson(Map<String, dynamic> json) =>
      _$BalanceFromJson(json);

  /// Zero balance
  factory Balance.zero() => Balance(
        mature: BigInt.zero,
        pending: BigInt.zero,
        outgoing: BigInt.zero,
        matureUtxoCount: 0,
        pendingUtxoCount: 0,
        stasisUtxoCount: 0,
      );

  /// SOMPI per KAS constant
  static final BigInt sompiPerKas = BigInt.from(100000000);

  /// Total available balance (mature - outgoing), never negative
  BigInt get available => mature > outgoing ? mature - outgoing : BigInt.zero;

  /// Total balance including pending
  BigInt get total => mature + pending;

  /// Whether balance is zero
  bool get isEmpty =>
      mature == BigInt.zero && pending == BigInt.zero && outgoing == BigInt.zero;

  // ===========================================================================
  // KAS CONVERSION (FOR DISPLAY ONLY)
  // ===========================================================================
  //
  // WARNING: These double values may lose precision for amounts > 9 million KAS
  // (2^53 / 100,000,000 ≈ 9,007,199 KAS)
  //
  // For calculations, use BigInt values (mature, pending, etc.) directly.
  // For precise string formatting, use formatMature(), formatAvailable(), etc.
  // ===========================================================================

  /// Mature balance in KAS. WARNING: May lose precision for > 9M KAS.
  double get matureKas => mature.toDouble() / sompiPerKas.toDouble();

  /// Pending balance in KAS. WARNING: May lose precision for > 9M KAS.
  double get pendingKas => pending.toDouble() / sompiPerKas.toDouble();

  /// Outgoing balance in KAS. WARNING: May lose precision for > 9M KAS.
  double get outgoingKas => outgoing.toDouble() / sompiPerKas.toDouble();

  /// Available balance in KAS. WARNING: May lose precision for > 9M KAS.
  double get availableKas => available.toDouble() / sompiPerKas.toDouble();

  /// Total balance in KAS. WARNING: May lose precision for > 9M KAS.
  double get totalKas => total.toDouble() / sompiPerKas.toDouble();

  /// Format mature balance as KAS string
  String formatMature({int decimals = 8}) => _formatKas(mature, decimals);

  /// Format available balance as KAS string
  String formatAvailable({int decimals = 8}) => _formatKas(available, decimals);

  /// Format total balance as KAS string
  String formatTotal({int decimals = 8}) => _formatKas(total, decimals);

  String _formatKas(BigInt sompi, int decimals) {
    final kasWhole = sompi ~/ sompiPerKas;
    final kasFraction = sompi.remainder(sompiPerKas);

    if (kasFraction == BigInt.zero) {
      return '$kasWhole.0';
    }

    final fractionStr = kasFraction.toString().padLeft(8, '0');
    final trimmed = fractionStr.substring(
      0,
      decimals.clamp(0, 8),
    ).replaceAll(RegExp(r'0+$'), '');

    return trimmed.isEmpty ? '$kasWhole.0' : '$kasWhole.$trimmed';
  }
}
