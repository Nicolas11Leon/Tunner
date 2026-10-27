import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/universal_importer/data/midi_score_parser.dart';

void main() {
  group('MidiScoreParser Binary Tests', () {
    const parser = MidiScoreParser();

    Uint8List createMidiBytes({
      required int ppq,
      required int tempoMicroseconds,
      required List<int> events,
    }) {
      final header = [
        0x4D, 0x54, 0x68, 0x64, // MThd
        0x00, 0x00, 0x00, 0x06, // length 6
        0x00, 0x00,             // format 0
        0x00, 0x01,             // 1 track
        (ppq >> 8) & 0xFF,
        ppq & 0xFF,
      ];

      // Meta Set Tempo: FF 51 03 [3 bytes]
      final tempoMeta = [
        0x00, 0xFF, 0x51, 0x03,
        (tempoMicroseconds >> 16) & 0xFF,
        (tempoMicroseconds >> 8) & 0xFF,
        tempoMicroseconds & 0xFF,
      ];

      final trackData = [...tempoMeta, ...events, 0x00, 0xFF, 0x2F, 0x00];
      final trackLen = trackData.length;

      final trackHeader = [
        0x4D, 0x54, 0x72, 0x6B, // MTrk
        (trackLen >> 24) & 0xFF,
        (trackLen >> 16) & 0xFF,
        (trackLen >> 8) & 0xFF,
        trackLen & 0xFF,
      ];

      return Uint8List.fromList([...header, ...trackHeader, ...trackData]);
    }

    test('canParse identifies .mid, .midi and MThd byte signatures', () {
      expect(parser.canParse('song.mid', Uint8List(0)), isTrue);
      expect(parser.canParse('song.midi', Uint8List(0)), isTrue);
      expect(parser.canParse('song.musicxml', Uint8List(0)), isFalse);

      final signature = Uint8List.fromList([0x4D, 0x54, 0x68, 0x64, 0x00, 0x00]);
      expect(parser.canParse('unknown', signature), isTrue);
    });

    test('Parses MIDI binary file and extracts tempo, notes and measures', () async {
      // 500,000 microsegundos por negra = 120 BPM
      // Evento: NoteOn Do4 (60), duración 480 ticks (1 negra), seguido de NoteOff
      final events = [
        // Delta 0, NoteOn Ch 0, Pitch 60, Vel 80
        0x00, 0x90, 0x3C, 0x50,
        // Delta 480 (0x83, 0x60 en VLQ), NoteOff Ch 0, Pitch 60, Vel 0
        0x83, 0x60, 0x80, 0x3C, 0x00,
        // Delta 0, NoteOn Ch 0, Pitch 69 (La4), Vel 80
        0x00, 0x90, 0x45, 0x50,
        // Delta 480, NoteOff Ch 0, Pitch 69, Vel 0
        0x83, 0x60, 0x80, 0x45, 0x00,
      ];

      final bytes = createMidiBytes(
        ppq: 480,
        tempoMicroseconds: 500000, // 120 BPM
        events: events,
      );

      final result = await parser.parseScoreData(bytes: bytes, fileName: 'bach_invention.mid');

      expect(result.format, equals('MIDI'));
      expect(result.package.title, equals('bach_invention'));
      expect(result.package.defaultBpm, equals(120));
      expect(result.totalMeasures, greaterThanOrEqualTo(1));
      expect(result.totalNotes, equals(2));

      final firstMeasure = result.package.score.measures.first;
      expect(firstMeasure.notes.isNotEmpty, isTrue);

      // Nota 1: Do4 (negra, 4 ticks)
      expect(firstMeasure.notes[0].noteName, equals('Do4'));
      expect(firstMeasure.notes[0].startTick, equals(0));
      expect(firstMeasure.notes[0].durationTicks, equals(4));

      // Nota 2: La4 (negra, 4 ticks)
      expect(firstMeasure.notes[1].noteName, equals('La4'));
      expect(firstMeasure.notes[1].startTick, equals(4));
      expect(firstMeasure.notes[1].durationTicks, equals(4));

      // Relleno de compás con silencio de 8 ticks (blanca)
      expect(firstMeasure.notes[2].isRest, isTrue);
      expect(firstMeasure.notes[2].startTick, equals(8));
      expect(firstMeasure.notes[2].durationTicks, equals(8));
    });

    test('Throws FormatException on invalid MIDI binary data', () async {
      final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(
        () => parser.parseScoreData(bytes: invalidBytes, fileName: 'bad.mid'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
