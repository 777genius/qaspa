import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get detailed information about a transaction.
class GetTransactionDetailsUseCase {
  final TransactionRepository _transactionRepository;

  GetTransactionDetailsUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Future<Transaction?> call({required TransactionId transactionId}) async {
    return _transactionRepository.getTransaction(id: transactionId);
  }
}
