import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class StartNodeUseCase {
  final NodeRepository _nodeRepository;

  StartNodeUseCase(this._nodeRepository);

  Future<void> call(String nodeId) => _nodeRepository.startNode(nodeId);
}
