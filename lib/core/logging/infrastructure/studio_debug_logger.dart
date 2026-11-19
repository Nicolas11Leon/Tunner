import 'package:flutter/foundation.dart';

import '../domain/i_studio_logger.dart';

/// Default infrastructure implementation of [IStudioLogger] backed by [debugPrint].
class StudioDebugLogger implements IStudioLogger {
  const StudioDebugLogger();

  /// Shared default logger instance for zero-allocation callsites.
  static const StudioDebugLogger instance = StudioDebugLogger();

  @override
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[WARN][$tag] $message${error != null ? ' | error: $error' : ''}');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  @override
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[ERROR][$tag] $message${error != null ? ' | error: $error' : ''}');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }
}
