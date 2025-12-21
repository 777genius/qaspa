import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetContainerIdsUseCase {
  final LogRepository _logRepository;

  GetContainerIdsUseCase(this._logRepository);

  Future<List<String>> call() => _logRepository.getContainerIds();
}
