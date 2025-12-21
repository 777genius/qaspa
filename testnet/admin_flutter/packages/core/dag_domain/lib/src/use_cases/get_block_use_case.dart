import 'package:injectable/injectable.dart';

import '../entities/entities.dart';
import '../repositories/dag_reader.dart';
import '../value_objects/value_objects.dart';

/// Use Case: Get a specific block by hash
@lazySingleton
class GetBlockUseCase {
  final DagReader _reader;

  GetBlockUseCase(this._reader);

  Future<DagBlock?> call(BlockHash hash) => _reader.getBlock(hash);
}
