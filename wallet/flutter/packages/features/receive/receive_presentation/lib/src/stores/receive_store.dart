import 'dart:async';
import 'dart:developer' as developer;

import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:receive_domain/receive_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'receive_store.g.dart';

/// MobX store for receive feature state management.
@lazySingleton
class ReceiveStore = _ReceiveStoreBase with _$ReceiveStore;

abstract class _ReceiveStoreBase with Store {
  final GetReceiveAddressUseCase _getReceiveAddressUseCase;
  final GenerateNewAddressUseCase _generateNewAddressUseCase;

  Timer? _copiedResetTimer;
  bool _isDisposed = false;

  _ReceiveStoreBase({
    required GetReceiveAddressUseCase getReceiveAddressUseCase,
    required GenerateNewAddressUseCase generateNewAddressUseCase,
  })  : _getReceiveAddressUseCase = getReceiveAddressUseCase,
        _generateNewAddressUseCase = generateNewAddressUseCase;

  @observable
  Address? currentAddress;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? currentAccountId;

  @observable
  bool addressCopied = false;

  @action
  void setAccountId(String accountId) {
    currentAccountId = accountId;
    loadAddress();
  }

  @action
  Future<void> loadAddress() async {
    final accountId = currentAccountId;
    final accountIdSnapshot = accountId;
    if (accountId == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final address = await _getReceiveAddressUseCase(
        accountId: accountId,
      );
      // Race condition check: only update if account hasn't changed
      if (currentAccountId != accountIdSnapshot) return;
      currentAddress = address;
    } catch (e) {
      // Race condition check: only show error if account hasn't changed
      if (currentAccountId != accountIdSnapshot) return;
      developer.log(
        'Failed to load address',
        error: e,
        name: 'ReceiveStore',
      );
      errorMessage = 'Failed to load address';
    } finally {
      if (currentAccountId == accountIdSnapshot) {
        isLoading = false;
      }
    }
  }

  @action
  Future<void> generateNewAddress() async {
    final accountId = currentAccountId;
    final accountIdSnapshot = accountId;
    if (accountId == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final address = await _generateNewAddressUseCase(
        accountId: accountId,
      );
      // Race condition check: only update if account hasn't changed
      if (currentAccountId != accountIdSnapshot) return;
      currentAddress = address;
    } catch (e) {
      // Race condition check: only show error if account hasn't changed
      if (currentAccountId != accountIdSnapshot) return;
      developer.log(
        'Failed to generate new address',
        error: e,
        name: 'ReceiveStore',
      );
      errorMessage = 'Failed to generate address';
    } finally {
      if (currentAccountId == accountIdSnapshot) {
        isLoading = false;
      }
    }
  }

  @action
  void setAddressCopied(bool value) {
    // Cancel previous timer
    _copiedResetTimer?.cancel();
    addressCopied = value;

    // Auto-reset after 2 seconds
    if (value && !_isDisposed) {
      _copiedResetTimer = Timer(const Duration(seconds: 2), () {
        if (!_isDisposed) {
          addressCopied = false;
        }
      });
    }
  }

  @action
  void reset() {
    currentAddress = null;
    isLoading = false;
    errorMessage = null;
    addressCopied = false;
  }

  void dispose() {
    _isDisposed = true;
    _copiedResetTimer?.cancel();
    _copiedResetTimer = null;
    reset();
  }
}
