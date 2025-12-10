import 'dart:convert';
import 'dart:developer' as developer;

import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

import '../database/history_database.dart';

/// Local datasource for storing transaction history using Drift.
@LazySingleton()
class LocalDatasource {
  final HistoryDatabase _db;

  static const _logName = 'LocalDatasource';

  LocalDatasource(this._db);

  // === Transaction History ===

  /// Save transaction with account ID.
  Future<void> saveTransactionForAccount(
    String accountId,
    Transaction tx,
  ) async {
    await _db.insertTransaction(
      TransactionRecord(
        id: tx.id.hex,
        accountId: accountId,
        kind: tx.kind.name,
        networkId: tx.networkId.toString(),
        timestamp: tx.timestamp,
        amount: tx.amount.toString(),
        fee: tx.fee?.toString(),
        fromAddresses:
            tx.fromAddresses != null ? jsonEncode(tx.fromAddresses) : null,
        toAddresses:
            tx.toAddresses != null ? jsonEncode(tx.toAddresses) : null,
        note: tx.note,
        metadata: tx.metadata,
        acceptedDaaScore: tx.acceptedDaaScore,
        isConfirmed: tx.isConfirmed,
      ),
    );
  }

  /// Get transactions for account.
  Future<List<Transaction>> getTransactions({
    required String accountId,
    int? limit,
    int? offset,
    TransactionKind? kindFilter,
  }) async {
    final records = await _db.getTransactions(
      accountId: accountId,
      limit: limit,
      offset: offset,
      kind: kindFilter?.name,
    );
    return records.map(_recordToTransaction).toList();
  }

  /// Watch transactions for account (reactive stream).
  /// [limit] defaults to 100 to prevent OOM with large transaction history.
  Stream<List<Transaction>> watchTransactions({
    required String accountId,
    int limit = 100,
  }) {
    return _db.watchTransactions(accountId: accountId, limit: limit).map(
          (records) => records.map(_recordToTransaction).toList(),
        );
  }

  /// Get single transaction by ID.
  Future<Transaction?> getTransaction({required TransactionId id}) async {
    final record = await _db.getTransactionById(id.hex);
    return record != null ? _recordToTransaction(record) : null;
  }

  /// Update transaction note.
  Future<void> updateTransactionNote({
    required TransactionId id,
    required String note,
  }) async {
    await _db.updateTransactionNote(id.hex, note);
  }

  /// Update transaction confirmation status.
  Future<void> markTransactionConfirmed({
    required TransactionId id,
    required int daaScore,
  }) async {
    await _db.markConfirmed(id.hex, daaScore);
  }

  /// Get transaction count for account.
  Future<int> getTransactionCount({required String accountId}) async {
    return _db.getTransactionCount(accountId);
  }

  /// Clear all transactions for account.
  Future<void> clearTransactions({required String accountId}) async {
    await _db.deleteTransactionsForAccount(accountId);
  }

  // === Helpers ===

  /// Safely decode JSON string list, returning null on failure
  List<String>? _safeDecodeAddresses(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        // Filter out non-strings and null values
        return List<String>.from(decoded.whereType<String>());
      }
      developer.log(
        'Invalid addresses format: expected List, got ${decoded.runtimeType}',
        name: _logName,
        level: 900,
      );
      return null;
    } catch (e) {
      developer.log(
        'Failed to decode addresses JSON: $e',
        name: _logName,
        level: 1000,
        error: e,
      );
      return null;
    }
  }

  /// Parse required BigInt - throws on failure.
  /// For amounts, we MUST not silently return zero as that could hide fund loss.
  BigInt _parseRequiredBigInt(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      throw FormatException(
        'Required BigInt field "$fieldName" is null or empty',
      );
    }
    try {
      final parsed = BigInt.parse(value);
      if (parsed.isNegative) {
        throw FormatException(
          'BigInt field "$fieldName" cannot be negative: $value',
        );
      }
      return parsed;
    } on FormatException {
      throw FormatException(
        'Invalid BigInt format in field "$fieldName": $value',
      );
    }
  }

  /// Safely parse optional BigInt - returns null on failure.
  /// For optional fields like fee, null is acceptable.
  BigInt? _parseOptionalBigInt(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final parsed = BigInt.parse(value);
      if (parsed.isNegative) {
        developer.log(
          'Negative BigInt value encountered: $value',
          name: _logName,
          level: 900,
        );
        return null;
      }
      return parsed;
    } catch (e) {
      developer.log(
        'Failed to parse optional BigInt: $value',
        name: _logName,
        level: 900,
        error: e,
      );
      return null;
    }
  }

  Transaction _recordToTransaction(TransactionRecord record) {
    // Parse amount - this is critical and MUST not fail silently
    final amount = _parseRequiredBigInt(record.amount, 'amount');

    return Transaction(
      id: TransactionId.fromHex(record.id),
      kind: TransactionKind.values.firstWhere(
        (k) => k.name == record.kind,
        orElse: () => TransactionKind.incoming,
      ),
      networkId: NetworkId.fromString(record.networkId),
      timestamp: record.timestamp,
      amount: amount,
      fee: _parseOptionalBigInt(record.fee),
      fromAddresses: _safeDecodeAddresses(record.fromAddresses),
      toAddresses: _safeDecodeAddresses(record.toAddresses),
      note: record.note,
      metadata: record.metadata,
      acceptedDaaScore: record.acceptedDaaScore,
      isConfirmed: record.isConfirmed,
    );
  }
}
