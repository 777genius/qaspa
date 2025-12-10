import '../entities/transaction.dart';
import '../value_objects/address.dart';
import '../value_objects/amount.dart';
import '../value_objects/transaction_id.dart';

/// Transaction send request parameters.
class SendRequest {
  final String accountId;
  final Address destination;
  final Amount amount;
  final Amount? priorityFee;
  final String? note;

  const SendRequest({
    required this.accountId,
    required this.destination,
    required this.amount,
    this.priorityFee,
    this.note,
  });
}

/// Transaction estimate for preview before sending.
class TransactionEstimate {
  final Amount amount;
  final Amount fee;
  final Amount total;
  final int utxoCount;

  const TransactionEstimate({
    required this.amount,
    required this.fee,
    required this.total,
    required this.utxoCount,
  });
}

/// Repository interface for transaction operations.
/// Implementations: RustTransactionRepository (wallet_data package)
abstract interface class TransactionRepository {
  /// Start syncing transactions for an account.
  void startSync(String accountId);

  /// Stop syncing transactions for an account.
  void stopSync(String accountId);

  /// Dispose repository and release all resources.
  void dispose();

  /// Get transaction by ID
  Future<Transaction?> getTransaction({required TransactionId id});

  /// List transactions for an account
  Future<List<Transaction>> listTransactions({
    required String accountId,
    int? limit,
    int? offset,
    TransactionKind? kindFilter,
  });

  /// Watch transaction updates (reactive stream)
  Stream<List<Transaction>> watchTransactions({required String accountId});

  /// Watch for new transactions
  Stream<Transaction> watchNewTransactions({required String accountId});

  /// Estimate transaction fee
  Future<TransactionEstimate> estimateTransaction({
    required SendRequest request,
  });

  /// Send a transaction
  Future<TransactionId> sendTransaction({
    required SendRequest request,
    required String password,
  });

  /// Send max amount (sweep)
  Future<TransactionId> sendMax({
    required String accountId,
    required Address destination,
    required String password,
    String? note,
  });

  /// Cancel pending transaction (if possible)
  Future<bool> cancelTransaction({required TransactionId id});

  /// Add note to transaction
  Future<void> addTransactionNote({
    required TransactionId id,
    required String note,
  });

  /// Get transaction count for account
  Future<int> getTransactionCount({required String accountId});
}
