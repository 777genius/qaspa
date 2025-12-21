import 'package:admin_domain/admin_domain.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class WatchLogsUseCase {
  final LogRepository _logRepository;

  WatchLogsUseCase(this._logRepository);

  Stream<LogEntry> call({String? containerId, LogLevel? minLevel}) =>
      _logRepository.watchLogs(containerId: containerId, minLevel: minLevel);
}
