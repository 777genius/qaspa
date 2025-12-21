import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class StartMinerUseCase {
  final MinerRepository _minerRepository;

  StartMinerUseCase(this._minerRepository);

  Future<void> call(String minerId) => _minerRepository.startMiner(minerId);
}
