import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetNodesUseCase {
  final NodeRepository _nodeRepository;

  GetNodesUseCase(this._nodeRepository);

  Future<List<NodeInstance>> call() => _nodeRepository.getNodes();
}
