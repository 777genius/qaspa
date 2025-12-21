import '../entities/miner_instance.dart';
import '../value_objects/miner_config.dart';

/// Repository interface for miner operations
abstract interface class MinerRepository {
  /// Get all miners
  Future<List<MinerInstance>> getMiners();

  /// Get a single miner by ID
  Future<MinerInstance> getMiner(String minerId);

  /// Watch miners for updates
  Stream<List<MinerInstance>> watchMiners();

  /// Add a new miner
  Future<MinerInstance> addMiner(MinerConfig config);

  /// Remove a miner
  Future<void> removeMiner(String minerId);

  /// Start a miner
  Future<void> startMiner(String minerId);

  /// Stop a miner
  Future<void> stopMiner(String minerId);
}
