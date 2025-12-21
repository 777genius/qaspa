import 'dart:async';
import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';
import 'package:miners_domain/miners_domain.dart';
import 'package:mobx/mobx.dart';

part 'miners_store.g.dart';

@lazySingleton
class MinersStore = _MinersStore with _$MinersStore;

abstract class _MinersStore with Store {
  final GetMinersUseCase _getMinersUseCase;
  final WatchMinersUseCase _watchMinersUseCase;
  final AddMinerUseCase _addMinerUseCase;
  final RemoveMinerUseCase _removeMinerUseCase;
  final StartMinerUseCase _startMinerUseCase;
  final StopMinerUseCase _stopMinerUseCase;

  _MinersStore(
    this._getMinersUseCase,
    this._watchMinersUseCase,
    this._addMinerUseCase,
    this._removeMinerUseCase,
    this._startMinerUseCase,
    this._stopMinerUseCase,
  );

  StreamSubscription<List<MinerInstance>>? _minersSubscription;

  /// Version token to prevent race conditions when subscription changes.
  /// Old stream events are ignored if their version doesn't match current.
  int _subscriptionVersion = 0;

  @observable
  ObservableList<MinerInstance> miners = ObservableList<MinerInstance>();

  @observable
  bool isLoading = false;

  @observable
  String? error;

  @observable
  String? operationError;

  @observable
  bool isOperating = false;

  @computed
  bool get hasMiners => miners.isNotEmpty;

  @computed
  int get runningCount => miners.where((m) => m.status == 'running').length;

  @computed
  int get stoppedCount => miners.where((m) => m.status == 'stopped').length;

  @computed
  double get totalHashrate {
    // Filter out NaN/Infinity/negative values to prevent invalid total
    final result = miners.fold(0.0, (sum, m) {
      final hr = m.hashrate;
      if (hr.isNaN || hr.isInfinite || hr < 0) return sum;
      return sum + hr;
    });
    return result.isNaN || result.isInfinite ? 0.0 : result;
  }

  @computed
  int get totalBlocksFound =>
      miners.fold(0, (sum, m) => sum + m.blocksFound);

  @action
  Future<void> init() async {
    await loadMiners();
    _subscribeToUpdates();
  }

  @action
  Future<void> loadMiners() async {
    isLoading = true;
    error = null;

    try {
      final result = await _getMinersUseCase();
      // Use clear+addAll to preserve list reference and avoid stale observers
      miners.clear();
      miners.addAll(result);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  void _subscribeToUpdates() {
    // Cancel existing subscription to prevent memory leak on re-init
    _minersSubscription?.cancel();
    _minersSubscription = null;

    // Increment version to invalidate any pending events from old subscription
    final currentVersion = ++_subscriptionVersion;

    _minersSubscription = _watchMinersUseCase().listen(
      (newMiners) {
        // Ignore events from stale subscriptions (race condition protection)
        if (currentVersion != _subscriptionVersion) return;

        // Skip update if nothing changed (avoids O(N) clear+addAll on frequent updates)
        if (!_hasMinerChanges(newMiners)) return;

        // Merge new data with existing, preserving static fields (targetNode)
        final mergedMiners = _mergeMiners(newMiners);

        // Use clear+addAll to preserve list reference and avoid stale observers
        miners.clear();
        miners.addAll(mergedMiners);
        error = null;
      },
      onError: (e) {
        // Ignore errors from stale subscriptions
        if (currentVersion != _subscriptionVersion) return;

        error = e.toString();
      },
      onDone: () {
        // Ignore done from stale subscriptions
        if (currentVersion != _subscriptionVersion) return;

        error = 'Connection closed';
      },
    );
  }

  /// Merge new miners with existing, preserving static fields (targetNode) if missing
  List<MinerInstance> _mergeMiners(List<MinerInstance> newMiners) {
    return newMiners.map((newMiner) {
      // Find existing miner by ID
      final existingIndex = miners.indexWhere((m) => m.id == newMiner.id);
      if (existingIndex < 0) return newMiner;

      final existing = miners[existingIndex];

      // If new miner has empty targetNode but existing has valid one, preserve it
      final targetNode = newMiner.targetNode.isNotEmpty
          ? newMiner.targetNode
          : existing.targetNode;

      // Return merged miner
      return MinerInstance(
        id: newMiner.id,
        name: newMiner.name,
        status: newMiner.status,
        targetNode: targetNode,
        hashrate: newMiner.hashrate,
        blocksFound: newMiner.blocksFound,
      );
    }).toList();
  }

  /// Check if newMiners differ from current miners (by ID, status, and metrics)
  bool _hasMinerChanges(List<MinerInstance> newMiners) {
    if (miners.length != newMiners.length) return true;

    // Build a map of new miners by ID for O(1) lookup (order-independent)
    final newMinersMap = {for (final m in newMiners) m.id: m};

    for (final current in miners) {
      final updated = newMinersMap[current.id];
      // Miner was removed or ID changed
      if (updated == null) return true;
      // Check status
      if (current.status != updated.status) return true;
      // Check hashrate and blocks changes
      if (current.hashrate != updated.hashrate ||
          current.blocksFound != updated.blocksFound) {
        return true;
      }
    }
    return false;
  }

  @action
  Future<void> addMiner(MinerConfig config) async {
    isOperating = true;
    operationError = null;

    try {
      final miner = await _addMinerUseCase(config);
      miners.add(miner);
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> removeMiner(String minerId) async {
    isOperating = true;
    operationError = null;

    try {
      await _removeMinerUseCase(minerId);
      miners.removeWhere((m) => m.id == minerId);
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> startMiner(String minerId) async {
    isOperating = true;
    operationError = null;

    try {
      await _startMinerUseCase(minerId);
      _updateMinerStatus(minerId, 'starting');
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  Future<void> stopMiner(String minerId) async {
    isOperating = true;
    operationError = null;

    try {
      await _stopMinerUseCase(minerId);
      _updateMinerStatus(minerId, 'stopping');
    } catch (e) {
      operationError = e.toString();
      rethrow;
    } finally {
      isOperating = false;
    }
  }

  @action
  void _updateMinerStatus(String minerId, String status) {
    final index = miners.indexWhere((m) => m.id == minerId);
    if (index >= 0) {
      final miner = miners[index];
      miners[index] = MinerInstance(
        id: miner.id,
        name: miner.name,
        status: status,
        targetNode: miner.targetNode,
        hashrate: miner.hashrate,
        blocksFound: miner.blocksFound,
      );
    }
  }

  @action
  Future<void> refresh() async {
    await loadMiners();
  }

  void dispose() {
    _minersSubscription?.cancel();
  }
}
