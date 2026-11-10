import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_score_converter.dart';

void main() {
  group('VocalScoreConverter Domain Tests', () {
    const converter = VocalScoreConverter();

    test('Empty pitch track produces valid single-measure rest package', () {
      final result = converter.convertTrackToScore(
        pitchTrack: const [],
        title: 'Toma Vacía',
        bpm: 120,
      );

      expect(result.totalNotes, equals(0));
      expect(result.package.score.measures.length, equals(1));
      expect(result.package.score.measures.first.notes.first.isRest, isTrue);
      expect(result.package.score.measures.first.notes.first.durationTicks, equals(16));
    });

    test('Converts sustained 440 Hz tone (500 ms at 120 bpm) into quarter note La4', () {
      // 120 bpm: 1 beat = 500ms = 4 sub-ticks
      final samples = List.generate(
        25,
        (i) => TimedPitchSample(
          timeMs: i * 20, // 0..480 ms
          frequencyHz: 440.0,
          centsDeviation: 0.0,
          targetNoteName: 'La4',
        ),
      );

      final result = converter.convertTrackToScore(
        pitchTrack: samples,
        title: 'Toma La4',
        bpm: 120,
      );

      expect(result.totalNotes, equals(1));
      final note = result.package.score.measures.first.notes.first;
      expect(note.isRest, isFalse);
      expect(note.noteName, equals('La4'));
      expect(note.durationTicks, equals(4)); // Negra (4 ticks)
    });

    test('Segments 3-note melodic phrase (Do4 -> Mi4 -> Sol4) into 3 distinct notes', () {
      final samples = <TimedPitchSample>[];
      // Do4 (261.63 Hz) por 240 ms
      for (int i = 0; i < 12; i++) {
        samples.add(TimedPitchSample(timeMs: i * 20, frequencyHz: 261.63, centsDeviation: 2.0, targetNoteName: 'Do4'));
      }
      // Mi4 (329.63 Hz) por 240 ms
      for (int i = 12; i < 24; i++) {
        samples.add(TimedPitchSample(timeMs: i * 20, frequencyHz: 329.63, centsDeviation: -1.0, targetNoteName: 'Mi4'));
      }
      // Sol4 (392.00 Hz) por 240 ms
      for (int i = 24; i < 36; i++) {
        samples.add(TimedPitchSample(timeMs: i * 20, frequencyHz: 392.00, centsDeviation: 3.0, targetNoteName: 'Sol4'));
      }

      final result = converter.convertTrackToScore(
        pitchTrack: samples,
        title: 'Triada Mayor',
        bpm: 120,
      );

      expect(result.totalNotes, equals(3));
      final notes = result.package.score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(notes.length, equals(3));
      expect(notes[0].noteName, equals('Do4'));
      expect(notes[1].noteName, equals('Mi4'));
      expect(notes[2].noteName, equals('Sol4'));
    });

    test('Uses Auto-Tuned pitch when preferCorrectedPitch is true', () {
      // Cantante desafinado a 430 Hz (-40 cents respecto a La4) pero Auto-Tune corrigió a 440 Hz
      final samples = List.generate(
        15,
        (i) => TimedPitchSample(
          timeMs: i * 20,
          frequencyHz: 430.0,
          centsDeviation: -39.6,
          targetNoteName: 'La4',
          correctedPitchHz: 440.0,
          isAutoTuned: true,
        ),
      );

      final resultRaw = converter.convertTrackToScore(
        pitchTrack: samples,
        preferCorrectedPitch: false,
      );

      final resultTuned = converter.convertTrackToScore(
        pitchTrack: samples,
        preferCorrectedPitch: true,
      );

      expect(resultRaw.totalNotes, equals(1));
      expect(resultTuned.totalNotes, equals(1));
      expect(resultTuned.autoTunedNotesCount, equals(1));
      expect(resultTuned.package.score.measures.first.notes.first.noteName, equals('La4'));
    });

    test('Snaps out-of-scale notes to C Major scale (Melodyne 1-Tap Snap)', () {
      final samples = <TimedPitchSample>[
        // Fa#4 (369.99 Hz) desafinado para escala Do Mayor
        ...List.generate(
          10,
          (i) => TimedPitchSample(timeMs: i * 20, frequencyHz: 369.99, centsDeviation: 0.0, targetNoteName: 'Fa#4'),
        ),
      ];

      final rawResult = converter.convertTrackToScore(pitchTrack: samples);
      expect(rawResult.package.score.measures.first.notes.first.noteName, equals('Fa#4'));

      // Aplicar snap to C Major (rootKey = 0, scaleType = major)
      final snappedPackage = converter.snapToScale(
        package: rawResult.package,
        rootKey: 0, // Do
        scaleType: VocalScaleType.major,
      );

      final snappedNoteName = snappedPackage.score.measures.first.notes.first.noteName;
      // Fa#4 debe alinearse a Fa4 o Sol4
      expect(snappedNoteName == 'Fa4' || snappedNoteName == 'Sol4', isTrue);
    });

    test('Ignores transient noise bursts below 50ms', () {
      final samples = <TimedPitchSample>[
        // Ruido transitorio de 30ms
        TimedPitchSample(timeMs: 0, frequencyHz: 500.0, centsDeviation: 0.0, targetNoteName: 'Si4'),
        TimedPitchSample(timeMs: 20, frequencyHz: 500.0, centsDeviation: 0.0, targetNoteName: 'Si4'),
        // Silencio
        TimedPitchSample(timeMs: 40, frequencyHz: 0.0, centsDeviation: 0.0, targetNoteName: '--', isSilent: true),
        TimedPitchSample(timeMs: 150, frequencyHz: 0.0, centsDeviation: 0.0, targetNoteName: '--', isSilent: true),
        // Nota real sostenida de 200ms
        ...List.generate(
          10,
          (i) => TimedPitchSample(timeMs: 200 + (i * 20), frequencyHz: 440.0, centsDeviation: 0.0, targetNoteName: 'La4'),
        ),
      ];

      final result = converter.convertTrackToScore(pitchTrack: samples);
      expect(result.totalNotes, equals(1));
      expect(result.package.score.measures.first.notes.first.noteName, equals('La4'));
    });
  });
}
