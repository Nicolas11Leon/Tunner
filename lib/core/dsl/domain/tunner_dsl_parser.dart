import 'tunner_ast_node.dart';
import 'tunner_dsl_diagnostic.dart';
import 'tunner_dsl_lexer.dart';
import 'tunner_dsl_token.dart';

/// Resultado inmutable del análisis sintáctico de un script Tunner DSL.
class TunnerDslParseResult {
  /// Árbol de Sintaxis Abstracta generado. `null` si hubo errores fatales de análisis.
  final ProgramNode? program;

  /// Lista de diagnósticos de error y advertencias emitidos durante el análisis.
  final List<TunnerDslDiagnostic> diagnostics;

  const TunnerDslParseResult({
    this.program,
    required this.diagnostics,
  });

  /// Indica si el análisis sintáctico fue 100% exitoso sin errores.
  bool get isSuccess => diagnostics.isEmpty && program != null;
}

/// Analizador sintáctico descendente recursivo (Recursive Descent Parser)
/// para el lenguaje declarativo Tunner DSL.
///
/// Convierte un flujo de tokens en una jerarquía inmutable de `TunnerAstNode`,
/// con recuperación ante errores en modo pánico para recopilar múltiples
/// diagnósticos didácticos en una sola pasada.
class TunnerDslParser {
  final List<TunnerDslDiagnostic> _diagnostics = [];
  final List<TunnerDslToken> _tokens = [];
  int _current = 0;

  /// Analiza directamente una cadena de código fuente.
  TunnerDslParseResult parse(String sourceCode) {
    final lexer = TunnerDslLexer();
    final tokens = lexer.tokenize(sourceCode);
    final initialDiagnostics = List<TunnerDslDiagnostic>.from(lexer.diagnostics);

    final parseResult = parseTokens(tokens);
    return TunnerDslParseResult(
      program: parseResult.program,
      diagnostics: [...initialDiagnostics, ...parseResult.diagnostics],
    );
  }

  /// Analiza una lista de tokens ya escaneados.
  TunnerDslParseResult parseTokens(List<TunnerDslToken> tokens) {
    _tokens.clear();
    _tokens.addAll(tokens);
    _diagnostics.clear();
    _current = 0;

    final statements = <TunnerStatementNode>[];

    while (!_isAtEnd()) {
      try {
        final stmt = _parseStatement();
        if (stmt != null) {
          statements.add(stmt);
        }
      } catch (e) {
        _synchronize();
      }
    }

    return TunnerDslParseResult(
      program: ProgramNode(statements),
      diagnostics: List.unmodifiable(_diagnostics),
    );
  }

  TunnerStatementNode? _parseStatement() {
    final token = _peek();

    switch (token.type) {
      case TunnerDslTokenType.keywordTempo:
        return _parseTempoStatement();
      case TunnerDslTokenType.keywordChannel:
        return _parseChannelStatement();
      case TunnerDslTokenType.keywordConnect:
        return _parseConnectStatement();
      case TunnerDslTokenType.keywordSet:
        return _parseSetStatement();
      case TunnerDslTokenType.keywordNote:
        return _parseNoteStatement();
      case TunnerDslTokenType.keywordChord:
        return _parseChordStatement();
      case TunnerDslTokenType.keywordRest:
        return _parseRestStatement();
      case TunnerDslTokenType.keywordPlay:
      case TunnerDslTokenType.keywordPause:
      case TunnerDslTokenType.keywordStop:
        return _parseTransportStatement();
      case TunnerDslTokenType.keywordLoop:
        return _parseLoopStatement();
      case TunnerDslTokenType.semicolon:
        _advance(); // Sentencia vacía redundante (e.g. ';;')
        return null;
      default:
        _error(token, 'Instrucción no válida o palabra clave esperada.');
        _advance();
        return null;
    }
  }

  /// Parsea: `tempo <bpm>;`
  TunnerStatementNode _parseTempoStatement() {
    _consume(TunnerDslTokenType.keywordTempo, "Se esperaba 'tempo'.");
    final numToken = _consume(TunnerDslTokenType.number, 'Se esperaba el valor numérico de BPM después de tempo.');
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la sentencia tempo.");

    final bpm = (numToken.literal is num) ? (numToken.literal as num).toDouble() : 120.0;
    return TempoStatementNode(bpm);
  }

  /// Parsea: `channel <nombre>;`
  TunnerStatementNode _parseChannelStatement() {
    _consume(TunnerDslTokenType.keywordChannel, "Se esperaba 'channel'.");
    final idToken = _consume(TunnerDslTokenType.identifier, 'Se esperaba el nombre del canal.');
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la declaración de canal.");
    return ChannelDeclNode(idToken.lexeme);
  }

  /// Parsea: `connect @source -> @destination;`
  TunnerStatementNode _parseConnectStatement() {
    _consume(TunnerDslTokenType.keywordConnect, "Se esperaba 'connect'.");
    final sourceToken = _consume(TunnerDslTokenType.atIdentifier, "Se esperaba el nodo de origen (ej. '@synth.out').");
    _consume(TunnerDslTokenType.arrow, "Se esperaba el operador de conexión '->'.");
    final destToken = _consume(TunnerDslTokenType.atIdentifier, "Se esperaba el nodo de destino (ej. '@master.in').");
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la sentencia connect.");

    return ConnectStatementNode(
      source: sourceToken.lexeme,
      destination: destToken.lexeme,
    );
  }

  /// Parsea: `set @target.param = <valor> [unidad];`
  TunnerStatementNode _parseSetStatement() {
    _consume(TunnerDslTokenType.keywordSet, "Se esperaba 'set'.");
    final atToken = _consume(TunnerDslTokenType.atIdentifier, "Se esperaba el identificador del dispositivo (ej. '@master').");

    String target;
    String parameter;

    if (_match(TunnerDslTokenType.dot)) {
      final paramToken = _consume(TunnerDslTokenType.identifier, 'Se esperaba el nombre del parámetro tras el punto.');
      target = atToken.lexeme;
      parameter = paramToken.lexeme;
    } else {
      // El identificador @ ya puede contener un punto (ej. '@master.gain')
      final dotIndex = atToken.lexeme.indexOf('.');
      if (dotIndex != -1) {
        target = atToken.lexeme.substring(0, dotIndex);
        parameter = atToken.lexeme.substring(dotIndex + 1);
      } else {
        target = atToken.lexeme;
        parameter = '';
      }
    }

    _consume(TunnerDslTokenType.equals, "Se esperaba '=' para asignar el valor.");

    dynamic value;
    final valToken = _advance();
    if (valToken.type == TunnerDslTokenType.number) {
      value = valToken.literal;
    } else if (valToken.type == TunnerDslTokenType.string) {
      value = valToken.literal;
    } else if (valToken.type == TunnerDslTokenType.identifier) {
      value = valToken.lexeme;
    } else {
      _error(valToken, 'Valor asignado no válido en sentencia set.');
      value = valToken.lexeme;
    }

    // Unidad opcional (ej. 'dB', 'ms', 's', 'Hz', 'BPM')
    String? unit;
    if (_peek().type == TunnerDslTokenType.identifier) {
      unit = _advance().lexeme;
    }

    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la sentencia set.");

    return SetParamStatementNode(
      target: target,
      parameter: parameter,
      value: value,
      unit: unit,
    );
  }

  /// Parsea: `note <pitch> <fraction>;`
  TunnerStatementNode _parseNoteStatement() {
    _consume(TunnerDslTokenType.keywordNote, "Se esperaba 'note'.");
    final pitchToken = _consume(TunnerDslTokenType.identifier, "Se esperaba la nota tonal (ej. 'C4', 'A#4', 'Eb5').");
    final durToken = _advance();
    if (durToken.type != TunnerDslTokenType.fraction && durToken.type != TunnerDslTokenType.number) {
      _error(durToken, "Se esperaba la fracción de duración (ej. '1/4', '1/8').");
    }
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la sentencia note.");

    return NoteStatementNode(
      pitch: pitchToken.lexeme,
      durationFraction: durToken.lexeme,
    );
  }

  /// Parsea: `chord [<pitch>, <pitch>, ...] <fraction>;`
  TunnerStatementNode _parseChordStatement() {
    _consume(TunnerDslTokenType.keywordChord, "Se esperaba 'chord'.");
    _consume(TunnerDslTokenType.leftBracket, "Se esperaba '[' para iniciar la lista de notas del acorde.");

    final pitches = <String>[];
    if (!_check(TunnerDslTokenType.rightBracket)) {
      do {
        final p = _consume(TunnerDslTokenType.identifier, 'Se esperaba una nota dentro del acorde.');
        pitches.add(p.lexeme);
      } while (_match(TunnerDslTokenType.comma));
    }

    _consume(TunnerDslTokenType.rightBracket, "Se esperaba ']' para cerrar la lista de notas.");

    final durToken = _advance();
    if (durToken.type != TunnerDslTokenType.fraction && durToken.type != TunnerDslTokenType.number) {
      _error(durToken, "Se esperaba la fracción de duración tras el acorde.");
    }
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la sentencia chord.");

    return ChordStatementNode(
      pitches: pitches,
      durationFraction: durToken.lexeme,
    );
  }

  /// Parsea: `rest <fraction>;`
  TunnerStatementNode _parseRestStatement() {
    _consume(TunnerDslTokenType.keywordRest, "Se esperaba 'rest'.");
    final durToken = _advance();
    if (durToken.type != TunnerDslTokenType.fraction && durToken.type != TunnerDslTokenType.number) {
      _error(durToken, "Se esperaba la fracción de duración del silencio.");
    }
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' al final de la sentencia rest.");

    return RestStatementNode(durToken.lexeme);
  }

  /// Parsea: `play;`, `pause;`, `stop;`
  TunnerStatementNode _parseTransportStatement() {
    final token = _advance();
    _consume(TunnerDslTokenType.semicolon, "Se esperaba ';' tras la orden de transporte.");
    return TransportStatementNode(token.lexeme.toLowerCase());
  }

  /// Parsea: `loop <count> { <statements> }`
  TunnerStatementNode _parseLoopStatement() {
    _consume(TunnerDslTokenType.keywordLoop, "Se esperaba 'loop'.");
    final countToken = _consume(TunnerDslTokenType.number, 'Se esperaba el número de repeticiones del bucle.');
    _consume(TunnerDslTokenType.leftBrace, "Se esperaba '{' para iniciar el bloque del bucle.");

    final count = (countToken.literal is num) ? (countToken.literal as num).toInt() : 1;
    final body = <TunnerStatementNode>[];

    while (!_check(TunnerDslTokenType.rightBrace) && !_isAtEnd()) {
      final stmt = _parseStatement();
      if (stmt != null) {
        body.add(stmt);
      }
    }

    _consume(TunnerDslTokenType.rightBrace, "Se esperaba '}' para cerrar el bloque del bucle.");
    return LoopStatementNode(count: count, body: body);
  }

  // Métodos auxiliares de parsing
  bool _match(TunnerDslTokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _check(TunnerDslTokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  TunnerDslToken _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() => _peek().type == TunnerDslTokenType.eof;

  TunnerDslToken _peek() => _tokens[_current];

  TunnerDslToken _previous() => _tokens[_current - 1];

  TunnerDslToken _consume(TunnerDslTokenType type, String message) {
    if (_check(type)) return _advance();
    _error(_peek(), message);
    throw FormatException(message);
  }

  void _error(TunnerDslToken token, String message) {
    _diagnostics.add(TunnerDslDiagnostic.error(
      message,
      line: token.line,
      column: token.column,
    ));
  }

  /// Sincronización en modo pánico para recuperar el analizador tras un error de sintaxis
  void _synchronize() {
    _advance();
    while (!_isAtEnd()) {
      if (_previous().type == TunnerDslTokenType.semicolon) return;
      if (_previous().type == TunnerDslTokenType.rightBrace) return;

      switch (_peek().type) {
        case TunnerDslTokenType.keywordChannel:
        case TunnerDslTokenType.keywordConnect:
        case TunnerDslTokenType.keywordSet:
        case TunnerDslTokenType.keywordNote:
        case TunnerDslTokenType.keywordChord:
        case TunnerDslTokenType.keywordRest:
        case TunnerDslTokenType.keywordTempo:
        case TunnerDslTokenType.keywordPlay:
        case TunnerDslTokenType.keywordPause:
        case TunnerDslTokenType.keywordStop:
        case TunnerDslTokenType.keywordLoop:
          return;
        default:
          _advance();
      }
    }
  }
}
