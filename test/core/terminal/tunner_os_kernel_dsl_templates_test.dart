import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_entity.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/domain/studio_master_clock_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_engine.dart';
import 'package:tunner/core/terminal/domain/tunner_os_kernel.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TunnerOsKernel DSL Templates Integration Tests', () {
    late TunnerOsKernel kernel;
    late StudioAudioDeviceMatrixService matrixService;
    late PolyphonicVoicePool synthVoicePool;
    late StudioMasterClockService clockService;

    setUp(() {
      final initialMatrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        availableInputs: [AudioDeviceEntity.systemDefault()],
        availableOutputs: [AudioDeviceEntity.defaultOutput()],
      );

      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: StudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        initialMatrix: initialMatrix,
      );

      synthVoicePool = PolyphonicVoicePool(
        maxPolyphony: 8,
        defaultWaveform: SynthWaveform.triangle,
      );

      clockService = StudioMasterClockService(initialBpm: 120.0);

      kernel = TunnerOsKernel(
        matrixService: matrixService,
        synthVoicePool: synthVoicePool,
        clockService: clockService,
      );
    });

    tearDown(() {
      matrixService.dispose();
      clockService.dispose();
      kernel.audioKernel?.dispose();
    });

    test('dsl list displays canonical catalog with all templates', () async {
      final result = await kernel.execute('dsl list');

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('[BIBLIOTECA CANONICA DE PLANTILLAS TUNNER DSL]'));
      expect(result.message, contains('ambient_chords'));
      expect(result.message, contains('acid_bassline'));
      expect(result.message, contains('vocal_warmup_routine'));
      expect(result.message, contains('dsl load ambient_chords'));
    });

    test('dsl templates alias works identically to dsl list', () async {
      final result = await kernel.execute('dsl templates');

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('[BIBLIOTECA CANONICA DE PLANTILLAS TUNNER DSL]'));
      expect(result.message, contains('acid_bassline'));
    });

    test('dsl load ambient_chords compiles and updates tempo to 72 BPM', () async {
      final result = await kernel.execute('dsl load ambient_chords');

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('[PLANTILLA CARGADA: Ambient Modal Chords & Spatial Reverb]'));
      expect(result.message, contains('[TUNNER DSL EXECUTION REPORT]'));
      expect(clockService.bpm, 72.0);
    });

    test('dsl load acid_bassline compiles and updates tempo to 135 BPM and synth to sawtooth', () async {
      final result = await kernel.execute('dsl load acid_bassline');

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('[PLANTILLA CARGADA: Acid Bassline 135 BPM]'));
      expect(clockService.bpm, 135.0);
      expect(synthVoicePool.waveform, SynthWaveform.sawtooth);
    });

    test('dsl load vocal_warmup_routine compiles and updates tempo to 96 BPM', () async {
      final result = await kernel.execute('dsl load vocal_warmup_routine');

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('[PLANTILLA CARGADA: Vocal Diatonic Warmup Routine]'));
      expect(clockService.bpm, 96.0);
      expect(synthVoicePool.waveform, SynthWaveform.sine);
    });

    test('dsl load unknown_template reports descriptive error with available options', () async {
      final result = await kernel.execute('dsl load non_existent_template');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains("Plantilla 'non_existent_template' no encontrada"));
      expect(result.message, contains('ambient_chords'));
    });

    test('dsl load without template id reports syntax error', () async {
      final result = await kernel.execute('dsl load');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Sintaxis: dsl load <plantilla_id>'));
    });

    test('dsl command without arguments shows usage syntax', () async {
      final result = await kernel.execute('dsl');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('dsl list | dsl load <plantilla>'));
    });
  });
}
