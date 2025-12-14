import 'dart:async';
import 'dart:developer' as developer;

import 'package:history_domain/history_domain.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'history_store.g.dart';

/// MobX store for history feature state management.
@lazySingleton
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

  @action
  void _subscribeToTransactions() {
    _transactionSubscription?.cancel();
    final accountId = currentAccountId;
    if (accountId == null) return;

    _transactionSubscription = _watchTransactionHistoryUseCase(
      accountId: accountId,
    ).listen(
      (newTransactions) {
        if (_isDisposed || currentAccountId != accountId) return;
        transactions
          ..clear()
          ..addAll(newTransactions);
      },
      onError: (error) {
        if (_isDisposed || currentAccountId != accountId) return;
        developer.log('Transaction stream error', error: error, name: 'HistoryStore');
        errorMessage = 'Failed to sync transactions';
      },
    );
  }

  @action
  Future<void> loadTransactions() async {
    final accountId = currentAccountId;
    final accountIdSnapshot = accountId;
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
      // Race condition check
      if (currentAccountId != accountIdSnapshot) return;
      transactions
        ..clear()
        ..addAll(result);
      hasMoreData = result.length >= _pageSize;
      _currentOffset = result.length;
    } catch (e) {
      if (currentAccountId != accountIdSnapshot) return;
      developer.log('Failed to load transactions', error: e, name: 'HistoryStore');
      errorMessage = 'Failed to load transactions';
    } finally {
      if (currentAccountId == accountIdSnapshot) {
        isLoading = false;
      }
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
      developer.log('Failed to load more transactions', error: e, name: 'HistoryStore');
      errorMessage = 'Failed to load more transactions';
    } finally {
      isLoadingMore = false;
    }
  }

  @action
  Future<void> selectTransaction(TransactionId transactionId) async {
    errorMessage = null;
    try {
      selectedTransaction = await _getTransactionDetailsUseCase(
        transactionId: transactionId,
      );
    } catch (e) {
      developer.log('Failed to load transaction details', error: e, name: 'HistoryStore');
      errorMessage = 'Failed to load transaction details';
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
