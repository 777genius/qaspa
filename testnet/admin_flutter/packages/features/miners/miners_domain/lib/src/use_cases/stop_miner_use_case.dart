import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class StopMinerUseCase {
  final MinerRepository _minerRepository;

  StopMinerUseCase(this._minerRepository);

  Future<void> call(String minerId) => _minerRepository.stopMiner(minerId);
}
