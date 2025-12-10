// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HistoryStore on _HistoryStoreBase, Store {
  late final _$transactionsAtom = Atom(
    name: '_HistoryStoreBase.transactions',
    context: context,
  );

  @override
  ObservableList<Transaction> get transactions {
    _$transactionsAtom.reportRead();
    return super.transactions;
  }

  @override
  set transactions(ObservableList<Transaction> value) {
    _$transactionsAtom.reportWrite(value, super.transactions, () {
      super.transactions = value;
    });
  }

  late final _$selectedTransactionAtom = Atom(
    name: '_HistoryStoreBase.selectedTransaction',
    context: context,
  );

  @override
  Transaction? get selectedTransaction {
    _$selectedTransactionAtom.reportRead();
    return super.selectedTransaction;
  }

  @override
  set selectedTransaction(Transaction? value) {
    _$selectedTransactionAtom.reportWrite(value, super.selectedTransaction, () {
      super.selectedTransaction = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_HistoryStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isLoadingMoreAtom = Atom(
    name: '_HistoryStoreBase.isLoadingMore',
    context: context,
  );

  @override
  bool get isLoadingMore {
    _$isLoadingMoreAtom.reportRead();
    return super.isLoadingMore;
  }

  @override
  set isLoadingMore(bool value) {
    _$isLoadingMoreAtom.reportWrite(value, super.isLoadingMore, () {
      super.isLoadingMore = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_HistoryStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$currentAccountIdAtom = Atom(
    name: '_HistoryStoreBase.currentAccountId',
    context: context,
  );

  @override
  String? get currentAccountId {
    _$currentAccountIdAtom.reportRead();
    return super.currentAccountId;
  }

  @override
  set currentAccountId(String? value) {
    _$currentAccountIdAtom.reportWrite(value, super.currentAccountId, () {
      super.currentAccountId = value;
    });
  }

  late final _$hasMoreDataAtom = Atom(
    name: '_HistoryStoreBase.hasMoreData',
    context: context,
  );

  @override
  bool get hasMoreData {
    _$hasMoreDataAtom.reportRead();
    return super.hasMoreData;
  }

  @override
  set hasMoreData(bool value) {
    _$hasMoreDataAtom.reportWrite(value, super.hasMoreData, () {
      super.hasMoreData = value;
    });
  }

  late final _$loadTransactionsAsyncAction = AsyncAction(
    '_HistoryStoreBase.loadTransactions',
    context: context,
  );

  @override
  Future<void> loadTransactions() {
    return _$loadTransactionsAsyncAction.run(() => super.loadTransactions());
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    '_HistoryStoreBase.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  late final _$selectTransactionAsyncAction = AsyncAction(
    '_HistoryStoreBase.selectTransaction',
    context: context,
  );

  @override
  Future<void> selectTransaction(TransactionId transactionId) {
    return _$selectTransactionAsyncAction.run(
      () => super.selectTransaction(transactionId),
    );
  }

  late final _$_HistoryStoreBaseActionController = ActionController(
    name: '_HistoryStoreBase',
    context: context,
  );

  @override
  void setAccountId(String accountId) {
    final _$actionInfo = _$_HistoryStoreBaseActionController.startAction(
      name: '_HistoryStoreBase.setAccountId',
    );
    try {
      return super.setAccountId(accountId);
    } finally {
      _$_HistoryStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSelectedTransaction() {
    final _$actionInfo = _$_HistoryStoreBaseActionController.startAction(
      name: '_HistoryStoreBase.clearSelectedTransaction',
    );
    try {
      return super.clearSelectedTransaction();
    } finally {
      _$_HistoryStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$_HistoryStoreBaseActionController.startAction(
      name: '_HistoryStoreBase.reset',
    );
    try {
      return super.reset();
    } finally {
      _$_HistoryStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
transactions: ${transactions},
selectedTransaction: ${selectedTransaction},
isLoading: ${isLoading},
isLoadingMore: ${isLoadingMore},
errorMessage: ${errorMessage},
currentAccountId: ${currentAccountId},
hasMoreData: ${hasMoreData}
    ''';
  }
}
