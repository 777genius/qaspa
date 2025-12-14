import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:receive_domain/receive_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'receive_store.g.dart';

/// MobX store for receive feature state management.
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
    if (accountId == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      currentAddress = await _getReceiveAddressUseCase(
        accountId: accountId,
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> generateNewAddress() async {
    final accountId = currentAccountId;
    if (accountId == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      currentAddress = await _generateNewAddressUseCase(
        accountId: accountId,
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
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
