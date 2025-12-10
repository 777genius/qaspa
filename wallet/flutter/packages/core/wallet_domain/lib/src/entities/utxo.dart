import 'package:freezed_annotation/freezed_annotation.dart';

import '../converters/bigint_converter.dart';
import '../value_objects/transaction_id.dart';

part 'utxo.freezed.dart';
part 'utxo.g.dart';

/// Unspent Transaction Output (UTXO).
@freezed
sealed class Utxo with _$Utxo {
  const Utxo._();

  const factory Utxo({
    @TransactionIdConverter() required TransactionId transactionId,
    required int index,
    @BigIntConverter() required BigInt amount,
    required String address,
    required int blockDaaScore,
    required bool isCoinbase,
    required bool isLocked,
  }) = _Utxo;

  factory Utxo.fromJson(Map<String, dynamic> json) => _$UtxoFromJson(json);

  /// Outpoint identifier (txid:index)
  String get outpoint => '${transactionId.hex}:$index';
}

/// UTXO set for an account.
@freezed
sealed class UtxoSet with _$UtxoSet {
  const UtxoSet._();

  const factory UtxoSet({
    required List<Utxo> mature,
    required List<Utxo> pending,
    required List<Utxo> stasis,
  }) = _UtxoSet;

  factory UtxoSet.fromJson(Map<String, dynamic> json) =>
      _$UtxoSetFromJson(json);

  /// Total count of all UTXOs.
  int get totalCount => mature.length + pending.length + stasis.length;

  /// Total mature amount.
  BigInt get matureAmount =>
      mature.fold(BigInt.zero, (sum, utxo) => sum + utxo.amount);

  /// Total pending amount.
  BigInt get pendingAmount =>
      pending.fold(BigInt.zero, (sum, utxo) => sum + utxo.amount);

  /// All UTXOs combined.
  List<Utxo> get all => [...mature, ...pending, ...stasis];
}
