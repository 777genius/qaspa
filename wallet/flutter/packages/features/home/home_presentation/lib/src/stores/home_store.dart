import 'dart:async';

import 'package:home_domain/home_domain.dart';
import 'package:mobx/mobx.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'home_store.g.dart';

/// MobX store for home feature state management.
class HomeStore = _HomeStoreBase with _$HomeStore;

abstract class _HomeStoreBase with Store {
  final GetBalanceUseCase _getBalanceUseCase;
  final GetRecentTransactionsUseCase _getRecentTransactionsUseCase;
  final WatchBalanceUseCase _watchBalanceUseCase;

  _HomeStoreBase({
    required GetBalanceUseCase getBalanceUseCase,
    required GetRecentTransactionsUseCase getRecentTransactionsUseCase,
    required WatchBalanceUseCase watchBalanceUseCase,
  })  : _getBalanceUseCase = getBalanceUseCase,
        _getRecentTransactionsUseCase = getRecentTransactionsUseCase,
        _watchBalanceUseCase = watchBalanceUseCase;

  StreamSubscription<Balance>? _balanceSubscription;

  @observable
  Balance? balance;

  @observable
  ObservableList<Transaction> recentTransactions = ObservableList<Transaction>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? currentAccountId;

  @computed
  bool get hasBalance => balance != null;

  @computed
  bool get hasTransactions => recentTransactions.isNotEmpty;

  @action
  Future<void> loadHomeData({required String accountId}) async {
    currentAccountId = accountId;
    isLoading = true;
    errorMessage = null;

    try {
      // Load balance and transactions independently to avoid losing data on partial failure
      final balanceFuture = _getBalanceUseCase(accountId: accountId)
          .then<Balance?>((b) => b)
          .catchError((e) {
        errorMessage = 'Balance: ${e.toString()}';
        return null;
      });

      final transactionsFuture = _getRecentTransactionsUseCase(
        accountId: accountId,
        limit: 10,
      ).then<List<Transaction>?>((t) => t).catchError((e) {
        if (errorMessage == null) {
          errorMessage = 'Transactions: ${e.toString()}';
        }
        return null;
      });

      final results = await Future.wait([balanceFuture, transactionsFuture]);

      final balanceResult = results[0] as Balance?;
      final transactionsResult = results[1] as List<Transaction>?;

      if (balanceResult != null) {
        balance = balanceResult;
      }
      if (transactionsResult != null) {
        recentTransactions = ObservableList.of(transactionsResult);
      }

      _startWatchingBalance(accountId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refreshBalance() async {
    if (currentAccountId == null) return;

    try {
      balance = await _getBalanceUseCase(accountId: currentAccountId!);
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  @action
  Future<void> refreshTransactions() async {
    if (currentAccountId == null) return;

    try {
      final transactions = await _getRecentTransactionsUseCase(
        accountId: currentAccountId!,
        limit: 10,
      );
      recentTransactions = ObservableList.of(transactions);
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  void _startWatchingBalance(String accountId) {
    _balanceSubscription?.cancel();
    _balanceSubscription = _watchBalanceUseCase(accountId: accountId).listen(
      (newBalance) {
        balance = newBalance;
      },
      onError: (e) {
        errorMessage = e.toString();
      },
    );
  }

  @action
  void reset() {
    _balanceSubscription?.cancel();
    _balanceSubscription = null;
    balance = null;
    recentTransactions.clear();
    isLoading = false;
    errorMessage = null;
    currentAccountId = null;
  }

  void dispose() {
    _balanceSubscription?.cancel();
  }
}
