import 'dart:async';
import 'package:admin_domain/admin_domain.dart';
import 'package:dashboard_domain/dashboard_domain.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'dashboard_store.g.dart';

@lazySingleton
class DashboardStore = _DashboardStore with _$DashboardStore;

abstract class _DashboardStore with Store {
  final GetClusterStatsUseCase _getClusterStatsUseCase;
  final WatchClusterStatsUseCase _watchClusterStatsUseCase;

  _DashboardStore(
    this._getClusterStatsUseCase,
    this._watchClusterStatsUseCase,
  );

  StreamSubscription<ClusterStats>? _statsSubscription;

  /// Subscription version to prevent race conditions when re-subscribing.
  /// Old stream events are ignored if their version doesn't match current.
  int _subscriptionVersion = 0;

  @observable
  ClusterStats? stats;

  @observable
  bool isLoading = false;

  @observable
  String? error;

  @computed
  bool get hasStats => stats != null;

  @computed
  int get totalNodes => stats?.totalNodes ?? 0;

  @computed
  int get runningNodes => stats?.runningNodes ?? 0;

  @computed
  int get totalMiners => stats?.totalMiners ?? 0;

  @computed
  int get runningMiners => stats?.runningMiners ?? 0;

  @computed
  int get totalBlockCount => stats?.totalBlockCount ?? 0;

  @computed
  double get totalHashrate => stats?.totalHashrate ?? 0;

  @action
  Future<void> init() async {
    await loadStats();
    _subscribeToUpdates();
  }

  @action
  Future<void> loadStats() async {
    isLoading = true;
    error = null;

    try {
      stats = await _getClusterStatsUseCase();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  void _subscribeToUpdates() {
    // Cancel existing subscription to prevent memory leak on re-init
    _statsSubscription?.cancel();

    // Increment version to invalidate any pending events from old subscription
    final currentVersion = ++_subscriptionVersion;

    _statsSubscription = _watchClusterStatsUseCase().listen(
      (newStats) {
        // Ignore events from stale subscriptions (race condition protection)
        if (currentVersion != _subscriptionVersion) return;

        stats = newStats;
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

  @action
  Future<void> refresh() async {
    await loadStats();
  }

  void dispose() {
    _statsSubscription?.cancel();
  }
}
