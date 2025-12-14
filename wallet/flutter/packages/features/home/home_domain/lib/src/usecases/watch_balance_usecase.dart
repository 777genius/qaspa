import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case for watching balance changes.
@injectable
class WatchBalanceUseCase {
  final AccountRepository _accountRepository;

  WatchBalanceUseCase({required AccountRepository accountRepository})
      : _accountRepository = accountRepository;

  /// Watch balance changes for account.
  Stream<Balance> call({required String accountId}) {
    return _accountRepository.watchBalance(accountId: accountId);
  }
}
