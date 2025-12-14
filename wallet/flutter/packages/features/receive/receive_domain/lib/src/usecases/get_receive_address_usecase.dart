import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get current receive address for an account.
@injectable
class GetReceiveAddressUseCase {
  final AccountRepository _accountRepository;

  GetReceiveAddressUseCase({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  Future<Address> call({required String accountId}) async {
    return _accountRepository.getReceiveAddress(accountId: accountId);
  }
}
