import 'package:injectable/injectable.dart';

import '../entities/entities.dart';
import '../repositories/dag_watcher.dart';

/// Use Case: Watch for DAG state updates
@lazySingleton
class WatchDagUpdatesUseCase {
  final DagWatcher _watcher;

  WatchDagUpdatesUseCase(this._watcher);

  /// Watch for complete DAG state updates
  Stream<DagState> call() => _watcher.watchDagState();

  /// Watch for new blocks only
  Stream<DagBlock> watchBlocks() => _watcher.watchBlockAdded();

  /// Watch for chain reorganizations only
  Stream<VirtualChainChanged> watchReorgs() =>
      _watcher.watchVirtualChainChanged();
}
