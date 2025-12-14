import 'dart:async';
import 'dart:developer' as developer;

import 'package:mobx/mobx.dart';
import 'package:send_domain/send_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'send_store.g.dart';

/// MobX store for send feature state management.
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
        'Failed to parse amount: $amount',
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

  void _scheduleEstimateFee() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!_isDisposed) {
        _estimateFee();
      }
    });
  }

  @action
  void setAccountId(String accountId) {
    currentAccountId = accountId;
  }

  Future<void> _estimateFee() async {
    final accountId = currentAccountId;
    if (!isAddressValid || !isAmountValid || accountId == null) {
      estimatedFee = null;
      return;
    }

    isLoading = true;
    try {
      estimatedFee = await _estimateTransactionUseCase(
        accountId: accountId,
        destination: Address.fromString(recipientAddress),
        amount: Amount.fromSompi(amountInSompi),
      );
    } catch (e) {
      estimatedFee = null;
      developer.log(
        'Failed to estimate fee',
        error: e,
        name: 'SendStore',
      );
    } finally {
      isLoading = false;
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
      errorMessage = _getGenericErrorMessage(e);
    } finally {
      isSending = false;
    }
  }

  String _getGenericErrorMessage(Object error) {
    // Map known exceptions to user-friendly messages
    if (error is InsufficientFundsException) {
      return 'Insufficient funds for this transaction';
    } else if (error is InvalidPasswordException) {
      return 'Invalid password';
    } else if (error is InvalidAddressException) {
      return 'Invalid recipient address';
    } else if (error is InvalidAmountException) {
      return 'Invalid amount';
    } else if (error is NotConnectedException || error is RpcException) {
      return 'Network error. Please check your connection';
    }
    // Generic fallback - never expose raw error details
    return 'Transaction failed. Please try again';
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
