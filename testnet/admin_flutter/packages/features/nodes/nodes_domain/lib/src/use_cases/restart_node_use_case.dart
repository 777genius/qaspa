import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RestartNodeUseCase {
  final NodeRepository _nodeRepository;

  RestartNodeUseCase(this._nodeRepository);

  Future<void> call(String nodeId) => _nodeRepository.restartNode(nodeId);
}
