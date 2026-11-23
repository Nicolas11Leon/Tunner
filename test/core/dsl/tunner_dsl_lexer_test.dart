import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_diagnostic.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_lexer.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_token.dart';

void main() {
  group('TunnerDslLexer Tests', () {
    late TunnerDslLexer lexer;

    setUp(() {
      lexer = TunnerDslLexer();
    });

    test('tokens for keywords', () {
      const source = 'tempo channel connect set note chord rest play pause stop loop';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.map((t) => t.type), [
        TunnerDslTokenType.keywordTempo,
        TunnerDslTokenType.keywordChannel,
        TunnerDslTokenType.keywordConnect,
        TunnerDslTokenType.keywordSet,
        TunnerDslTokenType.keywordNote,
        TunnerDslTokenType.keywordChord,
        TunnerDslTokenType.keywordRest,
        TunnerDslTokenType.keywordPlay,
        TunnerDslTokenType.keywordPause,
        TunnerDslTokenType.keywordStop,
        TunnerDslTokenType.keywordLoop,
        TunnerDslTokenType.eof,
      ]);
    });

    test('tokens for punctuation and symbols', () {
      const source = '-> = . , ; [ ] { }';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.map((t) => t.type), [
        TunnerDslTokenType.arrow,
        TunnerDslTokenType.equals,
        TunnerDslTokenType.dot,
        TunnerDslTokenType.comma,
        TunnerDslTokenType.semicolon,
        TunnerDslTokenType.leftBracket,
        TunnerDslTokenType.rightBracket,
        TunnerDslTokenType.leftBrace,
        TunnerDslTokenType.rightBrace,
        TunnerDslTokenType.eof,
      ]);
    });

    test('tokens for @identifiers and routing paths', () {
      const source = '@synth.out @master.in @eq.band1';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.length, 4); // 3 @identifiers + eof
      expect(tokens[0].type, TunnerDslTokenType.atIdentifier);
      expect(tokens[0].lexeme, '@synth.out');
      expect(tokens[1].type, TunnerDslTokenType.atIdentifier);
      expect(tokens[1].lexeme, '@master.in');
      expect(tokens[2].type, TunnerDslTokenType.atIdentifier);
      expect(tokens[2].lexeme, '@eq.band1');
    });

    test('tokens for numbers, signed floats and fractions', () {
      const source = '120 -3.5 +6.0 1/4 1/8 3/16';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.length, 7); // 6 values + eof
      expect(tokens[0].type, TunnerDslTokenType.number);
      expect(tokens[0].literal, 120.0);
      expect(tokens[1].type, TunnerDslTokenType.number);
      expect(tokens[1].literal, -3.5);
      expect(tokens[2].type, TunnerDslTokenType.number);
      expect(tokens[2].literal, 6.0);
      expect(tokens[3].type, TunnerDslTokenType.fraction);
      expect(tokens[3].lexeme, '1/4');
      expect(tokens[4].type, TunnerDslTokenType.fraction);
      expect(tokens[4].lexeme, '1/8');
      expect(tokens[5].type, TunnerDslTokenType.fraction);
      expect(tokens[5].lexeme, '3/16');
    });

    test('tokens for strings with double and single quotes', () {
      const source = '"sawtooth" \'sine\'';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.length, 3);
      expect(tokens[0].type, TunnerDslTokenType.string);
      expect(tokens[0].literal, 'sawtooth');
      expect(tokens[1].type, TunnerDslTokenType.string);
      expect(tokens[1].literal, 'sine');
    });

    test('tokens for note identifiers with accidentals', () {
      const source = 'C4 A#5 Eb3 F#4 Bb2';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.length, 6);
      for (var i = 0; i < 5; i++) {
        expect(tokens[i].type, TunnerDslTokenType.identifier);
      }
      expect(tokens[0].lexeme, 'C4');
      expect(tokens[1].lexeme, 'A#5');
      expect(tokens[2].lexeme, 'Eb3');
      expect(tokens[3].lexeme, 'F#4');
      expect(tokens[4].lexeme, 'Bb2');
    });

    test('ignores comments and whitespace gracefully', () {
      const source = '''
        // Configuracion inicial
        tempo 130; // BPM base
        channel synth;
      ''';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics, isEmpty);
      expect(tokens.map((t) => t.type), [
        TunnerDslTokenType.keywordTempo,
        TunnerDslTokenType.number,
        TunnerDslTokenType.semicolon,
        TunnerDslTokenType.keywordChannel,
        TunnerDslTokenType.identifier,
        TunnerDslTokenType.semicolon,
        TunnerDslTokenType.eof,
      ]);
    });

    test('records diagnostic error for unclosed string literal', () {
      const source = 'set @synth.name = "unclosed';
      final tokens = lexer.tokenize(source);

      expect(lexer.diagnostics.length, 1);
      expect(lexer.diagnostics.first.severity, TunnerDslDiagnosticSeverity.error);
      expect(lexer.diagnostics.first.message, contains('Cadena de texto sin cerrar'));
      expect(tokens.last.type, TunnerDslTokenType.eof);
    });

    test('records diagnostic error for unrecognized characters', () {
      const source = 'tempo 120; ? %';
      lexer.tokenize(source);

      expect(lexer.diagnostics.length, 2);
      expect(lexer.diagnostics[0].message, contains("Carácter no reconocido en código fuente: '?'"));
      expect(lexer.diagnostics[1].message, contains("Carácter no reconocido en código fuente: '%'"));
    });

    test('tracks accurate line and column coordinates', () {
      const source = 'tempo\n  120;';
      final tokens = lexer.tokenize(source);

      expect(tokens[0].lexeme, 'tempo');
      expect(tokens[0].line, 1);
      expect(tokens[0].column, 1);

      expect(tokens[1].lexeme, '120');
      expect(tokens[1].line, 2);
      expect(tokens[1].column, 3);

      expect(tokens[2].lexeme, ';');
      expect(tokens[2].line, 2);
      expect(tokens[2].column, 6);
    });
  });
}
