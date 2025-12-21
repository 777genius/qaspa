import 'package:get_it/get_it.dart';
import 'package:admin_data/admin_data.dart';
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

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core - Data layer
  configureAdminDataDependencies(getIt);

  // Dashboard feature
  configureDashboardDomainDependencies(getIt);
  configureDashboardPresentationDependencies(getIt);

  // Nodes feature
  configureNodesDomainDependencies(getIt);
  configureNodesPresentationDependencies(getIt);

  // Miners feature
  configureMinersDomainDependencies(getIt);
  configureMinersPresentationDependencies(getIt);

  // Logs feature
  configureLogsDomainDependencies(getIt);
  configureLogsPresentationDependencies(getIt);

  // DAG feature (data must come before domain for interfaces)
  configureDagDataDependencies(getIt);
  configureDagDomainDependencies(getIt);
  configureDagPresentationDependencies(getIt);
}
