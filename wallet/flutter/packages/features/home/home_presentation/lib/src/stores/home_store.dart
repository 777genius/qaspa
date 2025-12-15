import 'dart:async';
import 'dart:developer' as developer;

import 'package:home_domain/home_domain.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'home_store.g.dart';

/// MobX store for home feature state management.
@lazySingleton
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
  bool _isDisposed = false;

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
    // Snapshot accountId to prevent race condition if loadHomeData called again
    final accountIdSnapshot = accountId;
    currentAccountId = accountId;
    isLoading = true;
    errorMessage = null;

    try {
      // Load balance and transactions independently to avoid losing data on partial failure
      final balanceFuture = _getBalanceUseCase(accountId: accountIdSnapshot)
          .then<Balance?>((b) => b)
          .catchError((Object e) {
        developer.log(
          'Failed to load balance for account: $accountIdSnapshot',
          error: e,
          name: 'HomeStore',
        );
        // Only set error if accountId hasn't changed (race condition prevention)
        if (currentAccountId == accountIdSnapshot) {
          errorMessage = 'Failed to load balance';
        }
        return null;
      });

      final transactionsFuture = _getRecentTransactionsUseCase(
        accountId: accountIdSnapshot,
        limit: 10,
      ).then<List<Transaction>?>((t) => t).catchError((Object e) {
        developer.log(
          'Failed to load transactions for account: $accountIdSnapshot',
          error: e,
          name: 'HomeStore',
        );
        // Only set error if accountId hasn't changed (race condition prevention)
        if (currentAccountId == accountIdSnapshot && errorMessage == null) {
          errorMessage = 'Failed to load transactions';
        }
        return null;
      });

      final results = await Future.wait([balanceFuture, transactionsFuture]);

      // Check if accountId changed during await (race condition prevention)
      if (currentAccountId != accountIdSnapshot) {
        developer.log(
          'Account changed during load, discarding results',
          name: 'HomeStore',
        );
        return;
      }

      final balanceResult = results[0];
      final transactionsResult = results[1];

      if (balanceResult is Balance) {
        balance = balanceResult;
      }
      if (transactionsResult is List<Transaction>) {
        recentTransactions = ObservableList.of(transactionsResult);
      }

      _startWatchingBalance(accountIdSnapshot);
    } catch (e) {
      developer.log(
        'Unexpected error in loadHomeData',
        error: e,
        name: 'HomeStore',
      );
      errorMessage = 'Failed to load data. Please try again';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refreshBalance() async {
    final accountId = currentAccountId;
    if (accountId == null) return;

    try {
      balance = await _getBalanceUseCase(accountId: accountId);
    } catch (e) {
      developer.log(
        'Failed to refresh balance',
        error: e,
        name: 'HomeStore',
      );
      errorMessage = 'Failed to refresh balance';
    }
  }

  @action
  Future<void> refreshTransactions() async {
    final accountId = currentAccountId;
    if (accountId == null) return;

    try {
      final transactions = await _getRecentTransactionsUseCase(
        accountId: accountId,
        limit: 10,
      );
      recentTransactions = ObservableList.of(transactions);
    } catch (e) {
      developer.log(
        'Failed to refresh transactions',
        error: e,
        name: 'HomeStore',
      );
      errorMessage = 'Failed to refresh transactions';
    }
  }

  @action
  void _startWatchingBalance(String accountId) {
    _balanceSubscription?.cancel();
    _balanceSubscription = _watchBalanceUseCase(accountId: accountId).listen(
      (newBalance) {
        if (_isDisposed || currentAccountId != accountId) return;
        runInAction(() {
          balance = newBalance;
        });
      },
      onError: (e) {
        if (_isDisposed || currentAccountId != accountId) return;
        developer.log(
          'Balance watch error',
          error: e,
          name: 'HomeStore',
        );
        runInAction(() {
          errorMessage = 'Connection error';
        });
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
    _isDisposed = true;
    _balanceSubscription?.cancel();
  }
}
