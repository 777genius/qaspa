import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';

import '../module/dashboard_module.dart';
import '../stores/dashboard_store.dart';
import '../widgets/cluster_stats_grid.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = DashboardModule.init();
  }

  @override
  void dispose() {
    DashboardModule.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Initializing dashboard...');
        }

        if (snapshot.hasError) {
          return ErrorView(
            title: 'Failed to initialize',
            message: snapshot.error.toString(),
            onRetry: () {
              if (mounted) {
                setState(() {
                  _initFuture = DashboardModule.init();
                });
              }
            },
          );
        }

        return const _DashboardContent();
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
    final store = GetIt.instance<DashboardStore>();

    return Observer(
      builder: (_) {
        if (store.isLoading && !store.hasStats) {
          return const LoadingIndicator(message: 'Loading cluster stats...');
        }

        if (store.error != null && !store.hasStats) {
          return ErrorView(
            title: 'Failed to load stats',
            message: store.error,
            onRetry: store.refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: store.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cluster Overview',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AdminSpacing.lg),
                ClusterStatsGrid(store: store),
              ],
            ),
          ),
        );
      },
    );
  }
}
