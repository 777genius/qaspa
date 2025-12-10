// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SettingsStore on _SettingsStoreBase, Store {
  late final _$walletAtom = Atom(
    name: '_SettingsStoreBase.wallet',
    context: context,
  );

  @override
  Wallet? get wallet {
    _$walletAtom.reportRead();
    return super.wallet;
  }

  @override
  set wallet(Wallet? value) {
    _$walletAtom.reportWrite(value, super.wallet, () {
      super.wallet = value;
    });
  }

  late final _$exportedMnemonicAtom = Atom(
    name: '_SettingsStoreBase.exportedMnemonic',
    context: context,
  );

  @override
  String? get exportedMnemonic {
    _$exportedMnemonicAtom.reportRead();
    return super.exportedMnemonic;
  }

  @override
  set exportedMnemonic(String? value) {
    _$exportedMnemonicAtom.reportWrite(value, super.exportedMnemonic, () {
      super.exportedMnemonic = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_SettingsStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isProcessingAtom = Atom(
    name: '_SettingsStoreBase.isProcessing',
    context: context,
  );

  @override
  bool get isProcessing {
    _$isProcessingAtom.reportRead();
    return super.isProcessing;
  }

  @override
  set isProcessing(bool value) {
    _$isProcessingAtom.reportWrite(value, super.isProcessing, () {
      super.isProcessing = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_SettingsStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$successMessageAtom = Atom(
    name: '_SettingsStoreBase.successMessage',
    context: context,
  );

  @override
  String? get successMessage {
    _$successMessageAtom.reportRead();
    return super.successMessage;
  }

  @override
  set successMessage(String? value) {
    _$successMessageAtom.reportWrite(value, super.successMessage, () {
      super.successMessage = value;
    });
  }

  late final _$currentWalletIdAtom = Atom(
    name: '_SettingsStoreBase.currentWalletId',
    context: context,
  );

  @override
  String? get currentWalletId {
    _$currentWalletIdAtom.reportRead();
    return super.currentWalletId;
  }

  @override
  set currentWalletId(String? value) {
    _$currentWalletIdAtom.reportWrite(value, super.currentWalletId, () {
      super.currentWalletId = value;
    });
  }

  late final _$loadWalletInfoAsyncAction = AsyncAction(
    '_SettingsStoreBase.loadWalletInfo',
    context: context,
  );

  @override
  Future<void> loadWalletInfo() {
    return _$loadWalletInfoAsyncAction.run(() => super.loadWalletInfo());
  }

  late final _$exportMnemonicAsyncAction = AsyncAction(
    '_SettingsStoreBase.exportMnemonic',
    context: context,
  );

  @override
  Future<void> exportMnemonic({required String password}) {
    return _$exportMnemonicAsyncAction.run(
      () => super.exportMnemonic(password: password),
    );
  }

  late final _$changePasswordAsyncAction = AsyncAction(
    '_SettingsStoreBase.changePassword',
    context: context,
  );

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _$changePasswordAsyncAction.run(
      () => super.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  late final _$deleteWalletAsyncAction = AsyncAction(
    '_SettingsStoreBase.deleteWallet',
    context: context,
  );

  @override
  Future<bool> deleteWallet({required String password}) {
    return _$deleteWalletAsyncAction.run(
      () => super.deleteWallet(password: password),
    );
  }

  late final _$_SettingsStoreBaseActionController = ActionController(
    name: '_SettingsStoreBase',
    context: context,
  );

  @override
  void setWalletId(String walletId) {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.setWalletId',
    );
    try {
      return super.setWalletId(walletId);
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearExportedMnemonic() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.clearExportedMnemonic',
    );
    try {
      return super.clearExportedMnemonic();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearMessages() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.clearMessages',
    );
    try {
      return super.clearMessages();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$_SettingsStoreBaseActionController.startAction(
      name: '_SettingsStoreBase.reset',
    );
    try {
      return super.reset();
    } finally {
      _$_SettingsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
wallet: ${wallet},
exportedMnemonic: ${exportedMnemonic},
isLoading: ${isLoading},
isProcessing: ${isProcessing},
errorMessage: ${errorMessage},
successMessage: ${successMessage},
currentWalletId: ${currentWalletId}
    ''';
  }
}
