import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_domain/admin_domain.dart';
import 'package:admin_design_system/admin_design_system.dart';
import 'package:nodes_presentation/nodes_presentation.dart';
import 'package:miners_presentation/miners_presentation.dart';

void main() {
  group('Design System Widget Tests', () {
    testWidgets('StatCard renders properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: const Scaffold(
            body: StatCard(
              title: 'Test Stat',
              value: '42',
              subtitle: 'test subtitle',
              icon: Icons.star,
            ),
          ),
        ),
      );

      expect(find.text('Test Stat'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('test subtitle'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('LoadingIndicator shows message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(message: 'Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ErrorView shows error and retry button', (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              title: 'Error Title',
              message: 'Error message',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Error Title'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('EmptyState renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Data',
              message: 'Nothing to show',
              icon: Icons.inbox,
            ),
          ),
        ),
      );

      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('Nothing to show'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('SidebarNavigation renders correctly', (tester) async {
      // Use a larger surface to avoid overflow
      await tester.binding.setSurfaceSize(const Size(800, 600));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: SidebarNavigation(
              items: const [
                SidebarItem(icon: Icons.dashboard, label: 'Dashboard'),
                SidebarItem(icon: Icons.dns, label: 'Nodes'),
                SidebarItem(icon: Icons.memory, label: 'Miners'),
              ],
              selectedIndex: 0,
              onItemSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Nodes'), findsOneWidget);
      expect(find.text('Miners'), findsOneWidget);
      expect(find.byIcon(Icons.dashboard), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('SidebarNavigation handles selection', (tester) async {
      int selectedIndex = -1;

      // Use a larger surface to avoid overflow
      await tester.binding.setSurfaceSize(const Size(800, 600));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: SidebarNavigation(
              items: const [
                SidebarItem(icon: Icons.dashboard, label: 'Dashboard'),
                SidebarItem(icon: Icons.dns, label: 'Nodes'),
              ],
              selectedIndex: 0,
              onItemSelected: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Nodes'));
      expect(selectedIndex, 1);

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('StatusBadge renders with different statuses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.fromString('running'),
                StatusBadge.fromString('stopped'),
                StatusBadge.fromString('error'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('running'), findsOneWidget);
      expect(find.text('stopped'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
    });
  });

  group('Theme Tests', () {
    testWidgets('Dark theme applies correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.brightness, Brightness.dark);
    });

    testWidgets('Light theme applies correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.light,
          home: const Scaffold(
            body: Text('Test'),
          ),
        ),
      );

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.brightness, Brightness.light);
    });
  });

  group('Domain Entity Tests', () {
    test('ClusterStats calculates nodeHealthPercent correctly', () {
      final stats = ClusterStats(
        totalNodes: 10,
        runningNodes: 8,
        syncedNodes: 5,
        totalMiners: 2,
        runningMiners: 1,
        totalBlockCount: 1000,
        virtualDaaScore: 500,
        totalPeers: 20,
        totalMempoolSize: 50,
        totalHashrate: 1500000.0,
        timestamp: DateTime.now(),
      );

      expect(stats.nodeHealthPercent, 80.0);
      expect(stats.minerHealthPercent, 50.0);
    });

    test('ClusterStats formats hashrate correctly', () {
      final lowHashrate = ClusterStats(
        totalNodes: 1,
        runningNodes: 1,
        syncedNodes: 1,
        totalMiners: 1,
        runningMiners: 1,
        totalBlockCount: 100,
        virtualDaaScore: 50,
        totalPeers: 2,
        totalMempoolSize: 5,
        totalHashrate: 1500.0,
        timestamp: DateTime.now(),
      );
      expect(lowHashrate.hashrateFormatted, '1.50 KH/s');

      final megaHashrate = lowHashrate.copyWith(totalHashrate: 1500000.0);
      expect(megaHashrate.hashrateFormatted, '1.50 MH/s');

      final gigaHashrate = lowHashrate.copyWith(totalHashrate: 1500000000.0);
      expect(gigaHashrate.hashrateFormatted, '1.50 GH/s');
    });

    test('NodeInstance isRunning works correctly', () {
      const runningNode = NodeInstance(
        id: '1',
        name: 'node-1',
        role: 'peer',
        status: 'running',
        p2pPort: 16110,
        grpcPort: 16111,
      );
      expect(runningNode.isRunning, isTrue);

      const stoppedNode = NodeInstance(
        id: '2',
        name: 'node-2',
        role: 'seed',
        status: 'stopped',
        p2pPort: 16210,
        grpcPort: 16211,
      );
      expect(stoppedNode.isRunning, isFalse);
      expect(stoppedNode.isSeed, isTrue);
    });

    test('ClusterStats.empty creates zero-filled stats', () {
      final empty = ClusterStats.empty();
      expect(empty.totalNodes, 0);
      expect(empty.runningNodes, 0);
      expect(empty.totalMiners, 0);
      expect(empty.nodeHealthPercent, 0.0);
    });
  });

  group('NodeCard Widget Tests', () {
    const testNode = NodeInstance(
      id: 'node-1',
      name: 'peer-1',
      role: 'peer',
      status: 'running',
      p2pPort: 16110,
      grpcPort: 16111,
      metrics: NodeMetrics(
        blockCount: 1000,
        headerCount: 1000,
        virtualDaaScore: 500,
        peerCount: 3,
        mempoolSize: 5,
        isSynced: true,
      ),
    );

    const stoppedNode = NodeInstance(
      id: 'node-2',
      name: 'peer-2',
      role: 'peer',
      status: 'stopped',
      p2pPort: 16210,
      grpcPort: 16211,
    );

    const seedNode = NodeInstance(
      id: 'seed-1',
      name: 'seed',
      role: 'seed',
      status: 'running',
      p2pPort: 16310,
      grpcPort: 16311,
    );

    testWidgets('NodeCard renders running node correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: NodeCard(
              node: testNode,
              onStart: () {},
              onStop: () {},
              onRestart: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Verify node name
      expect(find.text('peer-1'), findsOneWidget);
      // Verify ports
      expect(find.text('P2P: 16110 • gRPC: 16111'), findsOneWidget);
      // Verify status badge
      expect(find.text('running'), findsOneWidget);
      // Verify metrics are shown for running node
      expect(find.text('Blocks'), findsOneWidget);
      expect(find.text('1000'), findsWidgets);
      expect(find.text('Synced'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('NodeCard renders stopped node without metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: NodeCard(
              node: stoppedNode,
              onStart: () {},
              onStop: () {},
              onRestart: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Verify node name
      expect(find.text('peer-2'), findsOneWidget);
      // Verify status
      expect(find.text('stopped'), findsOneWidget);
      // Metrics should NOT be shown
      expect(find.text('Blocks'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('NodeCard shows SEED badge for seed nodes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: NodeCard(
              node: seedNode,
              onStart: () {},
              onStop: () {},
              onRestart: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(find.text('SEED'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('NodeCard popup menu works for running node', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      bool stopCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: NodeCard(
              node: testNode,
              onStart: () {},
              onStop: () => stopCalled = true,
              onRestart: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // For running node, should see Stop and Restart
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Start'), findsNothing);

      // Tap Stop
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(stopCalled, isTrue);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('NodeCard popup menu works for stopped node', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      bool startCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: NodeCard(
              node: stoppedNode,
              onStart: () => startCalled = true,
              onStop: () {},
              onRestart: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // For stopped node, should see Start
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Restart'), findsNothing);

      // Tap Start
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(startCalled, isTrue);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('MinerCard Widget Tests', () {
    const runningMiner = MinerInstance(
      id: 'miner-1',
      name: 'miner-1',
      targetNode: 'peer-1',
      status: 'running',
      hashrate: 1500000.0,
      blocksFound: 5,
    );

    const stoppedMiner = MinerInstance(
      id: 'miner-2',
      name: 'miner-2',
      targetNode: 'peer-2',
      status: 'stopped',
      hashrate: 0.0,
      blocksFound: 0,
    );

    testWidgets('MinerCard renders running miner with metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: MinerCard(
              miner: runningMiner,
              onStart: () {},
              onStop: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Verify miner name
      expect(find.text('miner-1'), findsOneWidget);
      // Verify target node
      expect(find.text('Target: peer-1'), findsOneWidget);
      // Verify status
      expect(find.text('running'), findsOneWidget);
      // Verify metrics
      expect(find.text('Hashrate'), findsOneWidget);
      expect(find.text('1.50 MH/s'), findsOneWidget);
      expect(find.text('Blocks Found'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('MinerCard renders stopped miner without metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: MinerCard(
              miner: stoppedMiner,
              onStart: () {},
              onStop: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(find.text('miner-2'), findsOneWidget);
      expect(find.text('stopped'), findsOneWidget);
      // Metrics should NOT be shown
      expect(find.text('Hashrate'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('MinerCard popup menu works', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      bool stopCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: MinerCard(
              miner: runningMiner,
              onStart: () {},
              onStop: () => stopCalled = true,
              onRemove: () {},
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // For running miner, should see Stop
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Start'), findsNothing);

      // Tap Stop
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(stopCalled, isTrue);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('MinerCard handles zero hashrate gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));

      const zeroMiner = MinerInstance(
        id: 'miner-zero',
        name: 'miner-zero',
        targetNode: 'peer-1',
        status: 'running',
        hashrate: 0.0,
        blocksFound: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: MinerCard(
              miner: zeroMiner,
              onStart: () {},
              onStop: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Should display 0.00 H/s for zero
      expect(find.text('0.00 H/s'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('AddNodeDialog Widget Tests', () {
    testWidgets('AddNodeDialog renders form correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddNodeDialog(
                      onAdd: (config) async {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog elements
      expect(find.text('Add Node'), findsOneWidget);
      expect(find.text('Node Name'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Peer'), findsOneWidget);
      expect(find.text('Seed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('AddNodeDialog validates empty name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddNodeDialog(
                      onAdd: (config) async {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Try to submit without name
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Please enter a name'), findsOneWidget);
    });

    testWidgets('AddNodeDialog submits valid data', (tester) async {
      NodeConfig? submittedConfig;

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddNodeDialog(
                      onAdd: (config) async {
                        submittedConfig = config;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter node name
      await tester.enterText(find.byType(TextFormField), 'new-peer');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify config was submitted
      expect(submittedConfig, isNotNull);
      expect(submittedConfig!.name, 'new-peer');
      expect(submittedConfig!.role, 'peer');
    });

    testWidgets('AddNodeDialog can switch role to seed', (tester) async {
      NodeConfig? submittedConfig;

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddNodeDialog(
                      onAdd: (config) async {
                        submittedConfig = config;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter name
      await tester.enterText(find.byType(TextFormField), 'new-seed');

      // Select Seed role
      await tester.tap(find.text('Seed'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(submittedConfig!.name, 'new-seed');
      expect(submittedConfig!.role, 'seed');
    });

    testWidgets('AddNodeDialog cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddNodeDialog(
                      onAdd: (config) async {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Add Node'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Add Node'), findsNothing);
    });
  });

  group('MinerInstance Entity Tests', () {
    test('MinerInstance isRunning works correctly', () {
      const running = MinerInstance(
        id: '1',
        name: 'miner-1',
        targetNode: 'peer-1',
        status: 'running',
        hashrate: 1500000.0,
        blocksFound: 5,
      );
      expect(running.isRunning, isTrue);

      const stopped = MinerInstance(
        id: '2',
        name: 'miner-2',
        targetNode: 'peer-1',
        status: 'stopped',
        hashrate: 0.0,
        blocksFound: 0,
      );
      expect(stopped.isRunning, isFalse);
    });

    test('MinerInstance hashrateFormatted works correctly', () {
      const miner = MinerInstance(
        id: '1',
        name: 'miner-1',
        targetNode: 'peer-1',
        status: 'running',
        hashrate: 1500000.0,
        blocksFound: 5,
      );
      expect(miner.hashrateFormatted, '1.50 MH/s');

      const lowMiner = MinerInstance(
        id: '2',
        name: 'miner-2',
        targetNode: 'peer-1',
        status: 'running',
        hashrate: 1500.0,
        blocksFound: 1,
      );
      expect(lowMiner.hashrateFormatted, '1.50 KH/s');
    });
  });

  group('NodeConfig Entity Tests', () {
    test('NodeConfig creates correctly', () {
      const config = NodeConfig(name: 'test-node', role: 'peer');
      expect(config.name, 'test-node');
      expect(config.role, 'peer');
    });

    test('NodeConfig toJson works', () {
      const config = NodeConfig(name: 'test', role: 'seed');
      final json = config.toJson();
      expect(json['name'], 'test');
      expect(json['role'], 'seed');
    });
  });
}
