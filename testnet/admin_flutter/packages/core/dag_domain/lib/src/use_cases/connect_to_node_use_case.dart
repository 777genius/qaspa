import 'package:injectable/injectable.dart';

import '../entities/entities.dart';
import '../repositories/dag_repository.dart';

/// Use Case: Connect to a node and start watching DAG updates
@lazySingleton
class ConnectToNodeUseCase {
  final DagRepository _repository;

  ConnectToNodeUseCase(this._repository);

  /// Connect to node and return stream of DAG state updates
  Future<Stream<DagState>> call(String nodeId) async {
    await _repository.connect(nodeId);
    return _repository.watchDagState();
  }

  /// Disconnect from current node
  Future<void> disconnect() => _repository.disconnect();

  /// Check if currently connected
  bool get isConnected => _repository.isConnected;
}
