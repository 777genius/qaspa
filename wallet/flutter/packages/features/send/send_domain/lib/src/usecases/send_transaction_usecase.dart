import 'package:wallet_domain/wallet_domain.dart';

/// Use case for sending transactions.
class SendTransactionUseCase {
  final TransactionRepository _transactionRepository;

  SendTransactionUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  /// Send a transaction.
  ///
  /// Throws:
  /// - [ArgumentError] if accountId is empty
  /// - [InvalidAmountException] if amount is zero
  /// - [InvalidPasswordException] if password is empty
  Future<TransactionId> call({
    required String accountId,
    required Address destination,
    required Amount amount,
    required String password,
    Amount? priorityFee,
    String? note,
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

    // Validate password (trim to reject whitespace-only passwords)
    if (password.trim().isEmpty) {
      throw InvalidPasswordException(
        code: 'EMPTY_PASSWORD',
        message: 'Password cannot be empty',
      );
    }

    return _transactionRepository.sendTransaction(
      request: SendRequest(
        accountId: accountId,
        destination: destination,
        amount: amount,
        priorityFee: priorityFee,
        note: note,
      ),
      password: password,
    );
  }
}
