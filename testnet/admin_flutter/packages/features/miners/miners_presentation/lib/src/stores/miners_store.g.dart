// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'miners_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$MinersStore on _MinersStore, Store {
  Computed<bool>? _$hasMinersComputed;

  @override
  bool get hasMiners => (_$hasMinersComputed ??= Computed<bool>(
    () => super.hasMiners,
    name: '_MinersStore.hasMiners',
  )).value;
  Computed<int>? _$runningCountComputed;

  @override
  int get runningCount => (_$runningCountComputed ??= Computed<int>(
    () => super.runningCount,
    name: '_MinersStore.runningCount',
  )).value;
  Computed<int>? _$stoppedCountComputed;

  @override
  int get stoppedCount => (_$stoppedCountComputed ??= Computed<int>(
    () => super.stoppedCount,
    name: '_MinersStore.stoppedCount',
  )).value;
  Computed<double>? _$totalHashrateComputed;

  @override
  double get totalHashrate => (_$totalHashrateComputed ??= Computed<double>(
    () => super.totalHashrate,
    name: '_MinersStore.totalHashrate',
  )).value;
  Computed<int>? _$totalBlocksFoundComputed;

  @override
  int get totalBlocksFound => (_$totalBlocksFoundComputed ??= Computed<int>(
    () => super.totalBlocksFound,
    name: '_MinersStore.totalBlocksFound',
  )).value;

  late final _$minersAtom = Atom(name: '_MinersStore.miners', context: context);

  @override
  ObservableList<MinerInstance> get miners {
    _$minersAtom.reportRead();
    return super.miners;
  }

  @override
  set miners(ObservableList<MinerInstance> value) {
    _$minersAtom.reportWrite(value, super.miners, () {
      super.miners = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_MinersStore.isLoading',
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

  late final _$errorAtom = Atom(name: '_MinersStore.error', context: context);

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$operationErrorAtom = Atom(
    name: '_MinersStore.operationError',
    context: context,
  );

  @override
  String? get operationError {
    _$operationErrorAtom.reportRead();
    return super.operationError;
  }

  @override
  set operationError(String? value) {
    _$operationErrorAtom.reportWrite(value, super.operationError, () {
      super.operationError = value;
    });
  }

  late final _$isOperatingAtom = Atom(
    name: '_MinersStore.isOperating',
    context: context,
  );

  @override
  bool get isOperating {
    _$isOperatingAtom.reportRead();
    return super.isOperating;
  }

  @override
  set isOperating(bool value) {
    _$isOperatingAtom.reportWrite(value, super.isOperating, () {
      super.isOperating = value;
    });
  }

  late final _$initAsyncAction = AsyncAction(
    '_MinersStore.init',
    context: context,
  );

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loadMinersAsyncAction = AsyncAction(
    '_MinersStore.loadMiners',
    context: context,
  );

  @override
  Future<void> loadMiners() {
    return _$loadMinersAsyncAction.run(() => super.loadMiners());
  }

  late final _$addMinerAsyncAction = AsyncAction(
    '_MinersStore.addMiner',
    context: context,
  );

  @override
  Future<void> addMiner(MinerConfig config) {
    return _$addMinerAsyncAction.run(() => super.addMiner(config));
  }

  late final _$removeMinerAsyncAction = AsyncAction(
    '_MinersStore.removeMiner',
    context: context,
  );

  @override
  Future<void> removeMiner(String minerId) {
    return _$removeMinerAsyncAction.run(() => super.removeMiner(minerId));
  }

  late final _$startMinerAsyncAction = AsyncAction(
    '_MinersStore.startMiner',
    context: context,
  );

  @override
  Future<void> startMiner(String minerId) {
    return _$startMinerAsyncAction.run(() => super.startMiner(minerId));
  }

  late final _$stopMinerAsyncAction = AsyncAction(
    '_MinersStore.stopMiner',
    context: context,
  );

  @override
  Future<void> stopMiner(String minerId) {
    return _$stopMinerAsyncAction.run(() => super.stopMiner(minerId));
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_MinersStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$_MinersStoreActionController = ActionController(
    name: '_MinersStore',
    context: context,
  );

  @override
  void _updateMinerStatus(String minerId, String status) {
    final _$actionInfo = _$_MinersStoreActionController.startAction(
      name: '_MinersStore._updateMinerStatus',
    );
    try {
      return super._updateMinerStatus(minerId, status);
    } finally {
      _$_MinersStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
miners: ${miners},
isLoading: ${isLoading},
error: ${error},
operationError: ${operationError},
isOperating: ${isOperating},
hasMiners: ${hasMiners},
runningCount: ${runningCount},
stoppedCount: ${stoppedCount},
totalHashrate: ${totalHashrate},
totalBlocksFound: ${totalBlocksFound}
    ''';
  }
}
