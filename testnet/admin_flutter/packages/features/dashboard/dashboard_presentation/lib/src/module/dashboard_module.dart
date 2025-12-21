import 'dart:async';

import 'package:get_it/get_it.dart';

import '../stores/dashboard_store.dart';

class DashboardModule {
  static Completer<void>? _initCompleter;
  static bool _initialized = false;

  static Future<void> init() async {
    // Thread-safe initialization using Completer
    if (_initialized) return;

    final completer = _initCompleter;
    if (completer != null) {
      // Another init is in progress, wait for it
      return completer.future;
    }

    _initCompleter = Completer<void>();

    try {
      final store = GetIt.instance<DashboardStore>();
      await store.init();
      _initialized = true;
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  static void dispose() {
    if (!_initialized) return;

    final store = GetIt.instance<DashboardStore>();
    store.dispose();
    _initialized = false;
    _initCompleter = null;
  }

  static DashboardStore get store => GetIt.instance<DashboardStore>();
}
