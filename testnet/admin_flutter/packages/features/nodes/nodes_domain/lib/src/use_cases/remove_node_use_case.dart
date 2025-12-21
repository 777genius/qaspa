import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RemoveNodeUseCase {
  final NodeRepository _nodeRepository;

  RemoveNodeUseCase(this._nodeRepository);

  Future<void> call(String nodeId) => _nodeRepository.removeNode(nodeId);
}
