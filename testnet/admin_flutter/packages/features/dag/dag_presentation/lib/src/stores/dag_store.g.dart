// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dag_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DagStore on _DagStore, Store {
  Computed<bool>? _$isConnectedComputed;

  @override
  bool get isConnected => (_$isConnectedComputed ??= Computed<bool>(
    () => super.isConnected,
    name: '_DagStore.isConnected',
  )).value;
  Computed<List<DagBlock>>? _$sortedBlocksComputed;

  @override
  List<DagBlock> get sortedBlocks =>
      (_$sortedBlocksComputed ??= Computed<List<DagBlock>>(
        () => super.sortedBlocks,
        name: '_DagStore.sortedBlocks',
      )).value;
  Computed<List<DagBlock>>? _$tipBlocksComputed;

  @override
  List<DagBlock> get tipBlocks =>
      (_$tipBlocksComputed ??= Computed<List<DagBlock>>(
        () => super.tipBlocks,
        name: '_DagStore.tipBlocks',
      )).value;
  Computed<DagBlock?>? _$sinkBlockComputed;

  @override
  DagBlock? get sinkBlock => (_$sinkBlockComputed ??= Computed<DagBlock?>(
    () => super.sinkBlock,
    name: '_DagStore.sinkBlock',
  )).value;
  Computed<DagBlock?>? _$selectedBlockComputed;

  @override
  DagBlock? get selectedBlock =>
      (_$selectedBlockComputed ??= Computed<DagBlock?>(
        () => super.selectedBlock,
        name: '_DagStore.selectedBlock',
      )).value;

  late final _$connectedNodeIdAtom = Atom(
    name: '_DagStore.connectedNodeId',
    context: context,
  );

  @override
  String? get connectedNodeId {
    _$connectedNodeIdAtom.reportRead();
    return super.connectedNodeId;
  }

  @override
  set connectedNodeId(String? value) {
    _$connectedNodeIdAtom.reportWrite(value, super.connectedNodeId, () {
      super.connectedNodeId = value;
    });
  }

  late final _$dagStateAtom = Atom(
    name: '_DagStore.dagState',
    context: context,
  );

  @override
  DagState? get dagState {
    _$dagStateAtom.reportRead();
    return super.dagState;
  }

  @override
  set dagState(DagState? value) {
    _$dagStateAtom.reportWrite(value, super.dagState, () {
      super.dagState = value;
    });
  }

  late final _$blocksAtom = Atom(name: '_DagStore.blocks', context: context);

  @override
  ObservableMap<String, DagBlock> get blocks {
    _$blocksAtom.reportRead();
    return super.blocks;
  }

  @override
  set blocks(ObservableMap<String, DagBlock> value) {
    _$blocksAtom.reportWrite(value, super.blocks, () {
      super.blocks = value;
    });
  }

  late final _$isConnectingAtom = Atom(
    name: '_DagStore.isConnecting',
    context: context,
  );

  @override
  bool get isConnecting {
    _$isConnectingAtom.reportRead();
    return super.isConnecting;
  }

  @override
  set isConnecting(bool value) {
    _$isConnectingAtom.reportWrite(value, super.isConnecting, () {
      super.isConnecting = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_DagStore.isLoading',
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

  late final _$errorAtom = Atom(name: '_DagStore.error', context: context);

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

  late final _$isLiveModeAtom = Atom(
    name: '_DagStore.isLiveMode',
    context: context,
  );

  @override
  bool get isLiveMode {
    _$isLiveModeAtom.reportRead();
    return super.isLiveMode;
  }

  @override
  set isLiveMode(bool value) {
    _$isLiveModeAtom.reportWrite(value, super.isLiveMode, () {
      super.isLiveMode = value;
    });
  }

  late final _$zoomLevelAtom = Atom(
    name: '_DagStore.zoomLevel',
    context: context,
  );

  @override
  double get zoomLevel {
    _$zoomLevelAtom.reportRead();
    return super.zoomLevel;
  }

  @override
  set zoomLevel(double value) {
    _$zoomLevelAtom.reportWrite(value, super.zoomLevel, () {
      super.zoomLevel = value;
    });
  }

  late final _$selectedBlockHashAtom = Atom(
    name: '_DagStore.selectedBlockHash',
    context: context,
  );

  @override
  String? get selectedBlockHash {
    _$selectedBlockHashAtom.reportRead();
    return super.selectedBlockHash;
  }

  @override
  set selectedBlockHash(String? value) {
    _$selectedBlockHashAtom.reportWrite(value, super.selectedBlockHash, () {
      super.selectedBlockHash = value;
    });
  }

  late final _$hoveredBlockHashAtom = Atom(
    name: '_DagStore.hoveredBlockHash',
    context: context,
  );

  @override
  String? get hoveredBlockHash {
    _$hoveredBlockHashAtom.reportRead();
    return super.hoveredBlockHash;
  }

  @override
  set hoveredBlockHash(String? value) {
    _$hoveredBlockHashAtom.reportWrite(value, super.hoveredBlockHash, () {
      super.hoveredBlockHash = value;
    });
  }

  late final _$newBlockHashesAtom = Atom(
    name: '_DagStore.newBlockHashes',
    context: context,
  );

  @override
  Set<String> get newBlockHashes {
    _$newBlockHashesAtom.reportRead();
    return super.newBlockHashes;
  }

  @override
  set newBlockHashes(Set<String> value) {
    _$newBlockHashesAtom.reportWrite(value, super.newBlockHashes, () {
      super.newBlockHashes = value;
    });
  }

  late final _$isAutoFollowEnabledAtom = Atom(
    name: '_DagStore.isAutoFollowEnabled',
    context: context,
  );

  @override
  bool get isAutoFollowEnabled {
    _$isAutoFollowEnabledAtom.reportRead();
    return super.isAutoFollowEnabled;
  }

  @override
  set isAutoFollowEnabled(bool value) {
    _$isAutoFollowEnabledAtom.reportWrite(value, super.isAutoFollowEnabled, () {
      super.isAutoFollowEnabled = value;
    });
  }

  late final _$connectAsyncAction = AsyncAction(
    '_DagStore.connect',
    context: context,
  );

  @override
  Future<void> connect(String nodeId) {
    return _$connectAsyncAction.run(() => super.connect(nodeId));
  }

  late final _$autoConnectAsyncAction = AsyncAction(
    '_DagStore.autoConnect',
    context: context,
  );

  @override
  Future<void> autoConnect() {
    return _$autoConnectAsyncAction.run(() => super.autoConnect());
  }

  late final _$disconnectAsyncAction = AsyncAction(
    '_DagStore.disconnect',
    context: context,
  );

  @override
  Future<void> disconnect() {
    return _$disconnectAsyncAction.run(() => super.disconnect());
  }

  late final _$loadInitialStateAsyncAction = AsyncAction(
    '_DagStore.loadInitialState',
    context: context,
  );

  @override
  Future<void> loadInitialState() {
    return _$loadInitialStateAsyncAction.run(() => super.loadInitialState());
  }

  late final _$_DagStoreActionController = ActionController(
    name: '_DagStore',
    context: context,
  );

  @override
  void _updateState(DagState state) {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore._updateState',
    );
    try {
      return super._updateState(state);
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _updateStateMetadata(DagState state) {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore._updateStateMetadata',
    );
    try {
      return super._updateStateMetadata(state);
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _addBlock(DagBlock block) {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore._addBlock',
    );
    try {
      return super._addBlock(block);
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleChainChange(VirtualChainChanged event) {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore._handleChainChange',
    );
    try {
      return super._handleChainChange(event);
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleLiveMode() {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.toggleLiveMode',
    );
    try {
      return super.toggleLiveMode();
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void zoomIn() {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.zoomIn',
    );
    try {
      return super.zoomIn();
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void zoomOut() {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.zoomOut',
    );
    try {
      return super.zoomOut();
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resetZoom() {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.resetZoom',
    );
    try {
      return super.resetZoom();
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectBlock(String? hash) {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.selectBlock',
    );
    try {
      return super.selectBlock(hash);
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void hoverBlock(String? hash) {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.hoverBlock',
    );
    try {
      return super.hoverBlock(hash);
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void disableAutoFollow() {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.disableAutoFollow',
    );
    try {
      return super.disableAutoFollow();
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void enableAutoFollow() {
    final _$actionInfo = _$_DagStoreActionController.startAction(
      name: '_DagStore.enableAutoFollow',
    );
    try {
      return super.enableAutoFollow();
    } finally {
      _$_DagStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
connectedNodeId: ${connectedNodeId},
dagState: ${dagState},
blocks: ${blocks},
isConnecting: ${isConnecting},
isLoading: ${isLoading},
error: ${error},
isLiveMode: ${isLiveMode},
zoomLevel: ${zoomLevel},
selectedBlockHash: ${selectedBlockHash},
hoveredBlockHash: ${hoveredBlockHash},
newBlockHashes: ${newBlockHashes},
isAutoFollowEnabled: ${isAutoFollowEnabled},
isConnected: ${isConnected},
sortedBlocks: ${sortedBlocks},
tipBlocks: ${tipBlocks},
sinkBlock: ${sinkBlock},
selectedBlock: ${selectedBlock}
    ''';
  }
}
