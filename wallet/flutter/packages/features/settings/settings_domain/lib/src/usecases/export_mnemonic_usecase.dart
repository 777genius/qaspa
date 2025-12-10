import 'package:wallet_domain/wallet_domain.dart';

/// Use case to export wallet mnemonic phrase.
class ExportMnemonicUseCase {
  final WalletRepository _walletRepository;

  ExportMnemonicUseCase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<Mnemonic> call({
    required String walletId,
    required String password,
  }) async {
    return _walletRepository.exportMnemonic(
      walletId: walletId,
      password: password,
    );
  }
}
