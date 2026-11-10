import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _MockPitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _MockMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  group('Smart Instrument Tuner Integration Tests (UC-59)', () {
    late TunerViewModel viewModel;
    late MemoryAudioSynthesizerService memorySynthesizer;

    setUp(() async {
      memorySynthesizer = MemoryAudioSynthesizerService();
      viewModel = TunerViewModel(
        pitchService: _MockPitchService(),
        metronomeService: _MockMetroService(),
        persistenceService: MemoryPersistenceService(),
        audioSynthesizerService: memorySynthesizer,
      );
      await viewModel.isInitialized;
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Initial smart tuner state is inactive and idle', () {
      expect(viewModel.isSmartInstrumentTuningActive, isFalse);
      expect(viewModel.autoSwitchInstrumentEnabled, isFalse);
      expect(viewModel.lastDetectedMatch, isNull);
      expect(viewModel.activeInstrument.id, equals('flute'));
    });

    test('Toggles smart instrument tuning and auto-switch modes', () {
      viewModel.toggleSmartInstrumentTuning();
      expect(viewModel.isSmartInstrumentTuningActive, isTrue);

      viewModel.toggleAutoSwitchInstrument();
      expect(viewModel.autoSwitchInstrumentEnabled, isTrue);

      viewModel.toggleSmartInstrumentTuning();
      expect(viewModel.isSmartInstrumentTuningActive, isFalse);
      expect(viewModel.lastDetectedMatch, isNull);
    });

    test('Identifies Clarinet timbre and adapts profile, filter, and SoundFont patch', () {
      viewModel.toggleSmartInstrumentTuning();

      // Firma acústica de clarinete (rico en H3/H5, centroide moderado)
      final match = viewModel.evaluateSmartInstrumentAcoustics(
        freqHz: 261.63, // C4
        overtones: const [1.0, 0.08, 0.88, 0.06, 0.58, 0.04, 0.35, 0.02],
        clarity: 0.94,
        centroidHz: 780.0,
      );

      expect(match, isNotNull);
      expect(match!.instrument.id, equals('bb_clarinet'));
      expect(match.soundFontPatch, equals(71)); // GM Clarinet
      expect(viewModel.lastDetectedMatch, equals(match));
      // Auto-switch está desactivado por defecto, no debe cambiar activeInstrument aún
      expect(viewModel.activeInstrument.id, equals('flute'));

      // Aplicar adaptación interactiva sugerida
      viewModel.applyDetectedInstrumentMatch(match);
      expect(viewModel.activeInstrument.id, equals('bb_clarinet'));
      expect(viewModel.activeSoundFontPatch, equals(71));
    });

    test('Auto-switches instrument profile directly when autoSwitchInstrumentEnabled is true', () {
      viewModel.toggleSmartInstrumentTuning();
      viewModel.toggleAutoSwitchInstrument(); // Activar auto-adaptación directa

      expect(viewModel.activeInstrument.id, equals('flute'));

      // Firma acústica de trompeta (brillo metálico, centroide alto)
      final match = viewModel.evaluateSmartInstrumentAcoustics(
        freqHz: 440.0, // A4
        overtones: const [1.0, 0.85, 0.70, 0.55, 0.40, 0.28, 0.18, 0.10],
        clarity: 0.95,
        centroidHz: 1450.0,
      );

      expect(match, isNotNull);
      expect(match!.instrument.id, equals('bb_trumpet'));
      expect(viewModel.activeInstrument.id, equals('bb_trumpet'));
      expect(viewModel.activeSoundFontPatch, equals(56)); // GM Trumpet
    });

    test('Dismisses detected smart match when requested', () {
      viewModel.toggleSmartInstrumentTuning();
      final match = viewModel.evaluateSmartInstrumentAcoustics(
        freqHz: 261.63,
        overtones: const [1.0, 0.08, 0.88, 0.06, 0.58, 0.04, 0.35, 0.02],
        clarity: 0.94,
        centroidHz: 780.0,
      );
      expect(match, isNotNull);
      expect(viewModel.lastDetectedMatch, isNotNull);

      viewModel.dismissSmartInstrumentMatch();
      expect(viewModel.lastDetectedMatch, isNull);
    });
  });
}
