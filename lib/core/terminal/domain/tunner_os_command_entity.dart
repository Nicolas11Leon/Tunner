/// Resultado inmutable de la ejecución de un comando en la terminal Tunner OS.
class TunnerOsCommandResult {
  final bool isSuccess;
  final String message;
  final String? rawOutput;
  final Map<String, dynamic>? structuredData;
  final DateTime executedAt;

  TunnerOsCommandResult({
    required this.isSuccess,
    required this.message,
    this.rawOutput,
    this.structuredData,
    DateTime? executedAt,
  }) : executedAt = executedAt ?? DateTime.now();

  factory TunnerOsCommandResult.success(
    String message, {
    String? rawOutput,
    Map<String, dynamic>? structuredData,
  }) {
    return TunnerOsCommandResult(
      isSuccess: true,
      message: message,
      rawOutput: rawOutput,
      structuredData: structuredData,
    );
  }

  factory TunnerOsCommandResult.error(
    String message, {
    String? rawOutput,
    Map<String, dynamic>? structuredData,
  }) {
    return TunnerOsCommandResult(
      isSuccess: false,
      message: message,
      rawOutput: rawOutput,
      structuredData: structuredData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'rawOutput': rawOutput,
      'structuredData': structuredData,
      'executedAt': executedAt.toIso8601String(),
    };
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
