// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DashboardStore on _DashboardStore, Store {
  Computed<bool>? _$hasStatsComputed;

  @override
  bool get hasStats => (_$hasStatsComputed ??= Computed<bool>(
    () => super.hasStats,
    name: '_DashboardStore.hasStats',
  )).value;
  Computed<int>? _$totalNodesComputed;

  @override
  int get totalNodes => (_$totalNodesComputed ??= Computed<int>(
    () => super.totalNodes,
    name: '_DashboardStore.totalNodes',
  )).value;
  Computed<int>? _$runningNodesComputed;

  @override
  int get runningNodes => (_$runningNodesComputed ??= Computed<int>(
    () => super.runningNodes,
    name: '_DashboardStore.runningNodes',
  )).value;
  Computed<int>? _$totalMinersComputed;

  @override
  int get totalMiners => (_$totalMinersComputed ??= Computed<int>(
    () => super.totalMiners,
    name: '_DashboardStore.totalMiners',
  )).value;
  Computed<int>? _$runningMinersComputed;

  @override
  int get runningMiners => (_$runningMinersComputed ??= Computed<int>(
    () => super.runningMiners,
    name: '_DashboardStore.runningMiners',
  )).value;
  Computed<int>? _$totalBlockCountComputed;

  @override
  int get totalBlockCount => (_$totalBlockCountComputed ??= Computed<int>(
    () => super.totalBlockCount,
    name: '_DashboardStore.totalBlockCount',
  )).value;
  Computed<double>? _$totalHashrateComputed;

  @override
  double get totalHashrate => (_$totalHashrateComputed ??= Computed<double>(
    () => super.totalHashrate,
    name: '_DashboardStore.totalHashrate',
  )).value;

  late final _$statsAtom = Atom(
    name: '_DashboardStore.stats',
    context: context,
  );

  @override
  ClusterStats? get stats {
    _$statsAtom.reportRead();
    return super.stats;
  }

  @override
  set stats(ClusterStats? value) {
    _$statsAtom.reportWrite(value, super.stats, () {
      super.stats = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_DashboardStore.isLoading',
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

  late final _$errorAtom = Atom(
    name: '_DashboardStore.error',
    context: context,
  );

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

  late final _$initAsyncAction = AsyncAction(
    '_DashboardStore.init',
    context: context,
  );

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loadStatsAsyncAction = AsyncAction(
    '_DashboardStore.loadStats',
    context: context,
  );

  @override
  Future<void> loadStats() {
    return _$loadStatsAsyncAction.run(() => super.loadStats());
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_DashboardStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  @override
  String toString() {
    return '''
stats: ${stats},
isLoading: ${isLoading},
error: ${error},
hasStats: ${hasStats},
totalNodes: ${totalNodes},
runningNodes: ${runningNodes},
totalMiners: ${totalMiners},
runningMiners: ${runningMiners},
totalBlockCount: ${totalBlockCount},
totalHashrate: ${totalHashrate}
    ''';
  }
}
