import 'package:wallet_domain/wallet_domain.dart';

/// Use case to watch transaction history stream.
class WatchTransactionHistoryUseCase {
  final TransactionRepository _transactionRepository;

  WatchTransactionHistoryUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Stream<List<Transaction>> call({required String accountId}) {
    return _transactionRepository.watchTransactions(accountId: accountId);
  }
}
