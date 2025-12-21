import '../entities/node_instance.dart';
import '../value_objects/node_config.dart';

/// Repository interface for node operations
abstract interface class NodeRepository {
  /// Get all nodes
  Future<List<NodeInstance>> getNodes();

  /// Get a single node by ID
  Future<NodeInstance> getNode(String nodeId);

  /// Watch nodes for updates
  Stream<List<NodeInstance>> watchNodes();

  /// Add a new node
  Future<NodeInstance> addNode(NodeConfig config);

  /// Remove a node
  Future<void> removeNode(String nodeId);

  /// Start a node
  Future<void> startNode(String nodeId);

  /// Stop a node
  Future<void> stopNode(String nodeId);

  /// Restart a node
  Future<void> restartNode(String nodeId);
}
