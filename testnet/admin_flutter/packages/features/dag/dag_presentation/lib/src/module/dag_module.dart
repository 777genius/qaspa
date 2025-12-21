import 'dart:async';

import 'package:get_it/get_it.dart';

import '../stores/dag_store.dart';

/// Feature module for DAG visualization
class DagModule {
  static Completer<void>? _initCompleter;
  static bool _initialized = false;

  /// Initialize the module and its dependencies
  static Future<void> init() async {
    if (_initialized) return;

    final completer = _initCompleter;
    if (completer != null) {
      return completer.future;
    }

    _initCompleter = Completer<void>();

    try {
      // DagStore is already registered via injectable
      // Just verify it's available
      final _ = GetIt.instance<DagStore>();
      _initialized = true;
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  /// Dispose the module
  static void dispose() {
    if (!_initialized) return;

    final store = GetIt.instance<DagStore>();
    store.dispose();
    _initialized = false;
    _initCompleter = null;
  }

  /// Get the DagStore instance
  static DagStore get store => GetIt.instance<DagStore>();
}
