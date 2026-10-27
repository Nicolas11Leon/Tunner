import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/domain/canonical_midi_exporter.dart';

void main() {
  group('CanonicalMidiExporter Domain Tests', () {
    const exporter = CanonicalMidiExporter();

    test('Encodes Variable Length Quantity (VLQ) correctly', () {
      expect(CanonicalMidiExporter.encodeVlq(0), [0x00]);
      expect(CanonicalMidiExporter.encodeVlq(127), [0x7F]);
      expect(CanonicalMidiExporter.encodeVlq(128), [0x81, 0x00]);
      expect(CanonicalMidiExporter.encodeVlq(480), [0x83, 0x60]);
      expect(CanonicalMidiExporter.encodeVlq(16383), [0xFF, 0x7F]);
      expect(CanonicalMidiExporter.encodeVlq(16384), [0x81, 0x80, 0x00]);
    });

    test('Maps note names to standard MIDI numbers correctly', () {
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Do4'), 60); // C4
      expect(CanonicalMidiExporter.noteNameToMidiPitch('C4'), 60);
      expect(CanonicalMidiExporter.noteNameToMidiPitch('La4'), 69); // A4 = 440 Hz
      expect(CanonicalMidiExporter.noteNameToMidiPitch('A4'), 69);
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Do5'), 72); // C5
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Fa#5'), 78); // F#5
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Sib3'), 58); // Bb3
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Mi2'), 40); // E2 (guitar 6th string)
    });

    test('Generates canonical SMF Format 0 file with valid MThd and MTrk headers', () {
      final score = HierarchicalScore(
        title: 'Canon Midi Test',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Sol4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'Do5'),
            ],
          ),
        ],
      );

      final bytes = exporter.exportScore(score: score, bpm: 120, trackName: 'Test Track');

      // Check MThd Magic
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'MThd');
      // Format 0 (single track)
      expect(bytes[8], 0x00);
      expect(bytes[9], 0x00);
      // 1 Track
      expect(bytes[10], 0x00);
      expect(bytes[11], 0x01);
      // PPQN = 480 (0x01E0)
      expect(bytes[12], 0x01);
      expect(bytes[13], 0xE0);

      // Check MTrk Magic at offset 14
      expect(String.fromCharCodes(bytes.sublist(14, 18)), 'MTrk');

      // Contains NoteOn status byte (0x90) and NoteOff status byte (0x80)
      expect(bytes.contains(0x90), isTrue);
      expect(bytes.contains(0x80), isTrue);

      // Ends with Meta End of Track: 0xFF, 0x2F, 0x00
      expect(bytes[bytes.length - 3], 0xFF);
      expect(bytes[bytes.length - 2], 0x2F);
      expect(bytes[bytes.length - 1], 0x00);
    });
  });
}
