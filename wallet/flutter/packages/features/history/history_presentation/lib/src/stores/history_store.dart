import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:history_domain/history_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'history_store.g.dart';

/// MobX store for history feature state management.
class HistoryStore = _HistoryStoreBase with _$HistoryStore;

abstract class _HistoryStoreBase with Store {
  final GetTransactionHistoryUseCase _getTransactionHistoryUseCase;
  final WatchTransactionHistoryUseCase _watchTransactionHistoryUseCase;
  final GetTransactionDetailsUseCase _getTransactionDetailsUseCase;

  StreamSubscription<List<Transaction>>? _transactionSubscription;
  bool _isDisposed = false;

  _HistoryStoreBase({
    required GetTransactionHistoryUseCase getTransactionHistoryUseCase,
    required WatchTransactionHistoryUseCase watchTransactionHistoryUseCase,
    required GetTransactionDetailsUseCase getTransactionDetailsUseCase,
  })  : _getTransactionHistoryUseCase = getTransactionHistoryUseCase,
        _watchTransactionHistoryUseCase = watchTransactionHistoryUseCase,
        _getTransactionDetailsUseCase = getTransactionDetailsUseCase;

  @observable
  ObservableList<Transaction> transactions = ObservableList<Transaction>();

  @observable
  Transaction? selectedTransaction;

  @observable
  bool isLoading = false;

  @observable
  bool isLoadingMore = false;

  @observable
  String? errorMessage;

  @observable
  String? currentAccountId;

  @observable
  bool hasMoreData = true;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  @action
  void setAccountId(String accountId) {
    if (currentAccountId == accountId) return;
    currentAccountId = accountId;
    _currentOffset = 0;
    hasMoreData = true;
    transactions.clear();
    _subscribeToTransactions();
    loadTransactions();
  }

  void _subscribeToTransactions() {
    _transactionSubscription?.cancel();
    final accountId = currentAccountId;
    if (accountId == null) return;

    _transactionSubscription = _watchTransactionHistoryUseCase(
      accountId: accountId,
    ).listen(
      (newTransactions) {
        if (_isDisposed) return;
        transactions
          ..clear()
          ..addAll(newTransactions);
      },
      onError: (error) {
        if (_isDisposed) return;
        errorMessage = error.toString();
      },
    );
  }

  @action
  Future<void> loadTransactions() async {
    final accountId = currentAccountId;
    if (accountId == null) return;

    isLoading = true;
    errorMessage = null;
    _currentOffset = 0;

    try {
      final result = await _getTransactionHistoryUseCase(
        accountId: accountId,
        limit: _pageSize,
        offset: 0,
      );
      transactions
        ..clear()
        ..addAll(result);
      hasMoreData = result.length >= _pageSize;
      _currentOffset = result.length;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> loadMore() async {
    final accountId = currentAccountId;
    if (accountId == null || isLoadingMore || !hasMoreData) return;

    isLoadingMore = true;

    try {
      final result = await _getTransactionHistoryUseCase(
        accountId: accountId,
        limit: _pageSize,
        offset: _currentOffset,
      );
      transactions.addAll(result);
      hasMoreData = result.length >= _pageSize;
      _currentOffset += result.length;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoadingMore = false;
    }
  }

  @action
  Future<void> selectTransaction(TransactionId transactionId) async {
    try {
      selectedTransaction = await _getTransactionDetailsUseCase(
        transactionId: transactionId,
      );
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  @action
  void clearSelectedTransaction() {
    selectedTransaction = null;
  }

  @action
  void reset() {
    _transactionSubscription?.cancel();
    _transactionSubscription = null;
    transactions.clear();
    selectedTransaction = null;
    isLoading = false;
    isLoadingMore = false;
    errorMessage = null;
    hasMoreData = true;
    _currentOffset = 0;
  }

  void dispose() {
    _isDisposed = true;
    _transactionSubscription?.cancel();
    _transactionSubscription = null;
  }
}
