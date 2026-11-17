/// Resultado inmutable de la ejecución de un comando en la terminal Tunner OS.
class TunnerOsCommandResult {
  final bool isSuccess;
  final String message;
  final String? rawOutput;
  final DateTime executedAt;

  TunnerOsCommandResult({
    required this.isSuccess,
    required this.message,
    this.rawOutput,
    DateTime? executedAt,
  }) : executedAt = executedAt ?? DateTime.now();

  factory TunnerOsCommandResult.success(String message, {String? rawOutput}) {
    return TunnerOsCommandResult(
      isSuccess: true,
      message: message,
      rawOutput: rawOutput,
    );
  }

  factory TunnerOsCommandResult.error(String message, {String? rawOutput}) {
    return TunnerOsCommandResult(
      isSuccess: false,
      message: message,
      rawOutput: rawOutput,
    );
  }
}

/// Registro histórico de comando ejecutado en la terminal.
class TunnerOsCommandHistoryItem {
  final String commandLine;
  final TunnerOsCommandResult result;
  final DateTime timestamp;

  TunnerOsCommandHistoryItem({
    required this.commandLine,
    required this.result,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
