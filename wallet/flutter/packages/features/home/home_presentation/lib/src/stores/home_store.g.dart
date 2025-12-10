// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$HomeStore on _HomeStoreBase, Store {
  Computed<bool>? _$hasBalanceComputed;

  @override
  bool get hasBalance => (_$hasBalanceComputed ??= Computed<bool>(
    () => super.hasBalance,
    name: '_HomeStoreBase.hasBalance',
  )).value;
  Computed<bool>? _$hasTransactionsComputed;

  @override
  bool get hasTransactions => (_$hasTransactionsComputed ??= Computed<bool>(
    () => super.hasTransactions,
    name: '_HomeStoreBase.hasTransactions',
  )).value;

  late final _$balanceAtom = Atom(
    name: '_HomeStoreBase.balance',
    context: context,
  );

  @override
  Balance? get balance {
    _$balanceAtom.reportRead();
    return super.balance;
  }

  @override
  set balance(Balance? value) {
    _$balanceAtom.reportWrite(value, super.balance, () {
      super.balance = value;
    });
  }

  late final _$recentTransactionsAtom = Atom(
    name: '_HomeStoreBase.recentTransactions',
    context: context,
  );

  @override
  ObservableList<Transaction> get recentTransactions {
    _$recentTransactionsAtom.reportRead();
    return super.recentTransactions;
  }

  @override
  set recentTransactions(ObservableList<Transaction> value) {
    _$recentTransactionsAtom.reportWrite(value, super.recentTransactions, () {
      super.recentTransactions = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_HomeStoreBase.isLoading',
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

  late final _$errorMessageAtom = Atom(
    name: '_HomeStoreBase.errorMessage',
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
    name: '_HomeStoreBase.currentAccountId',
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

  late final _$loadHomeDataAsyncAction = AsyncAction(
    '_HomeStoreBase.loadHomeData',
    context: context,
  );

  @override
  Future<void> loadHomeData({required String accountId}) {
    return _$loadHomeDataAsyncAction.run(
      () => super.loadHomeData(accountId: accountId),
    );
  }

  late final _$refreshBalanceAsyncAction = AsyncAction(
    '_HomeStoreBase.refreshBalance',
    context: context,
  );

  @override
  Future<void> refreshBalance() {
    return _$refreshBalanceAsyncAction.run(() => super.refreshBalance());
  }

  late final _$refreshTransactionsAsyncAction = AsyncAction(
    '_HomeStoreBase.refreshTransactions',
    context: context,
  );

  @override
  Future<void> refreshTransactions() {
    return _$refreshTransactionsAsyncAction.run(
      () => super.refreshTransactions(),
    );
  }

  late final _$_HomeStoreBaseActionController = ActionController(
    name: '_HomeStoreBase',
    context: context,
  );

  @override
  void reset() {
    final _$actionInfo = _$_HomeStoreBaseActionController.startAction(
      name: '_HomeStoreBase.reset',
    );
    try {
      return super.reset();
    } finally {
      _$_HomeStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
balance: ${balance},
recentTransactions: ${recentTransactions},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
currentAccountId: ${currentAccountId},
hasBalance: ${hasBalance},
hasTransactions: ${hasTransactions}
    ''';
  }
}
