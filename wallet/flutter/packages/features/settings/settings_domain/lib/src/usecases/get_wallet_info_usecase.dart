import 'package:injectable/injectable.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Use case to get wallet information.
@injectable
class GetWalletInfoUseCase {
  final WalletRepository _walletRepository;

  GetWalletInfoUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<Wallet?> call() async {
    return _walletRepository.getCurrentWallet();
  }
}
