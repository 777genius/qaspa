import '../entities/entities.dart';
import '../value_objects/value_objects.dart';

/// Interface for reading DAG data (ISP - Interface Segregation Principle)
abstract interface class DagReader {
  /// Get current DAG state
  Future<DagState> getDagState();

  /// Get a specific block by hash
  Future<DagBlock?> getBlock(BlockHash hash);

  /// Get multiple blocks with pagination
  Future<List<DagBlock>> getBlocks({
    int limit = 100,
    DaaScore? fromDaaScore,
  });

  /// Get tips (leaf blocks)
  Future<List<DagBlock>> getTips();

  /// Get the sink block (selected parent of virtual)
  Future<DagBlock?> getSink();
}
