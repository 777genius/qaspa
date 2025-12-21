import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AddNodeUseCase {
  final NodeRepository _nodeRepository;

  AddNodeUseCase(this._nodeRepository);

  Future<NodeInstance> call(NodeConfig config) => _nodeRepository.addNode(config);
}
