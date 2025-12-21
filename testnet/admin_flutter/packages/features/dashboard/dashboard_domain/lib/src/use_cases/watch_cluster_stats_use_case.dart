import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class WatchClusterStatsUseCase {
  final ClusterRepository _clusterRepository;

  WatchClusterStatsUseCase(this._clusterRepository);

  Stream<ClusterStats> call() => _clusterRepository.watchStats();
}
