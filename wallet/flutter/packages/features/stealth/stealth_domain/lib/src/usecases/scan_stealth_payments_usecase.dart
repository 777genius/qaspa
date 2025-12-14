import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case to scan blockchain for incoming stealth payments.
@injectable
class ScanStealthPaymentsUseCase {
  final AccountRepository _accountRepository;

  ScanStealthPaymentsUseCase({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  Future<void> call({required String accountId}) async {
    return _accountRepository.scanStealthPayments(accountId: accountId);
  }
}
