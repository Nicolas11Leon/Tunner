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

/// Implementación silenciosa en dominio puro para pruebas y fallbacks desacoplados.
class NoOpStudioLogger implements IStudioLogger {
  const NoOpStudioLogger();

  @override
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
