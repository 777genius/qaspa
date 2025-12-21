/// Interface for managing DAG connection (ISP - Interface Segregation Principle)
abstract interface class DagConnectionManager {
  /// Connect to a specific node by ID
  Future<void> connect(String nodeId);

  /// Disconnect from current node
  Future<void> disconnect();

  /// Check if currently connected
  bool get isConnected;

  /// Watch connection state changes
  Stream<bool> get connectionState;

  /// Get currently connected node ID (null if not connected)
  String? get currentNodeId;
}
