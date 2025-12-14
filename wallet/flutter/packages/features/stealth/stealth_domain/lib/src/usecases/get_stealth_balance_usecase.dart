import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get stealth (private) balance.
///
/// For stealth accounts, returns the account balance.
@injectable
class GetStealthBalanceUseCase {
  final AccountRepository _accountRepository;

  GetStealthBalanceUseCase({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  Future<Balance> call({required String accountId}) async {
    return _accountRepository.getBalance(accountId: accountId);
  }
}
