import 'package:wallet_domain/wallet_domain.dart';

/// Use case to change wallet password.
class ChangePasswordUseCase {
  final WalletRepository _walletRepository;

  ChangePasswordUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> call({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) async {
    return _walletRepository.changePassword(
      walletId: walletId,
      oldPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
