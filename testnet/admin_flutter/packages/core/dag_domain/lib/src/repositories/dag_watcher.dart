import '../entities/entities.dart';

/// Interface for watching DAG updates (ISP - Interface Segregation Principle)
abstract interface class DagWatcher {
  /// Watch for new blocks added to the DAG
  Stream<DagBlock> watchBlockAdded();

  /// Watch for virtual chain changes (reorgs)
  Stream<VirtualChainChanged> watchVirtualChainChanged();

  /// Watch for DAG state updates (combines all events into state changes)
  Stream<DagState> watchDagState();
}
