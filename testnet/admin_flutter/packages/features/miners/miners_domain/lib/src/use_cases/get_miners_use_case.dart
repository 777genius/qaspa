import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetMinersUseCase {
  final MinerRepository _minerRepository;

  GetMinersUseCase(this._minerRepository);

  Future<List<MinerInstance>> call() => _minerRepository.getMiners();
}
