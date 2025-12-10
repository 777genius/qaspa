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
    final parsed = double.tryParse(amount) ?? 0;
    return BigInt.from(parsed * 100000000); // 1 KAS = 100000000 sompi
  }

  @action
  void setRecipientAddress(String value) {
    recipientAddress = value;
    errorMessage = null;
    _estimateFee();
  }

  @action
  void setAmount(String value) {
    amount = value;
    errorMessage = null;
    _estimateFee();
  }

  @action
  void setAccountId(String accountId) {
    currentAccountId = accountId;
  }

  Future<void> _estimateFee() async {
    if (!isAddressValid || !isAmountValid || currentAccountId == null) {
      estimatedFee = null;
      return;
    }

    isLoading = true;
    try {
      estimatedFee = await _estimateTransactionUseCase(
        accountId: currentAccountId!,
        destination: Address.fromString(recipientAddress),
        amount: Amount.fromSompi(amountInSompi),
      );
    } catch (e) {
      estimatedFee = null;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> sendTransaction({required String password}) async {
    if (!canSend || currentAccountId == null) return;

    isSending = true;
    errorMessage = null;

    try {
      sentTransactionId = await _sendTransactionUseCase(
        accountId: currentAccountId!,
        destination: Address.fromString(recipientAddress),
        amount: Amount.fromSompi(amountInSompi),
        password: password,
      );

      // Clear form on success
      recipientAddress = '';
      amount = '';
      estimatedFee = null;
    } catch (e) {
      errorMessage = e.toString();
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
    reset();
  }
}
