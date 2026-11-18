import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/tunner_ast_node.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_parser.dart';

class _AstSummaryVisitor implements TunnerAstVisitor<String, void> {
  @override
  String visitProgram(ProgramNode node, void context) {
    return node.statements.map((s) => s.accept(this, context)).join('; ');
  }

  @override
  String visitTempo(TempoStatementNode node, void context) => 'TEMPO(${node.bpm})';

  @override
  String visitChannelDecl(ChannelDeclNode node, void context) => 'CHANNEL(${node.channelName})';

  @override
  String visitConnect(ConnectStatementNode node, void context) =>
      'CONNECT(${node.source}->${node.destination})';

  @override
  String visitSetParam(SetParamStatementNode node, void context) =>
      'SET(${node.target}.${node.parameter}=${node.value}${node.unit != null ? " ${node.unit}" : ""})';

  @override
  String visitNote(NoteStatementNode node, void context) =>
      'NOTE(${node.pitch}, ${node.durationFraction})';

  @override
  String visitChord(ChordStatementNode node, void context) =>
      'CHORD([${node.pitches.join(", ")}], ${node.durationFraction})';

  @override
  String visitRest(RestStatementNode node, void context) =>
      'REST(${node.durationFraction})';

  @override
  String visitTransport(TransportStatementNode node, void context) =>
      'TRANSPORT(${node.action})';

  @override
  String visitLoop(LoopStatementNode node, void context) {
    final bodyStr = node.body.map((s) => s.accept(this, context)).join(', ');
    return 'LOOP(${node.count}: [$bodyStr])';
  }
}

void main() {
  group('TunnerDslParser Tests', () {
    late TunnerDslParser parser;

    setUp(() {
      parser = TunnerDslParser();
    });

    test('parses tempo statement', () {
      const source = 'tempo 128.5;';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 1);
      final stmt = result.program!.statements.first as TempoStatementNode;
      expect(stmt.bpm, 128.5);
    });

    test('parses channel declaration statement', () {
      const source = 'channel leadSynth;';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 1);
      final stmt = result.program!.statements.first as ChannelDeclNode;
      expect(stmt.channelName, 'leadSynth');
    });

    test('parses connect statement', () {
      const source = 'connect @synth.out -> @master.in;';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 1);
      final stmt = result.program!.statements.first as ConnectStatementNode;
      expect(stmt.source, '@synth.out');
      expect(stmt.destination, '@master.in');
    });

    test('parses set parameter statements with and without units', () {
      const source = '''
        set @master.gain = -3.0 dB;
        set @synth.waveform = "saw";
        set @delay.feedback = 0.45;
      ''';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 3);

      final stmt1 = result.program!.statements[0] as SetParamStatementNode;
      expect(stmt1.target, '@master');
      expect(stmt1.parameter, 'gain');
      expect(stmt1.value, -3.0);
      expect(stmt1.unit, 'dB');

      final stmt2 = result.program!.statements[1] as SetParamStatementNode;
      expect(stmt2.target, '@synth');
      expect(stmt2.parameter, 'waveform');
      expect(stmt2.value, 'saw');
      expect(stmt2.unit, isNull);

      final stmt3 = result.program!.statements[2] as SetParamStatementNode;
      expect(stmt3.target, '@delay');
      expect(stmt3.parameter, 'feedback');
      expect(stmt3.value, 0.45);
    });

    test('parses note, chord and rest statements', () {
      const source = '''
        note C4 1/4;
        chord [C4, E4, G4] 1/2;
        rest 1/8;
      ''';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 3);

      final note = result.program!.statements[0] as NoteStatementNode;
      expect(note.pitch, 'C4');
      expect(note.durationFraction, '1/4');

      final chord = result.program!.statements[1] as ChordStatementNode;
      expect(chord.pitches, ['C4', 'E4', 'G4']);
      expect(chord.durationFraction, '1/2');

      final rest = result.program!.statements[2] as RestStatementNode;
      expect(rest.durationFraction, '1/8');
    });

    test('parses transport statements', () {
      const source = 'play; pause; stop;';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 3);

      expect((result.program!.statements[0] as TransportStatementNode).action, 'play');
      expect((result.program!.statements[1] as TransportStatementNode).action, 'pause');
      expect((result.program!.statements[2] as TransportStatementNode).action, 'stop');
    });

    test('parses nested loop statement', () {
      const source = '''
        loop 4 {
          note C4 1/4;
          rest 1/4;
        }
      ''';
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.program?.statements.length, 1);

      final loop = result.program!.statements.first as LoopStatementNode;
      expect(loop.count, 4);
      expect(loop.body.length, 2);
      expect((loop.body[0] as NoteStatementNode).pitch, 'C4');
      expect((loop.body[1] as RestStatementNode).durationFraction, '1/4');
    });

    test('visitor executes AST traversal correctly', () {
      const source = '''
        tempo 120;
        channel synth;
        loop 2 {
          note A4 1/4;
        }
        play;
      ''';
      final result = parser.parse(source);
      expect(result.isSuccess, isTrue);

      final visitor = _AstSummaryVisitor();
      final summary = result.program!.accept(visitor, null);

      expect(
        summary,
        'TEMPO(120.0); CHANNEL(synth); LOOP(2: [NOTE(A4, 1/4)]); TRANSPORT(play)',
      );
    });

    test('recovers from syntax errors in panic mode and reports diagnostics', () {
      const source = '''
        tempo; // Error: falta numero
        channel synth; // Valido
        note; // Error: falta nota y duracion
        play; // Valido
      ''';
      final result = parser.parse(source);

      expect(result.isSuccess, isFalse);
      expect(result.diagnostics.length, greaterThanOrEqualTo(2));
      // Deberia haber rescatado channel y play
      final validStatements = result.program!.statements;
      expect(validStatements.any((s) => s is ChannelDeclNode), isTrue);
      expect(validStatements.any((s) => s is TransportStatementNode), isTrue);
    });
  });
}
