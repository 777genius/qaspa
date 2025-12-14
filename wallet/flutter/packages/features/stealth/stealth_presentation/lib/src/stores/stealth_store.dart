import 'dart:developer' as developer;

import 'package:mobx/mobx.dart';
import 'package:stealth_domain/stealth_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'stealth_store.g.dart';

/// MobX store for stealth feature state management.
class StealthStore = _StealthStoreBase with _$StealthStore;

abstract class _StealthStoreBase with Store {
  final GetStealthAddressUseCase _getStealthAddressUseCase;
  final ScanStealthPaymentsUseCase _scanStealthPaymentsUseCase;
  final SendStealthPaymentUseCase _sendStealthPaymentUseCase;
  final GetStealthBalanceUseCase _getStealthBalanceUseCase;
  final GetStealthTransactionsUseCase _getStealthTransactionsUseCase;

  _StealthStoreBase({
    required GetStealthAddressUseCase getStealthAddressUseCase,
    required ScanStealthPaymentsUseCase scanStealthPaymentsUseCase,
    required SendStealthPaymentUseCase sendStealthPaymentUseCase,
    required GetStealthBalanceUseCase getStealthBalanceUseCase,
    required GetStealthTransactionsUseCase getStealthTransactionsUseCase,
  })  : _getStealthAddressUseCase = getStealthAddressUseCase,
        _scanStealthPaymentsUseCase = scanStealthPaymentsUseCase,
        _sendStealthPaymentUseCase = sendStealthPaymentUseCase,
        _getStealthBalanceUseCase = getStealthBalanceUseCase,
        _getStealthTransactionsUseCase = getStealthTransactionsUseCase;

  @observable
  Address? stealthAddress;

  @observable
  Balance? stealthBalance;

  @observable
  ObservableList<Transaction> stealthTransactions = ObservableList<Transaction>();

  @observable
  bool isLoading = false;

  @observable
  bool isScanning = false;

  @observable
  bool isSending = false;

  @observable
  String? errorMessage;

  @observable
  String? currentAccountId;

  @observable
  int scanProgress = 0;

  @observable
  int scanTotal = 0;

  @observable
  String recipientStealthAddress = '';

  @observable
  String sendAmount = '';

  @computed
  double get stealthBalanceInKas =>
      stealthBalance?.availableKas ?? 0.0;

  @computed
  bool get canSend {
    if (recipientStealthAddress.isEmpty || sendAmount.isEmpty) return false;
    final amount = double.tryParse(sendAmount);
    return amount != null && amount > 0 && !isSending;
  }

  @computed
  BigInt get sendAmountInSompi {
    // Use Amount.fromKas for proper decimal parsing without precision loss
    // double can't represent values > 9M KAS accurately
    try {
      return Amount.fromKas(sendAmount).sompiValue;
    } catch (e) {
      developer.log(
        'Failed to parse amount: $sendAmount',
        error: e,
        name: 'StealthStore',
      );
      return BigInt.zero;
    }
  }

  @action
  void setAccountId(String accountId) {
    currentAccountId = accountId;
    loadStealthData();
  }

  @action
  Future<void> loadStealthData() async {
    final accountId = currentAccountId;
    if (accountId == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      // Load address and balance independently to avoid losing data on partial failure
      final addressFuture = _getStealthAddressUseCase(accountId: accountId)
          .then<Address?>((a) => a)
          .catchError((Object e) {
        developer.log(
          'Failed to load stealth address',
          error: e,
          name: 'StealthStore',
        );
        errorMessage = 'Address: ${e.toString()}';
        return null;
      });

      final balanceFuture = _getStealthBalanceUseCase(accountId: accountId)
          .then<Balance?>((b) => b)
          .catchError((Object e) {
        developer.log(
          'Failed to load stealth balance',
          error: e,
          name: 'StealthStore',
        );
        if (errorMessage == null) {
          errorMessage = 'Balance: ${e.toString()}';
        }
        return null;
      });

      final results = await Future.wait([addressFuture, balanceFuture]);

      // Check if accountId changed during await (race condition prevention)
      if (currentAccountId != accountId) {
        developer.log(
          'Account changed during loadStealthData, discarding results',
          name: 'StealthStore',
        );
        return;
      }

      final addressResult = results[0] as Address?;
      final balanceResult = results[1] as Balance?;

      if (addressResult != null) {
        stealthAddress = addressResult;
      }
      if (balanceResult != null) {
        stealthBalance = balanceResult;
      }

      // Load transactions
      await _loadTransactionsForAccount(accountId);
    } catch (e) {
      developer.log(
        'Unexpected error in loadStealthData',
        error: e,
        name: 'StealthStore',
      );
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> scanForPayments() async {
    final accountId = currentAccountId;
    if (accountId == null || isScanning) return;

    isScanning = true;
    scanProgress = 0;
    scanTotal = 0;
    errorMessage = null;

    try {
      await _scanStealthPaymentsUseCase(accountId: accountId);

      // Check if accountId changed during scan
      if (currentAccountId != accountId) {
        developer.log(
          'Account changed during scan, discarding results',
          name: 'StealthStore',
        );
        return;
      }

      // Reload balance and transactions after scan
      stealthBalance = await _getStealthBalanceUseCase(accountId: accountId);

      // Load transactions after successful scan
      await _loadTransactionsForAccount(accountId);
    } catch (e) {
      developer.log(
        'Failed to scan for payments',
        error: e,
        name: 'StealthStore',
      );
      errorMessage = e.toString();
    } finally {
      isScanning = false;
    }
  }

  Future<void> _loadTransactionsForAccount(String accountId) async {
    try {
      final transactions = await _getStealthTransactionsUseCase(
        accountId: accountId,
        limit: 20,
      );

      // Check if accountId is still current before updating state
      if (currentAccountId != accountId) return;

      stealthTransactions = ObservableList.of(transactions);
    } catch (e) {
      developer.log(
        'Failed to load stealth transactions',
        error: e,
        name: 'StealthStore',
      );
      // Don't overwrite existing error message if one exists
      if (errorMessage == null) {
        errorMessage = 'Failed to load transactions: ${e.toString()}';
      }
    }
  }

  @action
  void setRecipientStealthAddress(String value) {
    recipientStealthAddress = value;
    errorMessage = null;
  }

  @action
  void setSendAmount(String value) {
    sendAmount = value;
    errorMessage = null;
  }

  @action
  Future<TransactionId?> sendStealthPayment({required String password}) async {
    final accountId = currentAccountId;
    if (!canSend || accountId == null) return null;

    isSending = true;
    errorMessage = null;

    try {
      final transactionId = await _sendStealthPaymentUseCase(
        accountId: accountId,
        destination: Address.fromString(recipientStealthAddress),
        amount: Amount.fromSompi(sendAmountInSompi),
        password: password,
      );

      recipientStealthAddress = '';
      sendAmount = '';

      // Only update balance if still on same account
      if (currentAccountId == accountId) {
        stealthBalance = await _getStealthBalanceUseCase(accountId: accountId);
      }

      return transactionId;
    } catch (e) {
      developer.log(
        'Failed to send stealth payment',
        error: e,
        name: 'StealthStore',
      );
      errorMessage = e.toString();
      return null;
    } finally {
      isSending = false;
    }
  }

  @action
  void reset() {
    stealthAddress = null;
    stealthBalance = null;
    stealthTransactions.clear();
    isLoading = false;
    isScanning = false;
    isSending = false;
    errorMessage = null;
    scanProgress = 0;
    scanTotal = 0;
    recipientStealthAddress = '';
    sendAmount = '';
  }

  void dispose() {
    reset();
  }
}
