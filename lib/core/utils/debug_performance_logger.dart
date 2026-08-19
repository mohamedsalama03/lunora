import 'package:flutter/foundation.dart';

class DebugPerformanceLogger {
  DebugPerformanceLogger._();

  static bool get enabled => kDebugMode;

  static void log(String scope, String message) {
    if (!enabled) {
      return;
    }

    debugPrint('[perf][$scope] $message');
  }

  static void logElapsed(
    String scope,
    String label,
    Stopwatch stopwatch, {
    String? extra,
  }) {
    if (!enabled) {
      return;
    }

    final buffer = StringBuffer('$label in ${stopwatch.elapsedMilliseconds}ms');
    if (extra != null && extra.trim().isNotEmpty) {
      buffer.write(' | $extra');
    }

    log(scope, buffer.toString());
  }
}
