import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class StopNodeUseCase {
  final NodeRepository _nodeRepository;

  StopNodeUseCase(this._nodeRepository);

  Future<void> call(String nodeId) => _nodeRepository.stopNode(nodeId);
}
