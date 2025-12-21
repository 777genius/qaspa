import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetClusterStatsUseCase {
  final ClusterRepository _clusterRepository;

  GetClusterStatsUseCase(this._clusterRepository);

  Future<ClusterStats> call() => _clusterRepository.getStats();
}
