import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/data/musicxml_score_parser.dart';

void main() {
  group('MusicXmlScoreParser Tests', () {
    const parser = MusicXmlScoreParser();

    test('canParse identifies .musicxml, .xml and XML byte signatures', () {
      expect(parser.canParse('song.musicxml', Uint8List(0)), isTrue);
      expect(parser.canParse('score.xml', Uint8List(0)), isTrue);
      expect(parser.canParse('song.mid', Uint8List(0)), isFalse);

      final xmlBytes = Uint8List.fromList(utf8.encode('<?xml version="1.0"?><score-partwise/>'));
      expect(parser.canParse('unknown_file', xmlBytes), isTrue);
    });

    test('Parses valid MusicXML into HierarchicalScore with notes and rests', () async {
      const xmlString = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Minuet de Prueba</work-title></work>
  <identification><creator type="composer">J. S. Bach</creator></identification>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <sound tempo="108"/>
      <!-- Negra Do4 (duración 4) -->
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <!-- Negra Mi4 (duración 4) -->
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <!-- Silencio de negra (duración 4) -->
      <note>
        <rest/>
        <duration>4</duration>
      </note>
      <!-- Negra Sol4 (duración 4) -->
      <note>
        <pitch><step>G</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final bytes = Uint8List.fromList(utf8.encode(xmlString));
      final result = await parser.parseScoreData(bytes: bytes, fileName: 'minuet.musicxml');

      expect(result.format, equals('MusicXML'));
      expect(result.package.title, equals('Minuet de Prueba'));
      expect(result.package.composer, equals('J. S. Bach'));
      expect(result.package.defaultBpm, equals(108));
      expect(result.totalMeasures, equals(1));
      expect(result.totalNotes, equals(3)); // 3 notas con pitch (el silencio no suma a totalNotes)

      final measure = result.package.score.measures.first;
      expect(measure.timeSignature, equals(TimeSignature.commonTime44));
      expect(measure.notes.length, equals(4));

      // Verificar Nota 1: Do4 (negra, startTick 0, duration 4)
      expect(measure.notes[0].noteName, equals('Do4'));
      expect(measure.notes[0].startTick, equals(0));
      expect(measure.notes[0].durationTicks, equals(4));
      expect(measure.notes[0].isRest, isFalse);

      // Verificar Nota 2: Mi4 (negra, startTick 4, duration 4)
      expect(measure.notes[1].noteName, equals('Mi4'));
      expect(measure.notes[1].startTick, equals(4));
      expect(measure.notes[1].durationTicks, equals(4));

      // Verificar Nota 3: Silencio (startTick 8, duration 4)
      expect(measure.notes[2].isRest, isTrue);
      expect(measure.notes[2].startTick, equals(8));
      expect(measure.notes[2].durationTicks, equals(4));

      // Verificar Nota 4: Sol4 (negra, startTick 12, duration 4)
      expect(measure.notes[3].noteName, equals('Sol4'));
      expect(measure.notes[3].startTick, equals(12));
      expect(measure.notes[3].durationTicks, equals(4));
    });

    test('Parses accidentals (sharps and flats) correctly', () async {
      const xmlString = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <!-- Fa#5 con alter = 1 -->
      <note>
        <pitch><step>F</step><alter>1</alter><octave>5</octave></pitch>
        <duration>8</duration>
      </note>
      <!-- Re#4 con alter = 1 -->
      <note>
        <pitch><step>D</step><alter>1</alter><octave>4</octave></pitch>
        <duration>8</duration>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final bytes = Uint8List.fromList(utf8.encode(xmlString));
      final result = await parser.parseScoreData(bytes: bytes, fileName: 'accidentals.xml');

      final measure = result.package.score.measures.first;
      expect(measure.notes[0].noteName, equals('Fa#5'));
      expect(measure.notes[0].durationTicks, equals(8));
      expect(measure.notes[1].noteName, equals('Re#4'));
      expect(measure.notes[1].durationTicks, equals(8));
    });

    test('Autofills incomplete measures with padding rests', () async {
      const xmlString = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <!-- Solo 1 negra (4 ticks) en un compás de 16 ticks -->
      <note>
        <pitch><step>A</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final bytes = Uint8List.fromList(utf8.encode(xmlString));
      final result = await parser.parseScoreData(bytes: bytes, fileName: 'incomplete.xml');

      final measure = result.package.score.measures.first;
      expect(measure.notes.length, equals(2));
      expect(measure.notes[0].noteName, equals('La4'));
      expect(measure.notes[0].durationTicks, equals(4));

      // Silencio de relleno por los 12 ticks restantes
      expect(measure.notes[1].isRest, isTrue);
      expect(measure.notes[1].startTick, equals(4));
      expect(measure.notes[1].durationTicks, equals(12));
    });
  });
}
