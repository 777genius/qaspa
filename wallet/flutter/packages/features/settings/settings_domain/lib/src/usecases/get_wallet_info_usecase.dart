import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get wallet information.
class GetWalletInfoUseCase {
  final WalletRepository _walletRepository;

  GetWalletInfoUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<Wallet?> call() async {
    return _walletRepository.getCurrentWallet();
  }
}
