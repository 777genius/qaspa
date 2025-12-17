import 'dart:async';
import 'dart:developer' as developer;

import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:send_domain/send_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'send_store.g.dart';

const _errorMapper = ErrorMessageMapperImpl();

/// MobX store for send feature state management.
@lazySingleton
class SendStore = _SendStoreBase with _$SendStore;

abstract class _SendStoreBase with Store {
  final EstimateTransactionUseCase _estimateTransactionUseCase;
  final SendTransactionUseCase _sendTransactionUseCase;
  final ValidateAddressUseCase _validateAddressUseCase;

  _SendStoreBase({
    required EstimateTransactionUseCase estimateTransactionUseCase,
    required SendTransactionUseCase sendTransactionUseCase,
    required ValidateAddressUseCase validateAddressUseCase,
  })  : _estimateTransactionUseCase = estimateTransactionUseCase,
        _sendTransactionUseCase = sendTransactionUseCase,
        _validateAddressUseCase = validateAddressUseCase;

  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);
  bool _isDisposed = false;

  @observable
  String recipientAddress = '';

  @observable
  String amount = '';

  @observable
  TransactionEstimate? estimatedFee;

  @observable
  bool isLoading = false;

  @observable
  bool isSending = false;

  @observable
  String? errorMessage;

  @observable
  TransactionId? sentTransactionId;

  @observable
  String? currentAccountId;

  @computed
  bool get isAddressValid => _validateAddressUseCase(recipientAddress);

  @computed
  bool get isAmountValid {
    if (amount.isEmpty) return false;
    final parsed = double.tryParse(amount);
    return parsed != null && parsed > 0;
  }

  @computed
  bool get canSend => isAddressValid && isAmountValid && !isSending;

  @computed
  BigInt get amountInSompi {
    if (amount.isEmpty) return BigInt.zero;
    try {
      // Use Amount.fromKas for proper decimal parsing without precision loss
      // double can't represent values > 9M KAS accurately
      return Amount.fromKas(amount).sompiValue;
    } catch (e) {
      developer.log(
        'Failed to parse amount',
        error: e,
        name: 'SendStore',
      );
      return BigInt.zero;
    }
  }

  @action
  void setRecipientAddress(String value) {
    recipientAddress = value;
    errorMessage = null;
    _scheduleEstimateFee();
  }

  @action
  void setAmount(String value) {
    amount = value;
    errorMessage = null;
    _scheduleEstimateFee();
  }

  @action
  void _scheduleEstimateFee() {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!_isDisposed) {
        _estimateFee();
      }
    });
  }

  @action
  void setAccountId(String accountId) {
    if (currentAccountId != accountId) {
      // Clear form when switching accounts to avoid stale data
      recipientAddress = '';
      amount = '';
      estimatedFee = null;
      errorMessage = null;
      sentTransactionId = null;
    }
    currentAccountId = accountId;
  }

  @action
  Future<void> _estimateFee() async {
    final accountId = currentAccountId;
    final accountIdSnapshot = accountId;
    if (!isAddressValid || !isAmountValid || accountId == null) {
      estimatedFee = null;
      return;
    }

    isLoading = true;
    try {
      final result = await _estimateTransactionUseCase(
        accountId: accountId,
        destination: Address.fromString(recipientAddress),
        amount: Amount.fromSompi(amountInSompi),
      );
      // Race condition check
      if (currentAccountId != accountIdSnapshot) return;
      estimatedFee = result;
    } catch (e) {
      if (currentAccountId != accountIdSnapshot) return;
      estimatedFee = null;
      developer.log(
        'Failed to estimate fee',
        error: e,
        name: 'SendStore',
      );
    } finally {
      if (currentAccountId == accountIdSnapshot) {
        isLoading = false;
      }
    }
  }

  @action
  Future<void> sendTransaction({required String password}) async {
    final accountId = currentAccountId;
    if (!canSend || accountId == null) return;

    isSending = true;
    errorMessage = null;

    try {
      sentTransactionId = await _sendTransactionUseCase(
        accountId: accountId,
        destination: Address.fromString(recipientAddress),
        amount: Amount.fromSompi(amountInSompi),
        password: password,
      );

      // Clear form on success
      recipientAddress = '';
      amount = '';
      estimatedFee = null;
    } catch (e) {
      // Use generic message to avoid leaking sensitive data
      developer.log(
        'Send transaction failed',
        error: e,
        name: 'SendStore',
      );
      errorMessage = _errorMapper.mapTransactionError(e);
    } finally {
      isSending = false;
    }
  }

  @action
  void reset() {
    recipientAddress = '';
    amount = '';
    estimatedFee = null;
    isLoading = false;
    isSending = false;
    errorMessage = null;
    sentTransactionId = null;
  }

  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    reset();
  }
}
