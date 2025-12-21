import 'dart:async';

import 'package:get_it/get_it.dart';

import '../stores/logs_store.dart';

class LogsModule {
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
      final store = GetIt.instance<LogsStore>();
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

    final store = GetIt.instance<LogsStore>();
    store.dispose();
    _initialized = false;
    _initCompleter = null;
  }

  static LogsStore get store => GetIt.instance<LogsStore>();
}
