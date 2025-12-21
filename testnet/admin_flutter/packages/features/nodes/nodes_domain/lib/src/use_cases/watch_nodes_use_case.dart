import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class WatchNodesUseCase {
  final NodeRepository _nodeRepository;

  WatchNodesUseCase(this._nodeRepository);

  Stream<List<NodeInstance>> call() => _nodeRepository.watchNodes();
}
