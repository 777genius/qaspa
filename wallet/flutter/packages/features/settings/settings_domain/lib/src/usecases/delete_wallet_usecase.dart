import 'package:wallet_domain/wallet_domain.dart';

/// Use case to delete wallet.
class DeleteWalletUseCase {
  final WalletRepository _walletRepository;

  DeleteWalletUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> call({
    required String walletId,
    required String password,
  }) async {
    return _walletRepository.deleteWallet(
      walletId: walletId,
      password: password,
    );
  }
}
