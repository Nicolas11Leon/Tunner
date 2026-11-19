/// Pure Dart domain port for structured diagnostic logging across Tunner.
abstract class IStudioLogger {
  /// Logs a non-fatal warning or recoverable error with optional stack trace.
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });

  /// Logs a critical failure in audio hardware, DSP, or persistence I/O.
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}
