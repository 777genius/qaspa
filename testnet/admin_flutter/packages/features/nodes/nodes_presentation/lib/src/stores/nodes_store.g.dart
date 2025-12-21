// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nodes_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$NodesStore on _NodesStore, Store {
  Computed<bool>? _$hasNodesComputed;

  @override
  bool get hasNodes => (_$hasNodesComputed ??= Computed<bool>(
    () => super.hasNodes,
    name: '_NodesStore.hasNodes',
  )).value;
  Computed<int>? _$runningCountComputed;

  @override
  int get runningCount => (_$runningCountComputed ??= Computed<int>(
    () => super.runningCount,
    name: '_NodesStore.runningCount',
  )).value;
  Computed<int>? _$stoppedCountComputed;

  @override
  int get stoppedCount => (_$stoppedCountComputed ??= Computed<int>(
    () => super.stoppedCount,
    name: '_NodesStore.stoppedCount',
  )).value;

  late final _$nodesAtom = Atom(name: '_NodesStore.nodes', context: context);

  @override
  ObservableList<NodeInstance> get nodes {
    _$nodesAtom.reportRead();
    return super.nodes;
  }

  @override
  set nodes(ObservableList<NodeInstance> value) {
    _$nodesAtom.reportWrite(value, super.nodes, () {
      super.nodes = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_NodesStore.isLoading',
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

  late final _$errorAtom = Atom(name: '_NodesStore.error', context: context);

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
    name: '_NodesStore.operationError',
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
    name: '_NodesStore.isOperating',
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
    '_NodesStore.init',
    context: context,
  );

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loadNodesAsyncAction = AsyncAction(
    '_NodesStore.loadNodes',
    context: context,
  );

  @override
  Future<void> loadNodes() {
    return _$loadNodesAsyncAction.run(() => super.loadNodes());
  }

  late final _$addNodeAsyncAction = AsyncAction(
    '_NodesStore.addNode',
    context: context,
  );

  @override
  Future<void> addNode(NodeConfig config) {
    return _$addNodeAsyncAction.run(() => super.addNode(config));
  }

  late final _$removeNodeAsyncAction = AsyncAction(
    '_NodesStore.removeNode',
    context: context,
  );

  @override
  Future<void> removeNode(String nodeId) {
    return _$removeNodeAsyncAction.run(() => super.removeNode(nodeId));
  }

  late final _$startNodeAsyncAction = AsyncAction(
    '_NodesStore.startNode',
    context: context,
  );

  @override
  Future<void> startNode(String nodeId) {
    return _$startNodeAsyncAction.run(() => super.startNode(nodeId));
  }

  late final _$stopNodeAsyncAction = AsyncAction(
    '_NodesStore.stopNode',
    context: context,
  );

  @override
  Future<void> stopNode(String nodeId) {
    return _$stopNodeAsyncAction.run(() => super.stopNode(nodeId));
  }

  late final _$restartNodeAsyncAction = AsyncAction(
    '_NodesStore.restartNode',
    context: context,
  );

  @override
  Future<void> restartNode(String nodeId) {
    return _$restartNodeAsyncAction.run(() => super.restartNode(nodeId));
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_NodesStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$_NodesStoreActionController = ActionController(
    name: '_NodesStore',
    context: context,
  );

  @override
  void _updateNodeStatus(String nodeId, String status) {
    final _$actionInfo = _$_NodesStoreActionController.startAction(
      name: '_NodesStore._updateNodeStatus',
    );
    try {
      return super._updateNodeStatus(nodeId, status);
    } finally {
      _$_NodesStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
nodes: ${nodes},
isLoading: ${isLoading},
error: ${error},
operationError: ${operationError},
isOperating: ${isOperating},
hasNodes: ${hasNodes},
runningCount: ${runningCount},
stoppedCount: ${stoppedCount}
    ''';
  }
}
