import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/acoustic_lab/domain/harmonic_series_analyzer.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/practice_recorder/domain/practice_recording_entity.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recorder_controller.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recording_player_modal.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_modal.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_painter.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import '../../helpers/studio_test_fakes.dart';
import 'mock_recorder_services.dart';

class _SpyAudioSynthesizerService implements IAudioSynthesizerService {
  int playNoteToneCallCount = 0;
  double? lastFrequencyHz;

  @override
  bool get isDiapasonPlaying => false;

  @override
  double get activeDiapasonFrequency => 0.0;

  @override
  bool get isDroneLoopPlaying => false;

  @override
  Future<void> playMetronomeClick({required bool isDownbeat, double volume = 1.0}) async {}

  @override
  Future<void> startDiapasonTone(double frequency, {double volume = 0.8}) async {}

  @override
  Future<void> stopDiapasonTone() async {}

  @override
  Future<void> playNoteTone({
    required double frequency,
    required Duration duration,
    double volume = 0.8,
  }) async {
    playNoteToneCallCount++;
    lastFrequencyHz = frequency;
  }

  @override
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7}) async {}

  @override
  Future<void> playPcmWav(Uint8List wavBytes, {double volume = 0.8}) async {}

  @override
  Future<void> stopDroneLoop() async {}

  @override
  void dispose() {}
}

class _FailingAudioPlaybackService extends MockAudioPlaybackService {
  @override
  Future<void> play(String filePath) async {
    throw const FileSystemException('Archivo de audio no encontrado', '/missing/take.wav');
  }
}

class _FakeMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-4.6 Eliminacion de Tomas Falsas y Fallbacks Sinteticos', () {
    test('TunerViewModel con seedDefaults true o false inicia sin tomas falsas ni grabaciones ficticias', () async {
      final vmSeeded = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: MockPracticeRecorderService(),
        playbackService: MockAudioPlaybackService(),
        persistenceService: MemoryPersistenceService(),
        seedDefaults: true,
      );
      await vmSeeded.isInitialized;

      expect(vmSeeded.multiTrackSession.takes, isEmpty);
      expect(vmSeeded.multiTrackSession.selectedTakeAId, isNull);
      expect(vmSeeded.multiTrackSession.selectedTakeBId, isNull);
      expect(vmSeeded.recordingHistory, isEmpty);
      expect(vmSeeded.activeRecording, isNull);

      vmSeeded.dispose();

      final vmClean = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: MockPracticeRecorderService(),
        playbackService: MockAudioPlaybackService(),
        persistenceService: MemoryPersistenceService(),
        seedDefaults: false,
      );
      await vmClean.isInitialized;

      expect(vmClean.multiTrackSession.takes, isEmpty);
      expect(vmClean.recordingHistory, isEmpty);
      vmClean.dispose();
    });

    test('playActiveRecording y playTakeAudio no emiten pitido de 440 Hz cuando no hay archivo valido', () async {
      final spySynth = _SpyAudioSynthesizerService();
      final mockPlayback = MockAudioPlaybackService();
      final vm = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: MockPracticeRecorderService(),
        playbackService: mockPlayback,
        audioSynthesizerService: spySynth,
        persistenceService: MemoryPersistenceService(),
      );
      await vm.isInitialized;

      final emptyRecording = PracticeRecordingEntity(
        id: 'rec_empty',
        filePath: '',
        recordedAt: DateTime(2026, 11, 22, 10, 0),
        duration: const Duration(seconds: 3),
        songTitle: 'Toma Sin Archivo',
        bpm: 100,
      );

      await vm.playActiveRecording(emptyRecording);
      expect(spySynth.playNoteToneCallCount, equals(0));
      expect(mockPlayback.currentFilePath, isNull);
      expect(vm.isPlayingAudio, isFalse);

      final emptyTake = PracticeTakeEntity(
        id: 'take_empty',
        name: 'Toma Vacia',
        timestamp: DateTime(2026, 11, 22, 10, 1),
        duration: const Duration(seconds: 3),
        filePath: '   ',
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 0.0, targetNoteName: 'La4'),
        ],
      );

      await vm.playTakeAudio(emptyTake);
      expect(spySynth.playNoteToneCallCount, equals(0));
      expect(mockPlayback.currentFilePath, isNull);
      expect(vm.isPlayingAudio, isFalse);

      vm.dispose();
    });

    test('playTakeAudio y playActiveRecording manejan fallos de reproduccion sin pitido de respaldo', () async {
      final spySynth = _SpyAudioSynthesizerService();
      final failingPlayback = _FailingAudioPlaybackService();
      final vm = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: MockPracticeRecorderService(),
        playbackService: failingPlayback,
        audioSynthesizerService: spySynth,
        persistenceService: MemoryPersistenceService(),
      );
      await vm.isInitialized;

      final missingTake = PracticeTakeEntity(
        id: 'take_missing',
        name: 'Archivo Inexistente',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 2),
        filePath: '/missing/take.wav',
      );

      await vm.playTakeAudio(missingTake);
      expect(spySynth.playNoteToneCallCount, equals(0));
      expect(vm.isPlayingAudio, isFalse);

      vm.dispose();
    });
  });

  group('US-4.6 Calculo Timbrico Real FFT/DFT y Downsampling Proporcional', () {
    test('recordSampleForMultiTrack calcula centroid y THD reales mediante HarmonicSeriesAnalyzer', () async {
      final fakePitch = StudioFakePitchDetectorService();
      final mockRecorder = MockPracticeRecorderService();
      final vm = TunerViewModel(
        pitchService: fakePitch,
        metronomeService: _FakeMetronomeService(),
        recorderService: mockRecorder,
        playbackService: MockAudioPlaybackService(),
        persistenceService: MemoryPersistenceService(),
        recordingPathProvider: () async => '/tmp/real_timbre.wav',
      );
      await vm.isInitialized;

      const sampleRate = 44100.0;
      const f0 = 440.0;
      const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);

      final pureSine = List<double>.generate(
        1024,
        (i) => 0.8 * math.sin(2.0 * math.pi * f0 * i / sampleRate),
      );
      final richHarmonic = List<double>.generate(1024, (i) {
        final t = i / sampleRate;
        return 0.5 * math.sin(2.0 * math.pi * f0 * t) +
            0.4 * math.sin(2.0 * math.pi * (2.0 * f0) * t) +
            0.35 * math.sin(2.0 * math.pi * (3.0 * f0) * t);
      });

      final expectedPure = analyzer.analyze(fundamentalHz: f0, samples: pureSine, sampleRate: sampleRate);
      final expectedRich = analyzer.analyze(fundamentalHz: f0, samples: richHarmonic, sampleRate: sampleRate);

      await vm.startPracticeRecording();

      fakePitch.onAudioWindowCaptured?.call(pureSine);
      fakePitch.onPitchDetected?.call(f0);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      fakePitch.onAudioWindowCaptured?.call(richHarmonic);
      fakePitch.onPitchDetected?.call(f0);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await vm.stopPracticeRecording();

      expect(vm.multiTrackSession.takes.length, equals(1));
      final spectralTrack = vm.multiTrackSession.takes.first.spectralTrack;
      expect(spectralTrack.length, equals(2));

      // Ninguna muestra puede corresponder a la constante falsa pitch * 2.6 = 1144 Hz ni THD 3.2
      expect(spectralTrack[0].spectralCentroidHz, closeTo(expectedPure.spectralCentroidHz, 0.01));
      expect(spectralTrack[0].thdPercent, closeTo(expectedPure.totalHarmonicDistortionPercent, 0.01));
      expect(spectralTrack[0].spectralCentroidHz, isNot(closeTo(f0 * 2.6, 5.0)));
      expect(spectralTrack[0].thdPercent, lessThan(8.0));

      expect(spectralTrack[1].spectralCentroidHz, closeTo(expectedRich.spectralCentroidHz, 0.01));
      expect(spectralTrack[1].thdPercent, closeTo(expectedRich.totalHarmonicDistortionPercent, 0.01));
      expect(spectralTrack[1].spectralCentroidHz, greaterThan(spectralTrack[0].spectralCentroidHz + 150.0));
      expect(spectralTrack[1].thdPercent, greaterThan(25.0));

      vm.dispose();
    });

    test('recordSampleForMultiTrack no inventa muestras espectrales si faltan muestras PCM reales', () {
      final controller = PracticeRecorderController(
        recorderService: MockPracticeRecorderService(),
        playbackService: MockAudioPlaybackService(),
        persistenceService: MemoryPersistenceService(),
        platformFileGateway: const NoOpPlatformFileGateway(),
        initialTitle: 'Test',
        initialBpm: 120,
        onNotify: () {},
        onAutoSave: () {},
      );

      controller.recordSampleForMultiTrack(
        pitch: 440.0,
        cents: 0.0,
        noteName: 'La4',
        isAutoTuneEnabled: false,
        autoTuneTargetHz: 0.0,
        autoTuneCentsDev: 0.0,
        autoTuneTargetNote: '--',
        expectedNoteName: null,
        audioSamples: null,
      );

      expect(controller.currentPitchTrack.length, equals(1));
      expect(controller.currentSpectralTrack, isEmpty);
      controller.dispose();
    });

    test('addWaveformPeak realiza downsampling proporcional cubriendo el 100% de la duracion sin truncar a 60', () async {
      final mockRecorder = MockPracticeRecorderService();
      final vm = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: mockRecorder,
        playbackService: MockAudioPlaybackService(),
        persistenceService: MemoryPersistenceService(),
        recordingPathProvider: () async => '/tmp/long_take.wav',
      );
      await vm.isInitialized;

      await vm.startPracticeRecording();

      // Emitir 300 picos en 3 tramos claramente diferenciados (inicio alto 0.95, centro bajo 0.12, final medio 0.55)
      for (int i = 0; i < 100; i++) {
        mockRecorder.emitAmplitude(0.95);
      }
      for (int i = 0; i < 100; i++) {
        mockRecorder.emitAmplitude(0.12);
      }
      for (int i = 0; i < 100; i++) {
        mockRecorder.emitAmplitude(0.55);
      }

      await Future<void>.delayed(const Duration(milliseconds: 550));
      await vm.stopPracticeRecording();

      final peaks = vm.activeRecording!.waveformPeaks;
      expect(peaks.length, equals(PracticeRecorderController.maxWaveformPeaks));

      // Verificar que los primeros compases (0.95) no fueron descartados por truncamiento
      final firstThirdAvg = peaks.sublist(0, 40).reduce((a, b) => a + b) / 40.0;
      final middleThirdAvg = peaks.sublist(40, 80).reduce((a, b) => a + b) / 40.0;
      final lastThirdAvg = peaks.sublist(80, 120).reduce((a, b) => a + b) / 40.0;

      expect(firstThirdAvg, closeTo(0.95, 0.01));
      expect(middleThirdAvg, closeTo(0.12, 0.01));
      expect(lastThirdAvg, closeTo(0.55, 0.01));
      expect(vm.multiTrackSession.takes.first.waveformPeaks, equals(peaks));

      vm.dispose();
    });
  });

  group('US-4.6 Persistencia de MultiTrackSessionEntity en AppUserSettingsEntity', () {
    test('AppUserSettingsEntity serializa y restaura MultiTrackSessionEntity y tolera datos heredados/corruptos', () {
      final session = MultiTrackSessionEntity(
        id: 'session_99',
        title: 'Estudio en Mi Menor',
        createdAt: DateTime(2026, 11, 22, 12, 0),
        bpm: 96,
        selectedTakeAId: 't_a',
        selectedTakeBId: 't_b',
        takes: [
          PracticeTakeEntity(
            id: 't_a',
            name: 'Toma A',
            timestamp: DateTime(2026, 11, 22, 12, 1),
            duration: const Duration(seconds: 4),
            filePath: '/tmp/t_a.wav',
            waveformPeaks: const [0.3, 0.7, 0.5],
            pitchTrack: const [
              TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 4.0, targetNoteName: 'La4'),
            ],
            spectralTrack: const [
              TimedSpectralSample(timeMs: 0, spectralCentroidHz: 620.0, thdPercent: 1.8, rmsEnergy: 0.4),
            ],
            gain: 0.9,
            isMuted: true,
          ),
          PracticeTakeEntity(
            id: 't_b',
            name: 'Toma B',
            timestamp: DateTime(2026, 11, 22, 12, 3),
            duration: const Duration(seconds: 5),
            filePath: '/tmp/t_b.wav',
            isSolo: true,
          ),
        ],
      );

      final settings = AppUserSettingsEntity(multiTrackSession: session);
      final restored = AppUserSettingsEntity.fromJson(settings.toJson());

      expect(restored.multiTrackSession, isNotNull);
      expect(restored.multiTrackSession!.id, equals('session_99'));
      expect(restored.multiTrackSession!.title, equals('Estudio en Mi Menor'));
      expect(restored.multiTrackSession!.bpm, equals(96));
      expect(restored.multiTrackSession!.selectedTakeAId, equals('t_a'));
      expect(restored.multiTrackSession!.selectedTakeBId, equals('t_b'));
      expect(restored.multiTrackSession!.takes.length, equals(2));
      expect(restored.multiTrackSession!.takes.first.spectralTrack.first.spectralCentroidHz, equals(620.0));
      expect(restored.multiTrackSession!.takes.first.isMuted, isTrue);
      expect(restored.multiTrackSession!.takes.last.isSolo, isTrue);

      // Tolerancia hacia atras sin clave multiTrackSession
      final legacyRestored = AppUserSettingsEntity.fromMap({'referencePitch': 442.0});
      expect(legacyRestored.multiTrackSession, isNull);
      expect(legacyRestored.referencePitch, equals(442.0));

      // Tolerancia a multiTrackSession corrupta
      final corruptWarnings = <String>[];
      final corruptRestored = AppUserSettingsEntity.fromMap(
        {
          'referencePitch': 443.0,
          'multiTrackSession': 'formato_invalido',
        },
        onCorruptEntry: corruptWarnings.add,
      );
      expect(corruptRestored.referencePitch, equals(443.0));
      expect(corruptRestored.multiTrackSession, isNull);
      expect(corruptWarnings, isNotEmpty);
    });

    test('TunerViewModel persiste y restaura MultiTrackSessionEntity en disco entre reinicios', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_multitrack_persist_');
      try {
        final persistence = JsonLocalPersistenceService(
          documentsPathProvider: () async => tempDir.path,
          fileName: 'multitrack_settings.json',
        );

        final vm1 = TunerViewModel(
          pitchService: StudioFakePitchDetectorService(),
          metronomeService: _FakeMetronomeService(),
          recorderService: MockPracticeRecorderService(),
          playbackService: MockAudioPlaybackService(),
          persistenceService: persistence,
        );
        await vm1.isInitialized;

        vm1.addPracticeTake(
          PracticeTakeEntity(
            id: 'take_persisted_1',
            name: 'Toma Persistida 1',
            timestamp: DateTime(2026, 11, 22, 13, 0),
            duration: const Duration(seconds: 6),
            filePath: '/tmp/persisted_1.wav',
            waveformPeaks: const [0.4, 0.8],
            spectralTrack: const [
              TimedSpectralSample(timeMs: 0, spectralCentroidHz: 710.0, thdPercent: 2.1, rmsEnergy: 0.45),
            ],
          ),
        );
        vm1.setTakeGain('take_persisted_1', 0.72);
        await vm1.savePersistedState();

        final vm2 = TunerViewModel(
          pitchService: StudioFakePitchDetectorService(),
          metronomeService: _FakeMetronomeService(),
          recorderService: MockPracticeRecorderService(),
          playbackService: MockAudioPlaybackService(),
          persistenceService: persistence,
        );
        await vm2.isInitialized;

        expect(vm2.multiTrackSession.takes.length, equals(1));
        expect(vm2.multiTrackSession.takes.first.id, equals('take_persisted_1'));
        expect(vm2.multiTrackSession.takes.first.gain, closeTo(0.72, 0.001));
        expect(vm2.multiTrackSession.takes.first.spectralTrack.first.spectralCentroidHz, equals(710.0));

        vm1.dispose();
        vm2.dispose();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('US-4.6 UI sin Barras Falsas y Playhead Sincronizado en SpectralComparatorModal', () {
    testWidgets('PracticeRecordingPlayerModal no inventa 40 barras falsas cuando waveformPeaks esta vacio', (tester) async {
      final mockRecorder = MockPracticeRecorderService();
      final mockPlayback = MockAudioPlaybackService();
      final vm = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: mockRecorder,
        playbackService: mockPlayback,
        persistenceService: MemoryPersistenceService(),
        recordingPathProvider: () async => '/tmp/no_peaks.wav',
      );
      await tester.runAsync(() => vm.isInitialized);

      await vm.startPracticeRecording();
      await tester.pump(const Duration(milliseconds: 1100));
      await vm.stopPracticeRecording();

      expect(vm.activeRecording, isNotNull);
      expect(vm.activeRecording!.waveformPeaks, isEmpty);

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: const MaterialApp(
            home: Scaffold(
              body: PracticeRecordingPlayerModal(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sin forma de onda capturada'), findsOneWidget);
      vm.dispose();
    });

    testWidgets('SpectralComparatorModal pasa currentPlaybackPositionNormalized real a SpectralComparatorPainter', (tester) async {
      final mockPlayback = MockAudioPlaybackService();
      final vm = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: MockPracticeRecorderService(),
        playbackService: mockPlayback,
        persistenceService: MemoryPersistenceService(),
      );
      await vm.isInitialized;

      vm.addPracticeTake(
        PracticeTakeEntity(
          id: 'take_a',
          name: 'Toma A',
          timestamp: DateTime(2026, 11, 22, 10, 0),
          duration: const Duration(seconds: 4),
          filePath: '/tmp/take_a.wav',
          pitchTrack: const [
            TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 10.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 4000, frequencyHz: 440.0, centsDeviation: 5.0, targetNoteName: 'La4'),
          ],
          spectralTrack: const [
            TimedSpectralSample(timeMs: 0, spectralCentroidHz: 500.0, thdPercent: 1.5, rmsEnergy: 0.3),
            TimedSpectralSample(timeMs: 4000, spectralCentroidHz: 550.0, thdPercent: 1.6, rmsEnergy: 0.3),
          ],
        ),
      );
      vm.addPracticeTake(
        PracticeTakeEntity(
          id: 'take_b',
          name: 'Toma B',
          timestamp: DateTime(2026, 11, 22, 10, 2),
          duration: const Duration(seconds: 4),
          filePath: '/tmp/take_b.wav',
          pitchTrack: const [
            TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 2.0, targetNoteName: 'La4'),
            TimedPitchSample(timeMs: 4000, frequencyHz: 440.0, centsDeviation: -1.0, targetNoteName: 'La4'),
          ],
          spectralTrack: const [
            TimedSpectralSample(timeMs: 0, spectralCentroidHz: 800.0, thdPercent: 4.0, rmsEnergy: 0.4),
            TimedSpectralSample(timeMs: 4000, spectralCentroidHz: 850.0, thdPercent: 4.2, rmsEnergy: 0.4),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpectralComparatorModal(viewModel: vm),
          ),
        ),
      );
      await tester.pump();

      SpectralComparatorPainter findSpectralPainter() {
        final painters = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        return painters
            .map((w) => w.painter)
            .whereType<SpectralComparatorPainter>()
            .single;
      }

      expect(findSpectralPainter().currentPlaybackPositionNormalized, equals(0.0));

      // Iniciar audicion de Toma A y avanzar posicion a la mitad (2s de 4s)
      await tester.tap(find.byKey(const Key('audition_take_a_btn')));
      await tester.pump();

      mockPlayback.emitPosition(const Duration(seconds: 2));
      await tester.pump();

      expect(findSpectralPainter().currentPlaybackPositionNormalized, closeTo(0.5, 0.001));

      // Avanzar al final (4s de 4s)
      mockPlayback.emitPosition(const Duration(seconds: 4));
      await tester.pump();

      expect(findSpectralPainter().currentPlaybackPositionNormalized, closeTo(1.0, 0.001));

      // Detener reproduccion devuelve playhead a 0.0
      await vm.stopActiveRecordingPlayback();
      await tester.pump();

      expect(findSpectralPainter().currentPlaybackPositionNormalized, equals(0.0));
      vm.dispose();
    });
  });
}
