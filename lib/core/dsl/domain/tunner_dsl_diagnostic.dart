/// Severidad del diagnóstico emitido durante el análisis léxico o sintáctico.
enum TunnerDslDiagnosticSeverity {
  error,
  warning,
  info,
}

/// Diagnóstico pedagógico y de depuración emitido por el compilador de Tunner DSL.
///
/// Informa la ubicación exacta en el código fuente (línea y columna) junto
/// con un mensaje claro y libre de tecnicismos para orientar al usuario.
class TunnerDslDiagnostic {
  /// Mensaje explicativo del error o sugerencia.
  final String message;

  /// Número de línea del error (base 1).
  final int line;

  /// Número de columna del error (base 1).
  final int column;

  /// Nivel de gravedad del diagnóstico.
  final TunnerDslDiagnosticSeverity severity;

  /// Constructor inmutable canónico.
  const TunnerDslDiagnostic({
    required this.message,
    required this.line,
    required this.column,
    this.severity = TunnerDslDiagnosticSeverity.error,
  });

  /// Crea un diagnóstico de nivel de error.
  factory TunnerDslDiagnostic.error(String message, {required int line, required int column}) {
    return TunnerDslDiagnostic(
      message: message,
      line: line,
      column: column,
      severity: TunnerDslDiagnosticSeverity.error,
    );
  }

  /// Crea un diagnóstico de nivel de advertencia.
  factory TunnerDslDiagnostic.warning(String message, {required int line, required int column}) {
    return TunnerDslDiagnostic(
      message: message,
      line: line,
      column: column,
      severity: TunnerDslDiagnosticSeverity.warning,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'line': line,
      'column': column,
      'severity': severity.name,
    };
  }

  factory TunnerDslDiagnostic.fromJson(Map<String, dynamic> json) {
    final severityName = json['severity'] as String? ?? TunnerDslDiagnosticSeverity.error.name;
    final parsedSeverity = TunnerDslDiagnosticSeverity.values.firstWhere(
      (s) => s.name == severityName,
      orElse: () => TunnerDslDiagnosticSeverity.error,
    );
    return TunnerDslDiagnostic(
      message: json['message'] as String? ?? '',
      line: (json['line'] as num?)?.toInt() ?? 1,
      column: (json['column'] as num?)?.toInt() ?? 1,
      severity: parsedSeverity,
    );
  }

  @override
  String toString() => '[$severity] L:$line C:$column: $message';
}
