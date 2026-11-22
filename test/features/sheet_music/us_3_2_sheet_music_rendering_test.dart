import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';

void main() {
  group('US-3.2 Sheet Music Dotted Notes, Beams and 2D Hit-Testing Tests', () {
    test('HierarchicalNote retains isTied in serialization and copyWith', () {
      final noteTied = HierarchicalNote(
        noteName: 'C4',
        durationTicks: 6,
        startTick: 0,
        isTied: true,
      );

      expect(noteTied.isTied, isTrue);

      final map = noteTied.toMap();
      expect(map['isTied'], isTrue);

      final reconstructed = HierarchicalNote.fromMap(map);
      expect(reconstructed.isTied, isTrue);
      expect(reconstructed.durationTicks, equals(6));

      final untied = reconstructed.copyWith(isTied: false);
      expect(untied.isTied, isFalse);
    });

    test('MeasureEntity preserves keySignatureFifths in copyWith and serialization', () {
      final measure = MeasureEntity(
        index: 0,
        timeSignature: TimeSignature.commonTime44,
        notes: [
          HierarchicalNote(noteName: 'G4', durationTicks: 4, startTick: 0),
        ],
        keySignatureFifths: 3, // 3 sostenidos (A Mayor / F# menor)
      );

      expect(measure.keySignatureFifths, equals(3));
      final map = measure.toMap();
      expect(map['keySignatureFifths'], equals(3));

      final restored = MeasureEntity.fromMap(map);
      expect(restored.keySignatureFifths, equals(3));

      final altered = restored.copyWith(keySignatureFifths: -2); // 2 bemoles
      expect(altered.keySignatureFifths, equals(-2));
    });

    test('findNoteIndexAtOffset disambiguates notes sharing X column using 2D vertical Euclidean delta', () {
      final notes = [
        HierarchicalNote(noteName: 'C4', durationTicks: 4, startTick: 0), // Grave
        HierarchicalNote(noteName: 'A5', durationTicks: 4, startTick: 0), // Agudo en el mismo X
      ];

      final painter = RealSheetMusicPainter(
        notes: notes,
        currentSubTick: 0,
        timeSignature: TimeSignature.commonTime44,
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        measureIndex: 0,
        totalMeasures: 1,
      );

      const size = Size(400, 200);

      // En tick 0 (startX = 75), clic en zona grave vs aguda
      final hitC4 = painter.findNoteIndexAtOffset(const Offset(80.0, 130.0), size);
      expect(hitC4, equals(0), reason: 'Debe seleccionar C4 por proximidad vertical');

      final hitA5 = painter.findNoteIndexAtOffset(const Offset(80.0, 65.0), size);
      expect(hitA5, equals(1), reason: 'Debe seleccionar A5 por proximidad vertical');
    });

    test('RealSheetMusicPainter paints dotted notes, ties, beams and key signatures without errors', () {
      final notes = [
        HierarchicalNote(noteName: 'C4', durationTicks: 6, startTick: 0, isTied: true), // Con puntillo (negra con puntillo) y ligada
        HierarchicalNote(noteName: 'C4', durationTicks: 2, startTick: 6), // Corchea ligada
        HierarchicalNote(noteName: 'D4', durationTicks: 2, startTick: 8), // Corchea agrupada 1
        HierarchicalNote(noteName: 'E4', durationTicks: 2, startTick: 10), // Corchea agrupada 2 (beam)
        HierarchicalNote(noteName: 'F4', durationTicks: 1, startTick: 12), // Semicorchea
        HierarchicalNote(noteName: 'G4', durationTicks: 1, startTick: 13), // Semicorchea
      ];

      final painter = RealSheetMusicPainter(
        notes: notes,
        currentSubTick: 2,
        timeSignature: TimeSignature.commonTime44,
        history: const {0: PlayedRecord('C4', 2.0, true)},
        liveNote: 'C4',
        liveCents: 0.5,
        isCountingIn: false,
        countInBeat: 0,
        measureIndex: 0,
        totalMeasures: 2,
        clef: InstrumentClef.alto,
        keySignatureFifths: 4, // 4 sostenidos
        selectedNoteIndex: 0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(500, 220);

      // Debe ejecutarse completamente sin lanzar excepciones
      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
