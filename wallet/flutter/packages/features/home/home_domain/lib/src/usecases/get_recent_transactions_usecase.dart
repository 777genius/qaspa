import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case for getting recent transactions.
@injectable
class GetRecentTransactionsUseCase {
  final TransactionRepository _transactionRepository;

  GetRecentTransactionsUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  /// Get recent transactions for account.
  Future<List<Transaction>> call({
    required String accountId,
    int limit = 10,
  }) async {
    return _transactionRepository.listTransactions(
      accountId: accountId,
      limit: limit,
    );
  }
}
