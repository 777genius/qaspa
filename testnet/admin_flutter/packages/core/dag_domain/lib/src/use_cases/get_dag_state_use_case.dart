import 'package:injectable/injectable.dart';

import '../entities/entities.dart';
import '../repositories/dag_reader.dart';

/// Use Case: Get current DAG state
@lazySingleton
class GetDagStateUseCase {
  final DagReader _reader;

  GetDagStateUseCase(this._reader);

  Future<DagState> call() => _reader.getDagState();
}
