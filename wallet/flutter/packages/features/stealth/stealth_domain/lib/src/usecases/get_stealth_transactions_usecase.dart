import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get stealth transactions for an account.
class GetStealthTransactionsUseCase {
  final TransactionRepository _transactionRepository;

  GetStealthTransactionsUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Future<List<Transaction>> call({
    required String accountId,
    int? limit,
  }) async {
    return _transactionRepository.listTransactions(
      accountId: accountId,
      limit: limit ?? 20,
    );
  }
}
