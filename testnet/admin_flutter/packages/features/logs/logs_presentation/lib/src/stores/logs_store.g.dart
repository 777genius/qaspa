// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logs_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LogsStore on _LogsStore, Store {
  Computed<List<LogEntry>>? _$filteredLogsComputed;

  @override
  List<LogEntry> get filteredLogs =>
      (_$filteredLogsComputed ??= Computed<List<LogEntry>>(
        () => super.filteredLogs,
        name: '_LogsStore.filteredLogs',
      )).value;

  late final _$logsAtom = Atom(name: '_LogsStore.logs', context: context);

  @override
  ObservableList<LogEntry> get logs {
    _$logsAtom.reportRead();
    return super.logs;
  }

  @override
  set logs(ObservableList<LogEntry> value) {
    _$logsAtom.reportWrite(value, super.logs, () {
      super.logs = value;
    });
  }

  late final _$containerIdsAtom = Atom(
    name: '_LogsStore.containerIds',
    context: context,
  );

  @override
  ObservableList<String> get containerIds {
    _$containerIdsAtom.reportRead();
    return super.containerIds;
  }

  @override
  set containerIds(ObservableList<String> value) {
    _$containerIdsAtom.reportWrite(value, super.containerIds, () {
      super.containerIds = value;
    });
  }

  late final _$selectedContainerIdAtom = Atom(
    name: '_LogsStore.selectedContainerId',
    context: context,
  );

  @override
  String? get selectedContainerId {
    _$selectedContainerIdAtom.reportRead();
    return super.selectedContainerId;
  }

  @override
  set selectedContainerId(String? value) {
    _$selectedContainerIdAtom.reportWrite(value, super.selectedContainerId, () {
      super.selectedContainerId = value;
    });
  }

  late final _$minLevelAtom = Atom(
    name: '_LogsStore.minLevel',
    context: context,
  );

  @override
  LogLevel? get minLevel {
    _$minLevelAtom.reportRead();
    return super.minLevel;
  }

  @override
  set minLevel(LogLevel? value) {
    _$minLevelAtom.reportWrite(value, super.minLevel, () {
      super.minLevel = value;
    });
  }

  late final _$isConnectedAtom = Atom(
    name: '_LogsStore.isConnected',
    context: context,
  );

  @override
  bool get isConnected {
    _$isConnectedAtom.reportRead();
    return super.isConnected;
  }

  @override
  set isConnected(bool value) {
    _$isConnectedAtom.reportWrite(value, super.isConnected, () {
      super.isConnected = value;
    });
  }

  late final _$errorAtom = Atom(name: '_LogsStore.error', context: context);

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

  late final _$isPausedAtom = Atom(
    name: '_LogsStore.isPaused',
    context: context,
  );

  @override
  bool get isPaused {
    _$isPausedAtom.reportRead();
    return super.isPaused;
  }

  @override
  set isPaused(bool value) {
    _$isPausedAtom.reportWrite(value, super.isPaused, () {
      super.isPaused = value;
    });
  }

  late final _$initAsyncAction = AsyncAction(
    '_LogsStore.init',
    context: context,
  );

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$loadContainerIdsAsyncAction = AsyncAction(
    '_LogsStore.loadContainerIds',
    context: context,
  );

  @override
  Future<void> loadContainerIds() {
    return _$loadContainerIdsAsyncAction.run(() => super.loadContainerIds());
  }

  late final _$_LogsStoreActionController = ActionController(
    name: '_LogsStore',
    context: context,
  );

  @override
  void setContainerFilter(String? containerId) {
    final _$actionInfo = _$_LogsStoreActionController.startAction(
      name: '_LogsStore.setContainerFilter',
    );
    try {
      return super.setContainerFilter(containerId);
    } finally {
      _$_LogsStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setLevelFilter(LogLevel? level) {
    final _$actionInfo = _$_LogsStoreActionController.startAction(
      name: '_LogsStore.setLevelFilter',
    );
    try {
      return super.setLevelFilter(level);
    } finally {
      _$_LogsStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void togglePause() {
    final _$actionInfo = _$_LogsStoreActionController.startAction(
      name: '_LogsStore.togglePause',
    );
    try {
      return super.togglePause();
    } finally {
      _$_LogsStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearLogs() {
    final _$actionInfo = _$_LogsStoreActionController.startAction(
      name: '_LogsStore.clearLogs',
    );
    try {
      return super.clearLogs();
    } finally {
      _$_LogsStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
logs: ${logs},
containerIds: ${containerIds},
selectedContainerId: ${selectedContainerId},
minLevel: ${minLevel},
isConnected: ${isConnected},
error: ${error},
isPaused: ${isPaused},
filteredLogs: ${filteredLogs}
    ''';
  }
}
