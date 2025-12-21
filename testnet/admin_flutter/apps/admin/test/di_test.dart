import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:admin_data/admin_data.dart';
import 'package:admin_domain/admin_domain.dart';
import 'package:dashboard_domain/dashboard_domain.dart';
import 'package:dashboard_presentation/dashboard_presentation.dart';
import 'package:nodes_domain/nodes_domain.dart';
import 'package:nodes_presentation/nodes_presentation.dart';
import 'package:miners_domain/miners_domain.dart';
import 'package:miners_presentation/miners_presentation.dart';
import 'package:logs_domain/logs_domain.dart';
import 'package:logs_presentation/logs_presentation.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:dag_data/dag_data.dart';
import 'package:dag_presentation/dag_presentation.dart';

void main() {
  group('Dependency Injection Tests', () {
    late GetIt getIt;

    setUp(() {
      getIt = GetIt.instance;
      getIt.reset();
    });

    tearDown(() {
      getIt.reset();
    });

    test('All dependencies are registered correctly', () {
      // Register all dependencies in order
      configureAdminDataDependencies(getIt);
      configureDashboardDomainDependencies(getIt);
      configureDashboardPresentationDependencies(getIt);
      configureNodesDomainDependencies(getIt);
      configureNodesPresentationDependencies(getIt);
      configureMinersDomainDependencies(getIt);
      configureMinersPresentationDependencies(getIt);
      configureLogsDomainDependencies(getIt);
      configureLogsPresentationDependencies(getIt);

      // Verify core repositories are registered
      expect(getIt.isRegistered<ClusterRepository>(), isTrue);
      expect(getIt.isRegistered<NodeRepository>(), isTrue);
      expect(getIt.isRegistered<MinerRepository>(), isTrue);
      expect(getIt.isRegistered<LogRepository>(), isTrue);

      // Verify dashboard dependencies
      expect(getIt.isRegistered<GetClusterStatsUseCase>(), isTrue);
      expect(getIt.isRegistered<WatchClusterStatsUseCase>(), isTrue);
      expect(getIt.isRegistered<DashboardStore>(), isTrue);

      // Verify nodes dependencies
      expect(getIt.isRegistered<GetNodesUseCase>(), isTrue);
      expect(getIt.isRegistered<NodesStore>(), isTrue);

      // Verify miners dependencies
      expect(getIt.isRegistered<GetMinersUseCase>(), isTrue);
      expect(getIt.isRegistered<MinersStore>(), isTrue);

      // Verify logs dependencies
      expect(getIt.isRegistered<WatchLogsUseCase>(), isTrue);
      expect(getIt.isRegistered<LogsStore>(), isTrue);
    });

    test('DashboardStore can be resolved with dependencies', () {
      configureAdminDataDependencies(getIt);
      configureDashboardDomainDependencies(getIt);
      configureDashboardPresentationDependencies(getIt);

      final store = getIt<DashboardStore>();
      expect(store, isNotNull);
    });

    test('NodesStore can be resolved with dependencies', () {
      configureAdminDataDependencies(getIt);
      configureNodesDomainDependencies(getIt);
      configureNodesPresentationDependencies(getIt);

      final store = getIt<NodesStore>();
      expect(store, isNotNull);
    });

    test('MinersStore can be resolved with dependencies', () {
      configureAdminDataDependencies(getIt);
      configureMinersDomainDependencies(getIt);
      configureMinersPresentationDependencies(getIt);

      final store = getIt<MinersStore>();
      expect(store, isNotNull);
    });

    test('LogsStore can be resolved with dependencies', () {
      configureAdminDataDependencies(getIt);
      configureLogsDomainDependencies(getIt);
      configureLogsPresentationDependencies(getIt);

      final store = getIt<LogsStore>();
      expect(store, isNotNull);
    });

    test('DagStore can be resolved with dependencies', () {
      // DAG depends on nodes_domain for GetNodesUseCase
      configureAdminDataDependencies(getIt);
      configureNodesDomainDependencies(getIt);
      configureDagDataDependencies(getIt);
      configureDagDomainDependencies(getIt);
      configureDagPresentationDependencies(getIt);

      // Verify DAG use cases are registered
      expect(getIt.isRegistered<GetDagStateUseCase>(), isTrue);
      expect(getIt.isRegistered<WatchDagUpdatesUseCase>(), isTrue);
      expect(getIt.isRegistered<ConnectToNodeUseCase>(), isTrue);

      // Verify DagStore can be resolved
      final store = getIt<DagStore>();
      expect(store, isNotNull);
    });
  });
}
