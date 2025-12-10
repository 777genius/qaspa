import 'dart:io';

import 'package:modularity_cli/modularity_cli.dart';
import 'package:kaspa_wallet_mobile/src/app_module.dart';

/// Generates module dependency graph for Kaspa Wallet.
///
/// Usage:
/// ```bash
/// melos run module:graph
/// # or
/// dart run packages/tools/module_visualizer/bin/visualize.dart
/// ```
void main(List<String> args) async {
  print('Generating module dependency graph...');
  print('');

  final rootModule = AppModule();

  final isInteractive = args.contains('--interactive') || args.contains('-i');

  if (isInteractive) {
    print('Opening interactive graph viewer...');
    await GraphVisualizer.visualize(
      rootModule,
      renderer: GraphRenderer.g6,
    );
  } else {
    print('Generating static Graphviz diagram...');
    await GraphVisualizer.visualize(rootModule);
  }

  print('');
  print('Graph generated successfully!');

  if (!isInteractive) {
    print('');
    print('For interactive visualization, run with --interactive flag:');
    print('  dart run bin/visualize.dart --interactive');
  }

  exit(0);
}
