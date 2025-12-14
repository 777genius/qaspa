import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case to generate a new receive address.
@injectable
class GenerateNewAddressUseCase {
  final AccountRepository _accountRepository;

  GenerateNewAddressUseCase({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  Future<Address> call({required String accountId}) async {
    return _accountRepository.generateNewAddress(accountId: accountId);
  }
}
