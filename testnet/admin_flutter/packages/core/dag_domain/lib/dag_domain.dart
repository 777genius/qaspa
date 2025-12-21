/// DAG Domain Layer
///
/// Pure domain layer containing:
/// - Entities (DagBlock, DagState, VirtualChainChanged)
/// - Value Objects (BlockHash, DaaScore, BlueScore, BlueWork)
/// - Repository Interfaces (DagRepository, DagReader, DagWatcher, DagConnectionManager)
/// - Use Cases (GetDagState, GetBlock, WatchDagUpdates, ConnectToNode)
/// - Exceptions (DagException hierarchy)
library dag_domain;

// Value Objects
export 'src/value_objects/block_hash.dart';
export 'src/value_objects/blue_score.dart';
export 'src/value_objects/blue_work.dart';
export 'src/value_objects/daa_score.dart';

// Entities
export 'src/entities/dag_block.dart';
export 'src/entities/dag_state.dart';
export 'src/entities/virtual_chain_changed.dart';

// Repository Interfaces
export 'src/repositories/dag_connection.dart';
export 'src/repositories/dag_reader.dart';
export 'src/repositories/dag_repository.dart';
export 'src/repositories/dag_watcher.dart';

// Use Cases
export 'src/use_cases/connect_to_node_use_case.dart';
export 'src/use_cases/get_block_use_case.dart';
export 'src/use_cases/get_dag_state_use_case.dart';
export 'src/use_cases/watch_dag_updates_use_case.dart';

// Errors
export 'src/errors/dag_exception.dart';

// DI
export 'di/dag_domain_injectable.dart';
