import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get transaction history for an account.
class GetTransactionHistoryUseCase {
  final TransactionRepository _transactionRepository;

  GetTransactionHistoryUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Future<List<Transaction>> call({
    required String accountId,
    int? limit,
    int? offset,
  }) async {
    return _transactionRepository.listTransactions(
      accountId: accountId,
      limit: limit,
      offset: offset,
    );
  }
}
