import 'package:wallet_domain/wallet_domain.dart';

/// Use case to send a stealth (private) payment.
///
/// Uses standard transaction sending for stealth accounts.
class SendStealthPaymentUseCase {
  final TransactionRepository _transactionRepository;

  SendStealthPaymentUseCase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Future<TransactionId> call({
    required String accountId,
    required Address destination,
    required Amount amount,
    required String password,
  }) async {
    return _transactionRepository.sendTransaction(
      request: SendRequest(
        accountId: accountId,
        destination: destination,
        amount: amount,
      ),
      password: password,
    );
  }
}
