import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/data/abc_score_parser.dart';
import 'package:tunner/features/universal_importer/data/midi_score_parser.dart';
import 'package:tunner/features/universal_importer/data/musicxml_score_parser.dart';
import 'package:tunner/features/universal_importer/domain/canonical_abc_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_midi_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_musicxml_exporter.dart';

void main() {
  group('US-4.2 MusicXML Polifonico, Compases Arbitrarios y Rango 0..8', () {
    const parser = MusicXmlScoreParser();
    const exporter = CanonicalMusicXmlExporter();

    test('Preserva <chord/> con el startTick de la nota base inclusive en el ultimo tiempo', () async {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><rest/><duration>8</duration><type>half</type></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
    </measure>
  </part>
</score-partwise>''';

      final result = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(xml)),
        fileName: 'chords.musicxml',
      );
      final measure = result.package.score.measures.first;

      expect(measure.isValidMeasure, isTrue);
      expect(result.totalNotes, equals(6));

      final tick0Notes = measure.notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(tick0Notes.map((n) => n.noteName).toList(), equals(['Do4', 'Mi4', 'Sol4']));
      expect(tick0Notes.every((n) => n.durationTicks == 4), isTrue);

      final tick12Notes = measure.notes.where((n) => !n.isRest && n.startTick == 12).toList();
      expect(tick12Notes.map((n) => n.noteName).toList(), equals(['Re4', 'Fa#4', 'La4']));
      expect(tick12Notes.every((n) => n.durationTicks == 4), isTrue);
    });

    test('Soporta compases arbitrarios (5/4, 7/8, 9/8, 12/8, 2/2, 5/16) y rango 0..8 en round-trip', () async {
      final score = HierarchicalScore(
        title: 'Metros Arbitrarios y Rango Extremo',
        baseBpm: 112,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: const TimeSignature(5, 4),
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Do0'),
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Mi0'),
              HierarchicalNote.note(startTick: 8, durationTicks: 12, noteName: 'Sol4'),
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: const TimeSignature(7, 8),
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do8'),
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Si8'),
              HierarchicalNote.note(startTick: 4, durationTicks: 6, noteName: 'La0'),
              HierarchicalNote.rest(startTick: 10, durationTicks: 4),
            ],
          ),
          MeasureEntity(
            index: 2,
            timeSignature: const TimeSignature(9, 8),
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 6, noteName: 'Fa#4'),
              HierarchicalNote.note(startTick: 6, durationTicks: 6, noteName: 'La4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 6, noteName: 'Do#5'),
            ],
          ),
          MeasureEntity(
            index: 3,
            timeSignature: const TimeSignature(12, 8),
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 24, noteName: 'Do4'),
            ],
          ),
          MeasureEntity(
            index: 4,
            timeSignature: const TimeSignature(2, 2),
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'Sol4'),
            ],
          ),
          MeasureEntity(
            index: 5,
            timeSignature: const TimeSignature(5, 16),
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 5, noteName: 'La4'),
            ],
          ),
        ],
      );

      final exportedXml = exporter.exportScore(score: score, title: score.title);
      expect(exportedXml, contains('<chord/>'));
      expect(exportedXml, contains('<beats>5</beats>'));
      expect(exportedXml, contains('<beats>7</beats>'));
      expect(exportedXml, contains('<beat-type>8</beat-type>'));
      expect(exportedXml, contains('<beats>9</beats>'));
      expect(exportedXml, contains('<beats>12</beats>'));
      expect(exportedXml, contains('<beats>2</beats>'));
      expect(exportedXml, contains('<beat-type>2</beat-type>'));
      expect(exportedXml, contains('<beat-type>16</beat-type>'));
      expect(exportedXml, contains('<octave>0</octave>'));
      expect(exportedXml, contains('<octave>8</octave>'));

      final reparsed = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(exportedXml)),
        fileName: 'roundtrip.musicxml',
      );

      final measures = reparsed.package.score.measures;
      expect(measures.length, equals(6));
      expect(measures[0].timeSignature, equals(const TimeSignature(5, 4)));
      expect(measures[1].timeSignature, equals(const TimeSignature(7, 8)));
      expect(measures[2].timeSignature, equals(const TimeSignature(9, 8)));
      expect(measures[3].timeSignature, equals(const TimeSignature(12, 8)));
      expect(measures[4].timeSignature, equals(const TimeSignature(2, 2)));
      expect(measures[5].timeSignature, equals(const TimeSignature(5, 16)));
      expect(measures.every((m) => m.isValidMeasure), isTrue);

      final m0Tick0 = measures[0].notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(m0Tick0.map((n) => n.noteName).toList(), equals(['Do0', 'Mi0']));

      final m1Tick0 = measures[1].notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(m1Tick0.map((n) => n.noteName).toList(), equals(['Do8', 'Si8']));
      expect(measures[1].notes.firstWhere((n) => n.startTick == 4).noteName, equals('La0'));
    });
  });

  group('US-4.2 MIDI Polifonico en _quantizeToMeasures', () {
    const parser = MidiScoreParser();
    const exporter = CanonicalMidiExporter();

    test('Agrupa eventos MIDI simultaneos por startTick y preserva silencios intermedios', () async {
      final score = HierarchicalScore(
        title: 'MIDI Polifonico',
        baseBpm: 100,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: const TimeSignature(7, 8), // 14 ticks
            notes: [
              // Acorde C mayor en octava 0/4 en tick 0 (negra = 4 ticks)
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do0'),
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Sol4'),
              // Silencio intermedio en ticks 4..8 (4 ticks)
              HierarchicalNote.rest(startTick: 4, durationTicks: 4),
              // Acorde en tick 8 hasta tick 12 con octava 8 incluida
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Do4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Do8'),
              // Silencio final ticks 12..14 (2 ticks)
              HierarchicalNote.rest(startTick: 12, durationTicks: 2),
            ],
          ),
        ],
      );

      final midiBytes = exporter.exportScore(score: score, bpm: 100, trackName: 'PolyMidi');
      final parsed = await parser.parseScoreData(bytes: midiBytes, fileName: 'poly.mid');

      final measure = parsed.package.score.measures.first;
      expect(measure.timeSignature, equals(const TimeSignature(7, 8)));
      expect(measure.isValidMeasure, isTrue);

      final tick0Chord = measure.notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(tick0Chord.length, equals(3));
      expect(tick0Chord.map((n) => n.noteName).toList(), equals(['Do0', 'Mi4', 'Sol4']));
      expect(tick0Chord.every((n) => n.durationTicks == 4), isTrue);

      final midRest = measure.notes.firstWhere((n) => n.isRest && n.startTick == 4);
      expect(midRest.durationTicks, equals(4));

      final tick8Chord = measure.notes.where((n) => !n.isRest && n.startTick == 8).toList();
      expect(tick8Chord.length, equals(2));
      expect(tick8Chord.map((n) => n.noteName).toList(), equals(['Do4', 'Do8']));
      expect(tick8Chord.every((n) => n.durationTicks == 4), isTrue);

      final endRest = measure.notes.firstWhere((n) => n.isRest && n.startTick == 12);
      expect(endRest.durationTicks, equals(2));
    });

    test('No inserta silencio intermedio cuando otra voz del acorde sigue sonando', () async {
      final score = HierarchicalScore(
        title: 'Contrapunto MIDI',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              // Bajo sostenido 8 ticks + voz superior de 4 ticks en tick 0, otra nota en tick 4
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'La0'),
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Fa#4'),
              HierarchicalNote.rest(startTick: 8, durationTicks: 8),
            ],
          ),
        ],
      );

      final midiBytes = exporter.exportScore(score: score, bpm: 120);
      final parsed = await parser.parseScoreData(bytes: midiBytes, fileName: 'counterpoint.mid');
      final measure = parsed.package.score.measures.first;

      expect(measure.isValidMeasure, isTrue);
      expect(measure.notes.where((n) => n.isRest && n.startTick < 8), isEmpty);
      expect(
        measure.notes.where((n) => !n.isRest && n.startTick == 0).map((n) => n.noteName).toList(),
        equals(['La0', 'Mi4']),
      );
      expect(
        measure.notes.firstWhere((n) => !n.isRest && n.startTick == 4).noteName,
        equals('Fa#4'),
      );
    });
  });

  group('US-4.2 ABC Polifonico [CEG], 15 Armaduras, Compases Arbitrarios y Rango 0..8', () {
    const parser = AbcScoreParser();
    const exporter = CanonicalAbcExporter();

    test('Soporta M: C|, M: (3+2)/8, duraciones mixtas en acordes y subdivisiones con /2', () async {
      const abcCutAndOdd = '''X: 1
T: Metros Especiales ABC
M: C|
L: 1/4
K: F
[CEG]/2 [FAc]/2 [B,DF]3 | [M:(3+2)/8] [C2E] ^F/2 |]''';

      final res = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(abcCutAndOdd)),
        fileName: 'special_meters.abc',
      );

      final measures = res.package.score.measures;
      expect(measures.length, equals(2));
      expect(measures[0].timeSignature, equals(const TimeSignature(2, 2)));
      expect(measures[1].timeSignature, equals(const TimeSignature(5, 8)));
      expect(measures.every((m) => m.isValidMeasure), isTrue);

      final m0Tick0 = measures[0].notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(m0Tick0.map((n) => n.noteName).toList(), equals(['Do4', 'Mi4', 'Sol4']));
      expect(m0Tick0.every((n) => n.durationTicks == 2), isTrue);

      final m0Tick2 = measures[0].notes.where((n) => !n.isRest && n.startTick == 2).toList();
      expect(m0Tick2.map((n) => n.noteName).toList(), equals(['Fa4', 'La4', 'Do5']));
      expect(m0Tick2.every((n) => n.durationTicks == 2), isTrue);

      // En K: F, B natural pasa a Sib3 en [B,DF]3
      final m0Tick4 = measures[0].notes.where((n) => !n.isRest && n.startTick == 4).toList();
      expect(m0Tick4.map((n) => n.noteName).toList(), equals(['Sib3', 'Re4', 'Fa4']));
      expect(m0Tick4.every((n) => n.durationTicks == 12), isTrue);

      // Compas 5/8 = 10 ticks: [C2E] (Do4=8 ticks, Mi4=4 ticks) + ^F/2 (Fa#4=2 ticks en startTick=8)
      final m1Tick0 = measures[1].notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(m1Tick0[0].noteName, equals('Do4'));
      expect(m1Tick0[0].durationTicks, equals(8));
      expect(m1Tick0[1].noteName, equals('Mi4'));
      expect(m1Tick0[1].durationTicks, equals(4));

      final m1Tick8 = measures[1].notes.firstWhere((n) => !n.isRest && n.startTick == 8);
      expect(m1Tick8.noteName, equals('Fa#4'));
      expect(m1Tick8.durationTicks, equals(2));
    });

    test('Round-trip completo ABC con acordes [CEG], compas 5/4, cambio a 7/8 y rango C0..C8', () async {
      const cleanAbc = "X: 1\n"
          "T: Polifonia ABC\n"
          "C: Estudio 4.2\n"
          "M: 5/4\n"
          "L: 1/4\n"
          "Q: 1/4=108\n"
          "K: C\n"
          "[C,,,,E,,,,G,,,,] [CEG]2 z [c'''e'''g'''] |\n"
          "[M:7/8] [DFA] [FAc] G/2 A/2 B/2 |]";

      final parsed = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(cleanAbc)),
        fileName: 'poly_range.abc',
      );

      final measures = parsed.package.score.measures;
      expect(measures.length, equals(2));
      expect(measures[0].timeSignature, equals(const TimeSignature(5, 4)));
      expect(measures[1].timeSignature, equals(const TimeSignature(7, 8)));
      expect(measures.every((m) => m.isValidMeasure), isTrue);

      final m0Tick0 = measures[0].notes.where((n) => !n.isRest && n.startTick == 0).toList();
      expect(m0Tick0.map((n) => n.noteName).toList(), equals(['Do0', 'Mi0', 'Sol0']));
      expect(m0Tick0.every((n) => n.durationTicks == 4), isTrue);

      final m0Tick4 = measures[0].notes.where((n) => !n.isRest && n.startTick == 4).toList();
      expect(m0Tick4.map((n) => n.noteName).toList(), equals(['Do4', 'Mi4', 'Sol4']));
      expect(m0Tick4.every((n) => n.durationTicks == 8), isTrue);

      expect(measures[0].notes.firstWhere((n) => n.startTick == 12).isRest, isTrue);

      final m0Tick16 = measures[0].notes.where((n) => !n.isRest && n.startTick == 16).toList();
      expect(m0Tick16.map((n) => n.noteName).toList(), equals(['Do8', 'Mi8', 'Sol8']));

      final exported = exporter.exportScore(
        score: parsed.package.score,
        title: parsed.package.title,
        composer: parsed.package.composer,
      );

      expect(exported, contains('M: 5/4'));
      expect(exported, contains('[C,,,,E,,,,G,,,,]'));
      expect(exported, contains('[CEG]2'));
      expect(exported, contains("[c'''e'''g''']"));
      expect(exported, contains('[M:7/8]'));

      final reparsed = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(exported)),
        fileName: 'reimport.abc',
      );
      expect(reparsed.package.score.measures.length, equals(2));
      expect(reparsed.package.score.measures[0].timeSignature, equals(const TimeSignature(5, 4)));
      expect(reparsed.package.score.measures[1].timeSignature, equals(const TimeSignature(7, 8)));
      expect(
        reparsed.package.score.measures[0].notes
            .where((n) => !n.isRest && n.startTick == 0)
            .map((n) => n.noteName)
            .toList(),
        equals(['Do0', 'Mi0', 'Sol0']),
      );
      expect(
        reparsed.package.score.measures[0].notes
            .where((n) => !n.isRest && n.startTick == 16)
            .map((n) => n.noteName)
            .toList(),
        equals(['Do8', 'Mi8', 'Sol8']),
      );
    });

    test('Soporta las 15 armaduras estandar (-7 a +7) en mayores y relativas menores', () async {
      final expectedKeyChecks = <String, List<String>>{
        'C': ['Do4', 'Re4', 'Mi4', 'Fa4', 'Sol4', 'La4', 'Si4'],
        'G': ['Do4', 'Re4', 'Mi4', 'Fa#4', 'Sol4', 'La4', 'Si4'],
        'D': ['Do#4', 'Re4', 'Mi4', 'Fa#4', 'Sol4', 'La4', 'Si4'],
        'A': ['Do#4', 'Re4', 'Mi4', 'Fa#4', 'Sol#4', 'La4', 'Si4'],
        'E': ['Do#4', 'Re#4', 'Mi4', 'Fa#4', 'Sol#4', 'La4', 'Si4'],
        'B': ['Do#4', 'Re#4', 'Mi4', 'Fa#4', 'Sol#4', 'La#4', 'Si4'],
        'F#': ['Do#4', 'Re#4', 'Mi#4', 'Fa#4', 'Sol#4', 'La#4', 'Si4'],
        'C#': ['Do#4', 'Re#4', 'Mi#4', 'Fa#4', 'Sol#4', 'La#4', 'Si#4'],
        'F': ['Do4', 'Re4', 'Mi4', 'Fa4', 'Sol4', 'La4', 'Sib4'],
        'Bb': ['Do4', 'Re4', 'Mib4', 'Fa4', 'Sol4', 'La4', 'Sib4'],
        'Eb': ['Do4', 'Re4', 'Mib4', 'Fa4', 'Sol4', 'Lab4', 'Sib4'],
        'Ab': ['Do4', 'Reb4', 'Mib4', 'Fa4', 'Sol4', 'Lab4', 'Sib4'],
        'Db': ['Do4', 'Reb4', 'Mib4', 'Fa4', 'Solb4', 'Lab4', 'Sib4'],
        'Gb': ['Dob4', 'Reb4', 'Mib4', 'Fa4', 'Solb4', 'Lab4', 'Sib4'],
        'Cb': ['Dob4', 'Reb4', 'Mib4', 'Fab4', 'Solb4', 'Lab4', 'Sib4'],
        'Am': ['Do4', 'Re4', 'Mi4', 'Fa4', 'Sol4', 'La4', 'Si4'],
        'D#m': ['Do#4', 'Re#4', 'Mi#4', 'Fa#4', 'Sol#4', 'La#4', 'Si4'],
        'A#m': ['Do#4', 'Re#4', 'Mi#4', 'Fa#4', 'Sol#4', 'La#4', 'Si#4'],
        'Ebm': ['Dob4', 'Reb4', 'Mib4', 'Fa4', 'Solb4', 'Lab4', 'Sib4'],
        'Abm': ['Dob4', 'Reb4', 'Mib4', 'Fab4', 'Solb4', 'Lab4', 'Sib4'],
        'C minor': ['Do4', 'Re4', 'Mib4', 'Fa4', 'Sol4', 'Lab4', 'Sib4'],
      };

      for (final entry in expectedKeyChecks.entries) {
        final abc = '''X: 1
T: Key ${entry.key}
M: 7/4
L: 1/4
K: ${entry.key}
C D E F G A B |]''';

        final res = await parser.parseScoreData(
          bytes: Uint8List.fromList(utf8.encode(abc)),
          fileName: 'key_${entry.key}.abc',
        );
        final measure = res.package.score.measures.first;
        expect(measure.timeSignature, equals(const TimeSignature(7, 4)));
        expect(
          measure.notes.map((n) => n.noteName).toList(),
          equals(entry.value),
          reason: 'Armadura fallida para K: ${entry.key}',
        );
      }
    });
  });
}
