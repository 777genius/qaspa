import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case for getting account balance.
@injectable
class GetBalanceUseCase {
  final AccountRepository _accountRepository;

  GetBalanceUseCase({required AccountRepository accountRepository})
      : _accountRepository = accountRepository;

  /// Get balance for specific account.
  Future<Balance> call({required String accountId}) async {
    return _accountRepository.getBalance(accountId: accountId);
  }
}
