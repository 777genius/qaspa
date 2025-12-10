import 'package:freezed_annotation/freezed_annotation.dart';

import '../converters/bigint_converter.dart';
import '../value_objects/transaction_id.dart';
import '../value_objects/network_id.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// Transaction kind enumeration.
/// Maps 1:1 to Rust `TransactionKind` from `wallet/core/src/storage/transaction/kind.rs`
enum TransactionKind {
  /// Reorg transaction (UTXO restructuring)
  reorg,

  /// Stasis transaction (coinbase during reorg)
  stasis,

  /// Internal batch/sweep transaction
  batch,

  /// Change transaction
  change,

  /// Incoming transaction
  incoming,

  /// Outgoing transaction
  outgoing,

  /// External incoming transaction
  external,

  /// Incoming transfer between accounts
  transferIncoming,

  /// Outgoing transfer between accounts
  transferOutgoing,
}

/// Transaction entity representing a wallet transaction.
///
/// Uses BigInt for amount and fee to support full u64 range from Rust.
@freezed
sealed class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    @TransactionIdConverter() required TransactionId id,
    required TransactionKind kind,
    @NetworkIdConverter() required NetworkId networkId,

    /// Transaction timestamp (Unix milliseconds)
    required int timestamp,

    /// Amount in SOMPI (always positive, direction determined by kind)
    @BigIntConverter() required BigInt amount,

    /// Fee paid in SOMPI (for outgoing transactions)
    @NullableBigIntConverter() BigInt? fee,

    /// Sender addresses (for incoming)
    List<String>? fromAddresses,

    /// Recipient addresses (for outgoing)
    List<String>? toAddresses,

    /// User note
    String? note,

    /// Custom metadata (JSON string)
    String? metadata,

    /// Block DAA score when accepted
    int? acceptedDaaScore,

    /// Whether transaction is confirmed
    @Default(false) bool isConfirmed,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  /// SOMPI per KAS constant
  static final BigInt _sompiPerKas = BigInt.from(100000000);

  /// Whether this is an incoming transaction
  bool get isIncoming =>
      kind == TransactionKind.incoming ||
      kind == TransactionKind.external ||
      kind == TransactionKind.transferIncoming;

  /// Whether this is an outgoing transaction
  bool get isOutgoing =>
      kind == TransactionKind.outgoing ||
      kind == TransactionKind.transferOutgoing;

  /// Signed amount (negative for outgoing)
  BigInt get signedAmount => isOutgoing ? -amount : amount;

  // ===========================================================================
  // KAS CONVERSION (FOR DISPLAY ONLY)
  // ===========================================================================
  //
  // WARNING: These double values may lose precision for amounts > 9 million KAS
  // (2^53 / 100,000,000 ≈ 9,007,199 KAS)
  //
  // For calculations, use BigInt values (amount, fee) directly.
  // For precise string formatting, use formatAmount(), formatFee().
  // ===========================================================================

  /// Amount in KAS. WARNING: May lose precision for > 9M KAS.
  double get amountKas => amount.toDouble() / _sompiPerKas.toDouble();

  /// Fee in KAS. WARNING: May lose precision for > 9M KAS.
  double? get feeKas =>
      fee != null ? fee!.toDouble() / _sompiPerKas.toDouble() : null;

  /// Format amount as KAS string
  String formatAmount({int decimals = 8}) {
    final kasWhole = amount ~/ _sompiPerKas;
    final kasFraction = amount.remainder(_sompiPerKas);

    if (kasFraction == BigInt.zero) {
      return '$kasWhole.0';
    }

    final fractionStr = kasFraction.toString().padLeft(8, '0');
    final trimmed = fractionStr
        .substring(0, decimals.clamp(0, 8))
        .replaceAll(RegExp(r'0+$'), '');

    return trimmed.isEmpty ? '$kasWhole.0' : '$kasWhole.$trimmed';
  }

  /// Format fee as KAS string
  String? formatFee({int decimals = 8}) {
    if (fee == null) return null;

    final kasWhole = fee! ~/ _sompiPerKas;
    final kasFraction = fee!.remainder(_sompiPerKas);

    if (kasFraction == BigInt.zero) {
      return '$kasWhole.0';
    }

    final fractionStr = kasFraction.toString().padLeft(8, '0');
    final trimmed = fractionStr
        .substring(0, decimals.clamp(0, 8))
        .replaceAll(RegExp(r'0+$'), '');

    return trimmed.isEmpty ? '$kasWhole.0' : '$kasWhole.$trimmed';
  }

  /// Transaction date
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
