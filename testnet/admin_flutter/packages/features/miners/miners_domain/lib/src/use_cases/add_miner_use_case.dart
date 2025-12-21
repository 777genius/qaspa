import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AddMinerUseCase {
  final MinerRepository _minerRepository;

  AddMinerUseCase(this._minerRepository);

  Future<MinerInstance> call(MinerConfig config) =>
      _minerRepository.addMiner(config);
}
