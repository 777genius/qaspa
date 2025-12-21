import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RemoveMinerUseCase {
  final MinerRepository _minerRepository;

  RemoveMinerUseCase(this._minerRepository);

  Future<void> call(String minerId) => _minerRepository.removeMiner(minerId);
}
