import 'dart:io';

import '../domain/i_studio_logger.dart';

/// Pure Dart implementation of [IStudioLogger] that writes strictly to [stderr].
///
/// Designed for CLI and MCP `stdio` server execution where `stdout` is exclusively
/// reserved for JSON-RPC 2.0 protocol frames and must never receive diagnostic output.
class StudioStderrLogger implements IStudioLogger {
  final bool includeStackTrace;

  const StudioStderrLogger({this.includeStackTrace = false});

  /// Shared default stderr logger instance for zero-allocation callsites.
  static const StudioStderrLogger instance = StudioStderrLogger();

  @override
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    stderr.writeln(
      '[WARN][$tag] $message${error != null ? ' | error: $error' : ''}',
    );
    if (includeStackTrace && stackTrace != null) {
      stderr.writeln(stackTrace.toString());
    }
  }

  @override
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    stderr.writeln(
      '[ERROR][$tag] $message${error != null ? ' | error: $error' : ''}',
    );
    if (includeStackTrace && stackTrace != null) {
      stderr.writeln(stackTrace.toString());
    }
  }
}
