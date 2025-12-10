import 'package:wallet_domain/wallet_domain.dart';

/// Use case for estimating transaction fees.
class EstimateTransactionUseCase {
  final TransactionRepository _transactionRepository;

  EstimateTransactionUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  /// Estimate transaction fee.
  ///
  /// Throws:
  /// - [ArgumentError] if accountId is empty
  /// - [InvalidAmountException] if amount is zero
  Future<TransactionEstimate> call({
    required String accountId,
    required Address destination,
    required Amount amount,
    Amount? priorityFee,
  }) async {
    // Validate accountId
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Account ID cannot be empty');
    }

    // Validate amount is positive
    if (amount.isZero) {
      throw InvalidAmountException(
        code: 'ZERO_AMOUNT',
        message: 'Amount must be greater than zero',
      );
    }

    return _transactionRepository.estimateTransaction(
      request: SendRequest(
        accountId: accountId,
        destination: destination,
        amount: amount,
        priorityFee: priorityFee,
      ),
    );
  }
}
