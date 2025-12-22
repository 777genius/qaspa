import '../entities/cluster.dart';
import '../entities/cluster_stats.dart';
import '../value_objects/network_info.dart';

/// Repository interface for cluster operations
abstract interface class ClusterRepository {
  /// Get current cluster state
  Future<Cluster> getCluster();

  /// Get network information (type, address prefix, default address)
  Future<NetworkInfo> getNetworkInfo();

  /// Get cluster statistics
  Future<ClusterStats> getStats();

  /// Watch cluster statistics updates
  Stream<ClusterStats> watchStats();

  /// Start the cluster
  Future<void> startCluster();

  /// Stop the cluster
  Future<void> stopCluster();
}
