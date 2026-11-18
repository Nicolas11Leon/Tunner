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

  group('TunnerOsKernel DSL Integration Tests', () {
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

    test('dsl tempo command synchronizes clockService BPM', () async {
      final res = await kernel.execute('dsl tempo 142;');

      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[TUNNER DSL EXECUTION REPORT]'));
      expect(res.message, contains('Sentencias procesadas: 1'));
      expect(clockService.bpm, 142.0);
    });

    test('eval command sets master gain, EQ and synth parameters in hardware services', () async {
      // 1. Modula ganancia maestra
      final res1 = await kernel.execute('eval set @master.gain = -6.0 dB;');
      expect(res1.isSuccess, isTrue);
      expect(matrixService.matrix.masterGain, closeTo(0.501, 0.05));

      // 2. Modula ecualizador
      final res2 = await kernel.execute('dsl set @eq.low = 4.5 dB; set @eq.mid = -2.0 dB;');
      expect(res2.isSuccess, isTrue);
      expect(matrixService.matrix.eqLowDb, 4.5);
      expect(matrixService.matrix.eqMidDb, -2.0);

      // 3. Modula sintetizador
      final res3 = await kernel.execute('dsl set @synth.waveform = "saw"; set @synth.attack = 40 ms;');
      expect(res3.isSuccess, isTrue);
      expect(synthVoicePool.waveform, SynthWaveform.sawtooth);
      expect(synthVoicePool.attackSeconds, closeTo(0.04, 0.001));
    });

    test('dsl note command triggers synth voice in voice pool', () async {
      expect(synthVoicePool.activeVoiceCount, 0);

      final res = await kernel.execute('dsl note A4 1/4;');
      expect(res.isSuccess, isTrue);
      expect(synthVoicePool.activeVoiceCount, 1);
      final activeVoice = synthVoicePool.voices.firstWhere((v) => v.isActive);
      expect(activeVoice.noteNumber, 69);
      expect(activeVoice.frequency, 440.0);
    });

    test('dsl connect command configures virtual routing matrix', () async {
      final res = await kernel.execute('dsl connect @mic.in -> @cue.out;');

      expect(res.isSuccess, isTrue);
      expect(matrixService.matrix.channelRoutings['mic.in'], 'cue.out');
    });

    test('dsl command with syntax errors reports descriptive diagnostics without crashing', () async {
      final res = await kernel.execute('dsl tempo;'); // Falta valor numerico

      expect(res.isSuccess, isFalse);
      expect(res.message, contains('Error de sintaxis en script Tunner DSL'));
    });

    test('dsl command without arguments shows helpful usage instructions', () async {
      final res = await kernel.execute('dsl');

      expect(res.isSuccess, isFalse);
      expect(res.message, contains('Sintaxis: dsl <script> o eval <script>'));
    });
  });
}
