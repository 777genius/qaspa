import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get stealth address for receiving private payments.
///
/// For stealth accounts, the receive address IS the stealth address.
class GetStealthAddressUseCase {
  final AccountRepository _accountRepository;

  GetStealthAddressUseCase({
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository;

  Future<Address> call({required String accountId}) async {
    return _accountRepository.getReceiveAddress(accountId: accountId);
  }
}
