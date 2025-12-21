import 'dag_connection.dart';
import 'dag_reader.dart';
import 'dag_watcher.dart';

/// Full DAG repository interface (composition of segregated interfaces)
/// Implements all three interfaces: DagReader, DagWatcher, DagConnectionManager
abstract interface class DagRepository
    implements DagReader, DagWatcher, DagConnectionManager {
  /// Dispose the repository and cleanup resources
  void dispose();
}
