import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/transcription/domain/polyphonic_transcription_engine.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PolyphonicChordCandidate Unit Tests', () {
    test('Normalizes and sorts active notes uniquely', () {
      final candidate = PolyphonicChordCandidate(
        activeNoteNames: ['Sol4', 'Do4', 'Mi4', 'Do4', '--', ''],
        startTick: 0,
        measureIndex: 0,
      );

      expect(candidate.activeNoteNames, equals(['Do4', 'Mi4', 'Sol4']));
      expect(candidate.startTick, equals(0));
      expect(candidate.measureIndex, equals(0));
      expect(candidate.durationTicks, equals(1));
      expect(candidate.consecutiveFrames, equals(1));
    });

    test('matchesNoteNames matches regardless of ordering and ignores rests', () {
      final candidate = PolyphonicChordCandidate(
        activeNoteNames: ['Do4', 'Mi4', 'Sol4'],
        startTick: 0,
        measureIndex: 0,
      );

      expect(candidate.matchesNoteNames(['Sol4', 'Do4', 'Mi4']), isTrue);
      expect(candidate.matchesNoteNames(['Do4', 'Mi4', 'Sol4', '--']), isTrue);
      expect(candidate.matchesNoteNames(['Do4', 'Mi4']), isFalse);
      expect(candidate.matchesNoteNames(['Do4', 'Mi4', 'La4']), isFalse);
    });
  });

  group('PolyphonicTranscriptionEngine Domain Tests', () {
    late PolyphonicTranscriptionEngine engine;
    late SongPackage initialPackage;

    setUp(() {
      engine = PolyphonicTranscriptionEngine(minFramesForOnset: 2);
      initialPackage = SongPackage(
        id: 'test_poly_pkg',
        title: 'Estudio Polifonico',
        composer: 'Tunner Engine',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: 120,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Estudio Polifonico',
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.rest(startTick: 0, durationTicks: 16),
              ],
            ),
          ],
        ),
      );
    });

    test('Discards transient cluster noise below onset threshold', () {
      engine.start(initialPackage: initialPackage);

      // Frame 1: Ruido transitorio breve
      final result1 = engine.processPolyphonicFrame(
        noteNames: ['Do4', 'Mi4'],
        energyRms: 0.1,
      );
      expect(result1, isNull);
      expect(engine.activeCandidate, isNotNull);
      expect(engine.activeCandidate!.consecutiveFrames, equals(1));

      // Silencio repentino (descarte del candidato)
      final result2 = engine.processPolyphonicFrame(
        noteNames: [],
        energyRms: 0.0,
      );
      expect(result2, isNull);
      expect(engine.activeCandidate, isNull);
    });

    test('Transcribes sustained C Major chord into score tree', () {
      engine.start(initialPackage: initialPackage);

      // Frame 1: Ataque
      engine.processPolyphonicFrame(
        noteNames: ['Do4', 'Mi4', 'Sol4'],
        energyRms: 0.15,
      );

      // Frames 2 a 5: Sostenido (4 ticks observados -> cuantizado a 4 ticks de negra)
      for (int i = 0; i < 4; i++) {
        engine.processPolyphonicFrame(
          noteNames: ['Do4', 'Mi4', 'Sol4'],
          energyRms: 0.15,
        );
      }

      // Cierre mediante silencio
      final updatedPackage = engine.processPolyphonicFrame(
        noteNames: [],
        energyRms: 0.0,
      );

      expect(updatedPackage, isNotNull);
      final measure = updatedPackage!.score.measures[0];
      final chordNotes = measure.notes.where((n) => n.startTick == 0).toList();

      expect(chordNotes.length, equals(3));
      expect(chordNotes.map((n) => n.noteName).toList(), containsAll(['Do4', 'Mi4', 'Sol4']));
      expect(chordNotes.every((n) => n.durationTicks == 4), isTrue);
      expect(engine.currentTickInMeasure, equals(4));
    });

    test('Transcribes harmonic progression across measures', () {
      engine.start(initialPackage: initialPackage);

      // Acorde 1: Do Mayor (16 frames -> redonda = 16 ticks)
      for (int i = 0; i < 16; i++) {
        engine.processPolyphonicFrame(
          noteNames: ['Do4', 'Mi4', 'Sol4'],
          energyRms: 0.2,
        );
      }

      // Acorde 2: Sol Mayor (16 frames -> redonda = 16 ticks)
      // El cambio de acorde consolida el primero y avanza al compas 1
      final intermediatePackage = engine.processPolyphonicFrame(
        noteNames: ['Sol3', 'Si3', 'Re4'],
        energyRms: 0.2,
      );
      expect(intermediatePackage, isNotNull);
      expect(engine.currentMeasureIndex, equals(1));
      expect(engine.currentTickInMeasure, equals(0));

      for (int i = 0; i < 15; i++) {
        engine.processPolyphonicFrame(
          noteNames: ['Sol3', 'Si3', 'Re4'],
          energyRms: 0.2,
        );
      }

      final finalPackage = engine.stop();
      expect(finalPackage, isNotNull);
      expect(finalPackage!.score.measures.length, greaterThanOrEqualTo(2));

      // Verificar compas 0 (Do Mayor)
      final m0 = finalPackage.score.measures[0];
      expect(m0.isValidMeasure, isTrue);
      final m0Notes = m0.notes.where((n) => n.startTick == 0).toList();
      expect(m0Notes.length, equals(3));

      // Verificar compas 1 (Sol Mayor)
      final m1 = finalPackage.score.measures[1];
      expect(m1.isValidMeasure, isTrue);
      final m1Notes = m1.notes.where((n) => n.startTick == 0).toList();
      expect(m1Notes.length, equals(3));
      expect(m1Notes.map((n) => n.noteName).toList(), containsAll(['Sol3', 'Si3', 'Re4']));
    });
  });

  group('TunerViewModel Polyphonic Transcription Integration Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('togglePolyphonicLiveTranscription starts and stops engine reactively', () {
      expect(viewModel.isPolyphonicTranscriptionActive, isFalse);

      viewModel.togglePolyphonicLiveTranscription();
      expect(viewModel.isPolyphonicTranscriptionActive, isTrue);
      expect(viewModel.polyphonicTranscriptionEngine.isTranscribing, isTrue);

      viewModel.togglePolyphonicLiveTranscription();
      expect(viewModel.isPolyphonicTranscriptionActive, isFalse);
      expect(viewModel.polyphonicTranscriptionEngine.isTranscribing, isFalse);
    });

    test('processPolyphonicTranscriptionFrame updates active score package', () {
      viewModel.togglePolyphonicLiveTranscription();

      // Enviar frames de acorde Mi menor (Mi4, Sol4, Si4)
      for (int i = 0; i < 5; i++) {
        viewModel.processPolyphonicTranscriptionFrame(
          noteNames: ['Mi4', 'Sol4', 'Si4'],
          energyRms: 0.18,
        );
      }

      // Detener para consolidar
      viewModel.togglePolyphonicLiveTranscription();

      final activeScore = viewModel.activePackage.score;
      final notes = activeScore.measures[0].notes;
      final chordNotes = notes.where((n) => n.startTick == 0).toList();

      expect(chordNotes.length, equals(3));
      expect(chordNotes.map((n) => n.noteName).toList(), containsAll(['Mi4', 'Sol4', 'Si4']));
    });
  });
}
