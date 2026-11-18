/// Tipos de tokens léxicos admitidos por la gramática de Tunner DSL.
enum TunnerDslTokenType {
  // Palabras clave de declaración y transporte
  keywordChannel,
  keywordConnect,
  keywordSet,
  keywordNote,
  keywordChord,
  keywordRest,
  keywordTempo,
  keywordPlay,
  keywordPause,
  keywordStop,
  keywordLoop,

  // Literales e Identificadores
  identifier,
  atIdentifier, // Identificadores que inician con '@' (e.g. '@synth.out', '@master.gain')
  number,
  string,
  fraction, // Fracción rítmica canónica (e.g. '1/4', '1/8', '1/2', '4/4')

  // Símbolos y Operadores
  arrow, // '->'
  equals, // '='
  dot, // '.'
  comma, // ','
  semicolon, // ';'
  leftBracket, // '['
  rightBracket, // ']'
  leftBrace, // '{'
  rightBrace, // '}'

  // Control de flujo léxico
  eof,
}

/// Token inmutable que encapsula un lexema identificado en el código fuente de Tunner DSL,
/// junto con su tipo gramatical y sus coordenadas espaciales (línea y columna).
class TunnerDslToken {
  /// Tipo de token léxico.
  final TunnerDslTokenType type;

  /// Texto literal exacto tal como apareció en el código fuente.
  final String lexeme;

  /// Valor evaluado del literal (e.g. `double` para números, `String` para cadenas).
  final dynamic literal;

  /// Número de línea en el archivo fuente (base 1).
  final int line;

  /// Número de columna en la línea (base 1).
  final int column;

  /// Constructor inmutable canónico.
  const TunnerDslToken({
    required this.type,
    required this.lexeme,
    this.literal,
    required this.line,
    required this.column,
  });

  @override
  String toString() => 'Token($type, "$lexeme", l:$line, c:$column)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TunnerDslToken &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          lexeme == other.lexeme &&
          literal == other.literal &&
          line == other.line &&
          column == other.column;

  @override
  int get hashCode =>
      type.hashCode ^
      lexeme.hashCode ^
      literal.hashCode ^
      line.hashCode ^
      column.hashCode;
}
