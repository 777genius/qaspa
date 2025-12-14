import 'dart:async';
import 'dart:developer' as developer;

import 'package:mobx/mobx.dart';
import 'package:settings_domain/settings_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'settings_store.g.dart';

/// MobX store for settings feature state management.
class SettingsStore = _SettingsStoreBase with _$SettingsStore;

abstract class _SettingsStoreBase with Store {
  final GetWalletInfoUseCase _getWalletInfoUseCase;
  final ExportMnemonicUseCase _exportMnemonicUseCase;
  final ChangePasswordUseCase _changePasswordUseCase;
  final DeleteWalletUseCase _deleteWalletUseCase;

  /// Auto-clear mnemonic after this duration for security.
  /// 10 seconds is sufficient to copy and verify, minimizing exposure time.
  static const _mnemonicClearTimeout = Duration(seconds: 10);

  Timer? _mnemonicClearTimer;

  _SettingsStoreBase({
    required GetWalletInfoUseCase getWalletInfoUseCase,
    required ExportMnemonicUseCase exportMnemonicUseCase,
    required ChangePasswordUseCase changePasswordUseCase,
    required DeleteWalletUseCase deleteWalletUseCase,
  })  : _getWalletInfoUseCase = getWalletInfoUseCase,
        _exportMnemonicUseCase = exportMnemonicUseCase,
        _changePasswordUseCase = changePasswordUseCase,
        _deleteWalletUseCase = deleteWalletUseCase;

  @observable
  Wallet? wallet;

  @observable
  String? exportedMnemonic;

  @observable
  bool isLoading = false;

  @observable
  bool isProcessing = false;

  @observable
  String? errorMessage;

  @observable
  String? successMessage;

  @observable
  String? currentWalletId;

  @action
  void setWalletId(String walletId) {
    currentWalletId = walletId;
    loadWalletInfo();
  }

  @action
  Future<void> loadWalletInfo() async {
    isLoading = true;
    errorMessage = null;

    try {
      wallet = await _getWalletInfoUseCase();
      currentWalletId = wallet?.id;
    } catch (e) {
      developer.log('Failed to load wallet info', error: e, name: 'SettingsStore');
      errorMessage = 'Failed to load wallet info';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> exportMnemonic({required String password}) async {
    if (currentWalletId == null) return;

    isProcessing = true;
    errorMessage = null;
    exportedMnemonic = null;
    _cancelMnemonicClearTimer();

    try {
      final mnemonic = await _exportMnemonicUseCase(
        walletId: currentWalletId!,
        password: password,
      );
      exportedMnemonic = mnemonic.toPhrase();
      _startMnemonicClearTimer();
    } catch (e) {
      developer.log('Export mnemonic failed', error: e, name: 'SettingsStore');
      errorMessage = _getPasswordErrorMessage(e);
    } finally {
      isProcessing = false;
    }
  }

  void _startMnemonicClearTimer() {
    _mnemonicClearTimer = Timer(_mnemonicClearTimeout, clearExportedMnemonic);
  }

  void _cancelMnemonicClearTimer() {
    _mnemonicClearTimer?.cancel();
    _mnemonicClearTimer = null;
  }

  @action
  void clearExportedMnemonic() {
    _cancelMnemonicClearTimer();
    exportedMnemonic = null;
  }

  /// Call when app goes to background for security.
  @action
  void onAppPaused() {
    clearExportedMnemonic();
  }

  @action
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentWalletId == null) return false;

    isProcessing = true;
    errorMessage = null;
    successMessage = null;

    try {
      await _changePasswordUseCase(
        walletId: currentWalletId!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      successMessage = 'Password changed successfully';
      return true;
    } catch (e) {
      developer.log('Change password failed', error: e, name: 'SettingsStore');
      errorMessage = _getPasswordErrorMessage(e);
      return false;
    } finally {
      isProcessing = false;
    }
  }

  @action
  Future<bool> deleteWallet({required String password}) async {
    if (currentWalletId == null) return false;

    isProcessing = true;
    errorMessage = null;

    try {
      await _deleteWalletUseCase(
        walletId: currentWalletId!,
        password: password,
      );
      return true;
    } catch (e) {
      developer.log('Delete wallet failed', error: e, name: 'SettingsStore');
      errorMessage = _getPasswordErrorMessage(e);
      return false;
    } finally {
      isProcessing = false;
    }
  }

  String _getPasswordErrorMessage(Object error) {
    if (error is InvalidPasswordException) {
      return 'Invalid password';
    } else if (error is WalletNotFoundException) {
      return 'Wallet not found';
    }
    return 'Operation failed. Please try again';
  }

  @action
  void clearMessages() {
    errorMessage = null;
    successMessage = null;
  }

  @action
  void reset() {
    _cancelMnemonicClearTimer();
    wallet = null;
    exportedMnemonic = null;
    isLoading = false;
    isProcessing = false;
    errorMessage = null;
    successMessage = null;
  }

  void dispose() {
    _cancelMnemonicClearTimer();
    exportedMnemonic = null;
  }
}
