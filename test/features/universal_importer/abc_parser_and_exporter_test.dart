import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/universal_importer/data/abc_score_parser.dart';
import 'package:tunner/features/universal_importer/domain/canonical_abc_exporter.dart';

void main() {
  group('ABC Notation Parser & Exporter Tests', () {
    const parser = AbcScoreParser();
    const exporter = CanonicalAbcExporter();

    const sampleAbc = '''X: 1
T: Himno a la Alegria
C: Ludwig van Beethoven
M: 4/4
L: 1/4
Q: 1/4=120
K: C
E E F G | G F E D | C C D E | E3/2 D/2 D2 |]''';

    test('canParse identifies .abc extension and ABC header lines', () {
      expect(parser.canParse('song.abc', Uint8List(0)), isTrue);
      expect(parser.canParse('song.ABC', Uint8List(0)), isTrue);
      expect(parser.canParse('text.txt', Uint8List.fromList(utf8.encode('X: 1\nT: Test\nK: C'))), isTrue);
      expect(parser.canParse('other.bin', Uint8List.fromList([1, 2, 3])), isFalse);
    });

    test('parseScoreData decodes headers, measures, notes and durations', () async {
      final bytes = Uint8List.fromList(utf8.encode(sampleAbc));
      final result = await parser.parseScoreData(bytes: bytes, fileName: 'joy.abc');

      expect(result.package.title, equals('Himno a la Alegria'));
      expect(result.package.composer, equals('Ludwig van Beethoven'));
      expect(result.package.defaultBpm, equals(120));
      expect(result.totalMeasures, equals(4));

      // First measure: E E F G (4 quarter notes = 4 ticks each)
      final m1 = result.package.score.measures[0];
      expect(m1.notes.length, equals(4));
      expect(m1.notes[0].noteName, equals('Mi4'));
      expect(m1.notes[0].durationTicks, equals(4));
      expect(m1.notes[3].noteName, equals('Sol4'));

      // Measure 4 has duration fractions: E3/2 D/2 D2
      final m4 = result.package.score.measures[3];
      expect(m4.notes.length, equals(3));
      expect(m4.notes[0].noteName, equals('Mi4'));
      expect(m4.notes[0].durationTicks, equals(6));
      expect(m4.notes[1].noteName, equals('Re4'));
      expect(m4.notes[1].durationTicks, equals(2));
      expect(m4.notes[2].noteName, equals('Re4'));
      expect(m4.notes[2].durationTicks, equals(8));
    });

    test('CanonicalAbcExporter exports HierarchicalScore to formatted ABC text', () async {
      final bytes = Uint8List.fromList(utf8.encode(sampleAbc));
      final result = await parser.parseScoreData(bytes: bytes, fileName: 'joy.abc');

      final exportedAbc = exporter.exportScore(
        score: result.package.score,
        title: result.package.title,
        composer: result.package.composer,
      );

      expect(exportedAbc, contains('X: 1'));
      expect(exportedAbc, contains('T: Himno a la Alegria'));
      expect(exportedAbc, contains('C: Ludwig van Beethoven'));
      expect(exportedAbc, contains('M: 4/4'));
      expect(exportedAbc, contains('Q: 1/4=120'));
      expect(exportedAbc, contains('E'));
      expect(exportedAbc, contains('|]'));
    });

    test('Parser handles rests and accidentals correctly', () async {
      const abcWithRests = '''X: 2
T: Prueba Silencios
M: 4/4
L: 1/4
K: C
^C _B =F z2 |]''';

      final bytes = Uint8List.fromList(utf8.encode(abcWithRests));
      final result = await parser.parseScoreData(bytes: bytes, fileName: 'rests.abc');

      final notes = result.package.score.measures[0].notes;
      expect(notes.length, equals(4));
      // ^C (C#4)
      expect(notes[0].noteName, equals('Do#4'));
      // _B (Bb4)
      expect(notes[1].noteName, equals('Sib4'));
      // =F (F4)
      expect(notes[2].noteName, equals('Fa4'));
      // z2 (half rest = 8 ticks)
      expect(notes[3].isRest, isTrue);
      expect(notes[3].durationTicks, equals(8));
    });
  });
}
