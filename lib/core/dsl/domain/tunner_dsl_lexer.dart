import 'tunner_dsl_diagnostic.dart';
import 'tunner_dsl_token.dart';

/// Analizador léxico (Lexer / Tokenizer) de alto rendimiento para Tunner DSL.
///
/// Escanea el código fuente en un solo pase de complejidad lineal $O(N)$,
/// identificando palabras clave, operadores, identificadores con prefijo `@`,
/// literales numéricos, fracciones métricas y cadenas de texto.
class TunnerDslLexer {
  /// Lista de diagnósticos de error acumulados durante la tokenización.
  final List<TunnerDslDiagnostic> diagnostics = [];

  static const Map<String, TunnerDslTokenType> _keywords = {
    'channel': TunnerDslTokenType.keywordChannel,
    'connect': TunnerDslTokenType.keywordConnect,
    'set': TunnerDslTokenType.keywordSet,
    'note': TunnerDslTokenType.keywordNote,
    'chord': TunnerDslTokenType.keywordChord,
    'rest': TunnerDslTokenType.keywordRest,
    'tempo': TunnerDslTokenType.keywordTempo,
    'play': TunnerDslTokenType.keywordPlay,
    'pause': TunnerDslTokenType.keywordPause,
    'stop': TunnerDslTokenType.keywordStop,
    'loop': TunnerDslTokenType.keywordLoop,
  };

  /// Convierte una cadena de texto en código fuente a una lista ordenada de tokens.
  List<TunnerDslToken> tokenize(String source) {
    diagnostics.clear();
    final tokens = <TunnerDslToken>[];

    var index = 0;
    var line = 1;
    var column = 1;

    while (index < source.length) {
      final c = source[index];

      // 1. Manejo de espacios en blanco y saltos de línea
      if (c == ' ' || c == '\t' || c == '\r') {
        index++;
        column++;
        continue;
      }
      if (c == '\n') {
        index++;
        line++;
        column = 1;
        continue;
      }

      // 2. Comentarios de línea (// ...)
      if (c == '/' && index + 1 < source.length && source[index + 1] == '/') {
        while (index < source.length && source[index] != '\n') {
          index++;
        }
        continue;
      }

      final startColumn = column;

      // 3. Operador flecha '->'
      if (c == '-' && index + 1 < source.length && source[index + 1] == '>') {
        tokens.add(TunnerDslToken(
          type: TunnerDslTokenType.arrow,
          lexeme: '->',
          line: line,
          column: startColumn,
        ));
        index += 2;
        column += 2;
        continue;
      }

      // 4. Símbolos de puntuación de un solo carácter
      switch (c) {
        case '=':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.equals, lexeme: '=', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case ';':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.semicolon, lexeme: ';', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case ',':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.comma, lexeme: ',', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case '.':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.dot, lexeme: '.', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case '[':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.leftBracket, lexeme: '[', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case ']':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.rightBracket, lexeme: ']', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case '{':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.leftBrace, lexeme: '{', line: line, column: startColumn));
          index++;
          column++;
          continue;
        case '}':
          tokens.add(TunnerDslToken(type: TunnerDslTokenType.rightBrace, lexeme: '}', line: line, column: startColumn));
          index++;
          column++;
          continue;
      }

      // 5. Identificadores que inician con '@' (e.g. '@synth.out', '@master.gain')
      if (c == '@') {
        final start = index;
        index++;
        column++;
        while (index < source.length && _isAtIdentifierChar(source[index])) {
          index++;
          column++;
        }
        final lexeme = source.substring(start, index);
        tokens.add(TunnerDslToken(
          type: TunnerDslTokenType.atIdentifier,
          lexeme: lexeme,
          line: line,
          column: startColumn,
        ));
        continue;
      }

      // 6. Cadenas de texto entre comillas dobles o simples
      if (c == '"' || c == "'") {
        final quoteChar = c;
        final start = index;
        index++;
        column++;
        final sb = StringBuffer();
        var closed = false;

        while (index < source.length) {
          final cur = source[index];
          if (cur == quoteChar) {
            index++;
            column++;
            closed = true;
            break;
          }
          if (cur == '\n') {
            line++;
            column = 1;
          } else {
            column++;
          }
          sb.write(cur);
          index++;
        }

        if (!closed) {
          diagnostics.add(TunnerDslDiagnostic.error(
            'Cadena de texto sin cerrar al final del archivo.',
            line: line,
            column: startColumn,
          ));
        } else {
          final lexeme = source.substring(start, index);
          tokens.add(TunnerDslToken(
            type: TunnerDslTokenType.string,
            lexeme: lexeme,
            literal: sb.toString(),
            line: line,
            column: startColumn,
          ));
        }
        continue;
      }

      // 7. Números con o sin signo y fracciones métricas (e.g. '120', '-3.5', '+4.0', '1/4', '1/8')
      if (_isDigit(c) || ((c == '-' || c == '+') && index + 1 < source.length && _isDigit(source[index + 1]))) {
        final start = index;
        var hasDecimal = false;

        if (c == '-' || c == '+') {
          index++;
          column++;
        }

        while (index < source.length && _isDigit(source[index])) {
          index++;
          column++;
        }

        if (index < source.length && source[index] == '.' && index + 1 < source.length && _isDigit(source[index + 1])) {
          hasDecimal = true;
          index++;
          column++;
          while (index < source.length && _isDigit(source[index])) {
            index++;
            column++;
          }
        }

        // Comprobar si se trata de una fracción métrica (e.g. '1/4', '1/8', '3/4')
        if (!hasDecimal && index < source.length && source[index] == '/' && index + 1 < source.length && _isDigit(source[index + 1])) {
          index++; // consumir '/'
          column++;
          while (index < source.length && _isDigit(source[index])) {
            index++;
            column++;
          }
          final lexeme = source.substring(start, index);
          tokens.add(TunnerDslToken(
            type: TunnerDslTokenType.fraction,
            lexeme: lexeme,
            literal: lexeme,
            line: line,
            column: startColumn,
          ));
          continue;
        }

        // Si después del número sigue inmediatamente una unidad (e.g. 'dB', 'ms', 's', 'Hz', 'BPM')
        final lexeme = source.substring(start, index);
        final numVal = double.tryParse(lexeme) ?? 0.0;
        tokens.add(TunnerDslToken(
          type: TunnerDslTokenType.number,
          lexeme: lexeme,
          literal: numVal,
          line: line,
          column: startColumn,
        ));
        continue;
      }

      // 8. Identificadores regulares y palabras clave (e.g. 'channel', 'note', 'C4', 'A#5')
      if (_isAlpha(c)) {
        final start = index;
        while (index < source.length && _isAlphaNumeric(source[index])) {
          index++;
          column++;
        }
        final lexeme = source.substring(start, index);
        final lower = lexeme.toLowerCase();
        final kwType = _keywords[lower];

        if (kwType != null) {
          tokens.add(TunnerDslToken(
            type: kwType,
            lexeme: lexeme,
            line: line,
            column: startColumn,
          ));
        } else {
          tokens.add(TunnerDslToken(
            type: TunnerDslTokenType.identifier,
            lexeme: lexeme,
            literal: lexeme,
            line: line,
            column: startColumn,
          ));
        }
        continue;
      }

      // 9. Carácter no reconocido
      diagnostics.add(TunnerDslDiagnostic.error(
        "Carácter no reconocido en código fuente: '$c'",
        line: line,
        column: startColumn,
      ));
      index++;
      column++;
    }

    tokens.add(TunnerDslToken(
      type: TunnerDslTokenType.eof,
      lexeme: '',
      line: line,
      column: column,
    ));

    return tokens;
  }

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  bool _isAlpha(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        char == '_';
  }

  bool _isAlphaNumeric(String char) => _isAlpha(char) || _isDigit(char) || char == '#' || char == 'b';

  bool _isAtIdentifierChar(String char) => _isAlpha(char) || _isDigit(char) || char == '.' || char == '_';
}
