import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/practice_recorder/domain/practice_recording_entity.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recorder_dock.dart';
import 'package:tunner/features/song_library/presentation/song_decomposer_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/vocal_autotune/presentation/vocal_autotune_modal.dart';

import 'mock_recorder_services.dart';

class _MockPitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _MockMetronomeService implements IMetronomeService {
  @override
  Function(int p1)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TunerViewModel createViewModelWithTake({
    required String songTitle,
    required List<TimedPitchSample> pitchTrack,
    int bpm = 104,
  }) {
    final now = DateTime(2026, 11, 26, 14, 0, 0);
    const filePath = '/tmp/us_hc_08_take.wav';
    final recording = PracticeRecordingEntity(
      id: 'rec_us_hc_08',
      filePath: filePath,
      recordedAt: now,
      duration: const Duration(seconds: 4),
      songTitle: songTitle,
      bpm: bpm,
      waveformPeaks: const [0.3, 0.7, 0.5],
    );
    final take = PracticeTakeEntity(
      id: 'take_us_hc_08',
      name: songTitle,
      timestamp: now,
      duration: const Duration(seconds: 4),
      filePath: filePath,
      waveformPeaks: const [0.3, 0.7, 0.5],
      pitchTrack: pitchTrack,
    );
    final session = MultiTrackSessionEntity(
      id: 'session_us_hc_08',
      title: songTitle,
      createdAt: now,
      bpm: bpm,
      takes: [take],
      selectedTakeAId: take.id,
      selectedTakeBId: take.id,
    );

    return TunerViewModel(
      pitchService: _MockPitchService(),
      metronomeService: _MockMetronomeService(),
      evaluatorService: const PracticeEvaluatorService(),
      transpositionService: const InstrumentTranspositionService(),
      recorderService: MockPracticeRecorderService(),
      playbackService: MockAudioPlaybackService(),
      persistenceService: MemoryPersistenceService(
        AppUserSettingsEntity(
          recordingHistory: [recording],
          multiTrackSession: session,
        ),
      ),
      recordingPathProvider: () async => filePath,
      seedDefaults: false,
    );
  }

  group('US-HC-08: PracticeRecorderDock 1-Click Bridges & SongDecomposerModal Pitch Ingestion', () {
    testWidgets(
      'PracticeRecorderDock muestra AutoTune y A Partitura cuando hay toma grabada, abre VocalAutoTuneModal y convierte la toma en partitura',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final pitchSamples = [
          for (int i = 0; i < 12; i++)
            TimedPitchSample(
              timeMs: i * 50,
              frequencyHz: 293.66,
              centsDeviation: 0.0,
              targetNoteName: 'Re4',
            ),
          for (int i = 12; i < 24; i++)
            TimedPitchSample(
              timeMs: i * 50,
              frequencyHz: 440.0,
              centsDeviation: 0.0,
              targetNoteName: 'La4',
            ),
        ];

        final viewModel = createViewModelWithTake(
          songTitle: 'Escala Vocal US-HC-08',
          pitchTrack: pitchSamples,
        );
        addTearDown(viewModel.dispose);

        await viewModel.isInitialized;
        expect(viewModel.recordingHistory, isNotEmpty);
        final initialPackageId = viewModel.activePackage.id;

        await tester.pumpWidget(
          StudioThemeScope(
            controller: StudioThemeController(),
            child: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: const MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: PracticeRecorderDock(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final autoTuneBtn = find.byKey(const Key('btn_recorder_send_to_autotune'));
        final transcribeBtn = find.byKey(const Key('btn_recorder_transcribe_to_score'));

        expect(autoTuneBtn, findsOneWidget);
        expect(transcribeBtn, findsOneWidget);

        // 1. Transcribir toma a partitura en 1 clic
        await tester.tap(transcribeBtn);
        await tester.pump();

        expect(viewModel.activePackage.id, isNot(equals(initialPackageId)));
        expect(viewModel.activePackage.title, contains('Toma Afinada'));
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Toma convertida a partitura'), findsOneWidget);

        // 2. Abrir VocalAutoTuneModal en 1 clic
        await tester.tap(autoTuneBtn);
        await tester.pumpAndSettle();

        expect(find.byType(VocalAutoTuneModal), findsOneWidget);
        expect(find.byKey(const Key('vocal_autotune_modal')), findsOneWidget);
      },
    );

    testWidgets(
      'SongDecomposerModal extrae notas reales de pitchTrack colapsando repeticiones al pulsar el chip Toma',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final viewModel = createViewModelWithTake(
          songTitle: 'Melodia Real Re-Fa#-La',
          bpm: 96,
          pitchTrack: const [
            TimedPitchSample(
              timeMs: 0,
              frequencyHz: 293.66,
              centsDeviation: 0.0,
              targetNoteName: 'Re4',
            ),
            TimedPitchSample(
              timeMs: 40,
              frequencyHz: 293.66,
              centsDeviation: 1.0,
              targetNoteName: 'Re4',
            ),
            TimedPitchSample(
              timeMs: 80,
              frequencyHz: 0.0,
              centsDeviation: 0.0,
              targetNoteName: '--',
              isSilent: true,
            ),
            TimedPitchSample(
              timeMs: 120,
              frequencyHz: 369.99,
              centsDeviation: -2.0,
              targetNoteName: 'Fa#4',
            ),
            TimedPitchSample(
              timeMs: 160,
              frequencyHz: 440.0,
              centsDeviation: 0.5,
              targetNoteName: 'La4',
            ),
            TimedPitchSample(
              timeMs: 200,
              frequencyHz: 440.0,
              centsDeviation: 0.0,
              targetNoteName: 'La4',
            ),
          ],
        );
        addTearDown(viewModel.dispose);

        await viewModel.isInitialized;
        expect(viewModel.recordingHistory, isNotEmpty);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SongDecomposerModal(viewModel: viewModel),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final takeChip = find.text('Toma: Melodia Real Re-Fa#-La');
        expect(takeChip, findsOneWidget);

        await tester.tap(takeChip);
        await tester.pumpAndSettle();

        expect(find.text('Re4 Fa#4 La4'), findsOneWidget);
      },
    );

    testWidgets(
      'SongDecomposerModal asigna secuencia base Do4 Re4 Mi4 Sol4 si la toma no tiene pitchTrack',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final viewModel = createViewModelWithTake(
          songTitle: 'Toma Sin Pitch',
          pitchTrack: const [],
        );
        addTearDown(viewModel.dispose);

        await viewModel.isInitialized;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SongDecomposerModal(viewModel: viewModel),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final takeChip = find.text('Toma: Toma Sin Pitch');
        expect(takeChip, findsOneWidget);

        await tester.tap(takeChip);
        await tester.pumpAndSettle();

        expect(find.text('Do4 Re4 Mi4 Sol4'), findsOneWidget);
      },
    );
  });
}
