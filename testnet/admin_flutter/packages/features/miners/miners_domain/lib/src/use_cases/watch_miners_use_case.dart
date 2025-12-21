import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class WatchMinersUseCase {
  final MinerRepository _minerRepository;

  WatchMinersUseCase(this._minerRepository);

  Stream<List<MinerInstance>> call() => _minerRepository.watchMiners();
}
