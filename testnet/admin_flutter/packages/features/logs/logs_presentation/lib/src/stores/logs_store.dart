import 'dart:async';
import 'dart:math' as math;

import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';
import 'package:logs_domain/logs_domain.dart';
import 'package:mobx/mobx.dart';

part 'logs_store.g.dart';

@lazySingleton
class LogsStore = _LogsStore with _$LogsStore;

abstract class _LogsStore with Store {
  final WatchLogsUseCase _watchLogsUseCase;
  final GetContainerIdsUseCase _getContainerIdsUseCase;

  _LogsStore(
    this._watchLogsUseCase,
    this._getContainerIdsUseCase,
  );

  StreamSubscription<LogEntry>? _logsSubscription;
  static const int _maxLogEntries = 1000;
  // Batch removal threshold: trim when 20% over limit to amortize O(N) removeRange cost
  static const int _overflowThreshold = 1200;

  /// Version token to prevent race conditions when filter changes rapidly.
  /// Old stream events are ignored if their version doesn't match current.
  int _subscriptionVersion = 0;

  @observable
  ObservableList<LogEntry> logs = ObservableList<LogEntry>();

  @observable
  ObservableList<String> containerIds = ObservableList<String>();

  @observable
  String? selectedContainerId;

  @observable
  LogLevel? minLevel;

  @observable
  bool isConnected = false;

  @observable
  String? error;

  @observable
  bool isPaused = false;

  @computed
  List<LogEntry> get filteredLogs {
    // Filter and reverse to show newest first (logs are stored oldest-first for O(1) append)
    // Use List.of(...).reversed to avoid creating intermediate lists
    final filtered = logs.where((log) {
      if (selectedContainerId != null &&
          log.containerId != selectedContainerId) {
        return false;
      }
      if (minLevel != null && log.level.index < minLevel!.index) {
        return false;
      }
      return true;
    }).toList();
    // Reverse in-place for O(N) instead of O(2N) from .reversed.toList()
    return filtered.reversed.toList(growable: false);
  }

  @action
  Future<void> init() async {
    await loadContainerIds();
    _subscribeToLogs();
  }

  @action
  Future<void> loadContainerIds() async {
    try {
      final ids = await _getContainerIdsUseCase();
      containerIds = ObservableList.of(ids);
    } catch (e) {
      error = e.toString();
    }
  }

  void _subscribeToLogs() {
    _logsSubscription?.cancel();
    _logsSubscription = null;

    // Increment version to invalidate any pending events from old subscription
    final currentVersion = ++_subscriptionVersion;

    _logsSubscription = _watchLogsUseCase(
      containerId: selectedContainerId,
      minLevel: minLevel,
    ).listen(
      (log) {
        // Ignore events from stale subscriptions (race condition protection)
        if (currentVersion != _subscriptionVersion) return;

        if (!isPaused) {
          logs.add(log);
          // Batch removal: trim when over threshold instead of per-entry removal
          // This amortizes O(N) removeRange cost over 200 entries
          if (logs.length > _overflowThreshold) {
            // Use math.max to prevent negative range in edge cases
            final removeCount = math.max(0, logs.length - _maxLogEntries);
            if (removeCount > 0) {
              logs.removeRange(0, removeCount);
            }
          }
        }
        isConnected = true;
        error = null;
      },
      onError: (e) {
        // Ignore errors from stale subscriptions
        if (currentVersion != _subscriptionVersion) return;

        error = e.toString();
        isConnected = false;
      },
      onDone: () {
        // Ignore done from stale subscriptions
        if (currentVersion != _subscriptionVersion) return;

        isConnected = false;
      },
    );
  }

  @action
  void setContainerFilter(String? containerId) {
    selectedContainerId = containerId;
    logs.clear();
    _subscribeToLogs();
  }

  @action
  void setLevelFilter(LogLevel? level) {
    minLevel = level;
    logs.clear();
    _subscribeToLogs();
  }

  @action
  void togglePause() {
    isPaused = !isPaused;
  }

  @action
  void clearLogs() {
    logs.clear();
  }

  void dispose() {
    _logsSubscription?.cancel();
  }
}
