import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/transcription/domain/live_transcription_engine.dart';

void main() {
  group('RhythmicQuantizer Tests', () {
    test('Quantizes small ticks to sixteenth note (1 tick)', () {
      expect(RhythmicQuantizer.quantizeDuration(0), equals(1));
      expect(RhythmicQuantizer.quantizeDuration(1), equals(1));
    });

    test('Quantizes 2 ticks to eighth note (2 ticks)', () {
      expect(RhythmicQuantizer.quantizeDuration(2), equals(2));
    });

    test('Quantizes 3-5 ticks to quarter note (4 ticks)', () {
      expect(RhythmicQuantizer.quantizeDuration(3), equals(4));
      expect(RhythmicQuantizer.quantizeDuration(4), equals(4));
      expect(RhythmicQuantizer.quantizeDuration(5), equals(4));
    });

    test('Quantizes 7-10 ticks to half note (8 ticks)', () {
      expect(RhythmicQuantizer.quantizeDuration(7), equals(8));
      expect(RhythmicQuantizer.quantizeDuration(8), equals(8));
      expect(RhythmicQuantizer.quantizeDuration(10), equals(8));
    });

    test('Quantizes 14+ ticks to whole note (16 ticks)', () {
      expect(RhythmicQuantizer.quantizeDuration(14), equals(16));
      expect(RhythmicQuantizer.quantizeDuration(16), equals(16));
      expect(RhythmicQuantizer.quantizeDuration(20), equals(16));
    });
  });

  group('LiveTranscriptionEngine Tests', () {
    late SongPackage basePackage;
    late LiveTranscriptionEngine engine;

    setUp(() {
      basePackage = const SongPackage(
        id: 'test_transcription',
        title: 'Transcripción de Prueba',
        composer: 'Estudiante',
        genre: MusicGenre.contemporary,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 120,
        tracks: [],
        score: HierarchicalScore(
          title: 'Transcripción de Prueba',
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [],
            ),
          ],
        ),
      );
      engine = LiveTranscriptionEngine(
        minFramesForOnset: 2,
        minClarityThreshold: 0.80,
      );
    });

    test('Ignores noisy or unvoiced frames below clarity threshold', () {
      engine.start(initialPackage: basePackage);
      final result = engine.processPitchFrame(
        frequencyHz: 440.0,
        clarity: 0.50, // Low clarity
        noteName: 'La4',
      );

      expect(result, isNull);
      expect(engine.activePackage!.score.measures.first.notes, isEmpty);
    });

    test('Discards transient candidate if cut before minFramesForOnset', () {
      engine.start(initialPackage: basePackage);

      // Frame 1: Valid onset
      final frame1 = engine.processPitchFrame(
        frequencyHz: 440.0,
        clarity: 0.95,
        noteName: 'La4',
      );
      expect(frame1, isNull);

      // Frame 2: Silence before onset threshold reached (1 frame < 2)
      final frame2 = engine.processPitchFrame(
        frequencyHz: 0.0,
        clarity: 0.0,
        noteName: '--',
      );
      expect(frame2, isNull);
      expect(engine.activePackage!.score.measures.first.notes, isEmpty);
    });

    test('Transcribes sustained note when followed by silence', () {
      engine.start(initialPackage: basePackage);

      // Frame 1 & 2 & 3 & 4: Sustained Do4
      for (int i = 0; i < 4; i++) {
        final r = engine.processPitchFrame(
          frequencyHz: 261.63,
          clarity: 0.95,
          noteName: 'Do4',
        );
        expect(r, isNull);
      }

      // Silence arrives, closing note
      final updatedPackage = engine.processPitchFrame(
        frequencyHz: 0.0,
        clarity: 0.0,
        noteName: '--',
      );

      expect(updatedPackage, isNotNull);
      final notes = updatedPackage!.score.measures.first.notes;
      expect(notes.length, equals(1));
      expect(notes.first.noteName, equals('Do4'));
      expect(notes.first.startTick, equals(0));
      expect(notes.first.durationTicks, equals(4)); // Quantized 4 ticks
    });

    test('Transcribes sequential notes accurately when pitch changes', () {
      engine.start(initialPackage: basePackage);

      // 4 frames of Mi4
      for (int i = 0; i < 4; i++) {
        engine.processPitchFrame(
          frequencyHz: 329.63,
          clarity: 0.92,
          noteName: 'Mi4',
        );
      }

      // Transition to Sol4
      final transitionResult = engine.processPitchFrame(
        frequencyHz: 392.00,
        clarity: 0.94,
        noteName: 'Sol4',
      );

      // First note (Mi4) must have been committed
      expect(transitionResult, isNotNull);
      expect(transitionResult!.score.measures.first.notes.length, equals(1));
      expect(transitionResult.score.measures.first.notes.first.noteName, equals('Mi4'));

      // 2 more frames of Sol4
      for (int i = 0; i < 2; i++) {
        engine.processPitchFrame(
          frequencyHz: 392.00,
          clarity: 0.94,
          noteName: 'Sol4',
        );
      }

      // Finalize with stop()
      final finalPackage = engine.stop();
      expect(finalPackage, isNotNull);
      final notes = finalPackage!.score.measures.first.notes;
      expect(notes.length, equals(2));
      expect(notes[0].noteName, equals('Mi4'));
      expect(notes[1].noteName, equals('Sol4'));
      expect(notes[1].startTick, equals(4));
    });

    test('Adds new measure when current measure ticks exceed capacity', () {
      engine.start(initialPackage: basePackage);

      // 16 frames of La4 (whole note = 16 ticks)
      for (int i = 0; i < 16; i++) {
        engine.processPitchFrame(
          frequencyHz: 440.0,
          clarity: 0.95,
          noteName: 'La4',
        );
      }

      // Silence to commit La4
      final pkg1 = engine.processPitchFrame(
        frequencyHz: 0.0,
        clarity: 0.0,
        noteName: '--',
      );

      expect(pkg1, isNotNull);
      expect(engine.currentMeasureIndex, equals(1)); // Advanced to measure 1
      expect(engine.currentTickInMeasure, equals(0));

      // Now play Si4 in measure 1
      for (int i = 0; i < 4; i++) {
        engine.processPitchFrame(
          frequencyHz: 493.88,
          clarity: 0.95,
          noteName: 'Si4',
        );
      }
      final finalPackage = engine.stop();
      expect(finalPackage!.score.measures.length, greaterThanOrEqualTo(2));
      expect(finalPackage.score.measures[0].notes.first.noteName, equals('La4'));
      expect(finalPackage.score.measures[1].notes.first.noteName, equals('Si4'));
    });
  });
}
