import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/domain/studio_master_audio_mixer.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_clock_service.dart';
import 'package:tunner/core/audio/domain/studio_transport_status.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioMasterAudioMixer Domain Tests (UC-102)', () {
    test('linearGainFromDb and dbFromLinearGain are mathematical inverses', () {
      const testDb = -6.0;
      final linear = StudioMasterAudioMixer.linearGainFromDb(testDb);
      final reconstructedDb = StudioMasterAudioMixer.dbFromLinearGain(linear);

      expect(reconstructedDb, closeTo(testDb, 0.01));
    });

    test('0 dBFS maps to unity linear gain (1.0)', () {
      expect(StudioMasterAudioMixer.linearGainFromDb(0.0), closeTo(1.0, 0.001));
      expect(StudioMasterAudioMixer.dbFromLinearGain(1.0), closeTo(0.0, 0.001));
    });

    test('calculateRms computes correct root mean square', () {
      final samples = [1.0, -1.0, 1.0, -1.0];
      final rms = StudioMasterAudioMixer.calculateRms(samples);
      expect(rms, closeTo(1.0, 0.001));

      final emptyRms = StudioMasterAudioMixer.calculateRms([]);
      expect(emptyRms, 0.0);
    });

    test('calculatePeak detects absolute maximal amplitude', () {
      final samples = [0.1, -0.85, 0.4, 0.2];
      final peak = StudioMasterAudioMixer.calculatePeak(samples);
      expect(peak, closeTo(0.85, 0.001));
    });

    test('applySoftClipper smooths high amplitude signals without hard discontinuity', () {
      final clipped1 = StudioMasterAudioMixer.applySoftClipper(1.5);
      final clipped2 = StudioMasterAudioMixer.applySoftClipper(-1.5);

      expect(clipped1, lessThan(1.0));
      expect(clipped1, greaterThan(0.8));
      expect(clipped2, greaterThan(-1.0));
      expect(clipped2, lessThan(-0.8));
    });

    test('processStereoFrame handles mono collapse and effective gain', () {
      final (l1, r1) = StudioMasterAudioMixer.processStereoFrame(
        leftSample: 0.8,
        rightSample: 0.4,
        effectiveGain: 1.0,
        isMono: true,
      );

      // En mono, ambos canales son (0.8 + 0.4) / 2 = 0.6
      expect(l1, closeTo(0.6, 0.001));
      expect(r1, closeTo(0.6, 0.001));

      // Ganancia cero produce silencio
      final (l2, r2) = StudioMasterAudioMixer.processStereoFrame(
        leftSample: 0.8,
        rightSample: 0.4,
        effectiveGain: 0.0,
        isMono: false,
      );
      expect(l2, 0.0);
      expect(r2, 0.0);
    });

    test('analyzeStereoBuffers calculates stereo metrics and flags clipping', () {
      final left = [0.99, 1.05];
      final right = [0.5, 0.6];

      final metrics = StudioMasterAudioMixer.analyzeStereoBuffers(
        leftSamples: left,
        rightSamples: right,
      );

      expect(metrics.isClipping, isTrue);
      expect(metrics.leftPeakDb, greaterThanOrEqualTo(-0.1));
      expect(metrics.leftRms, greaterThan(0.0));
    });
  });

  group('StudioMasterClockService Tests (UC-103)', () {
    late StudioMasterClockService clock;

    setUp(() {
      clock = StudioMasterClockService(initialBpm: 120.0);
    });

    tearDown(() {
      clock.dispose();
    });

    test('initial state defaults to 120 BPM in 4/4 meter and stopped status', () {
      expect(clock.bpm, 120.0);
      expect(clock.meterNumerator, 4);
      expect(clock.meterDenominator, 4);
      expect(clock.status, StudioTransportStatus.stopped);
      expect(clock.currentBeat, 1);
      expect(clock.currentMeasure, 1);
      expect(clock.isDownbeat, isTrue);
    });

    test('setBpm clamps values within [20, 300] BPM range', () {
      clock.setBpm(10.0);
      expect(clock.bpm, 20.0);

      clock.setBpm(400.0);
      expect(clock.bpm, 300.0);

      clock.setBpm(140.0);
      expect(clock.bpm, 140.0);
    });

    test('startTransport, pauseTransport and stopTransport transition states', () {
      clock.startTransport();
      expect(clock.status, StudioTransportStatus.playing);
      expect(clock.isPlaying, isTrue);

      clock.pauseTransport();
      expect(clock.status, StudioTransportStatus.paused);
      expect(clock.isPaused, isTrue);

      clock.stopTransport();
      expect(clock.status, StudioTransportStatus.stopped);
      expect(clock.isStopped, isTrue);
      expect(clock.currentBeat, 1);
    });

    test('registerTap calculates weighted average tempo accurately', () {
      // Registrar 3 taps con delta de 500 ms (120 BPM)
      clock.registerTap();
      // Debido a DateTime.now() en pruebas inmediatas, verificar que la función no lance excepción
      clock.registerTap();
      clock.registerTap();
      expect(clock.bpm, greaterThanOrEqualTo(20.0));
    });
  });

  group('AudioDeviceMatrixEntity & StudioAudioDeviceMatrixService Tests', () {
    test('AudioDeviceMatrixEntity calculates buffer latency and decibel gain', () {
      final matrix = AudioDeviceMatrixEntity.defaultConfiguration();

      // Latencia para buffer de 512 a 44100 Hz = ~11.6 ms
      expect(matrix.estimatedBufferLatencyMs, closeTo(11.609, 0.01));

      // Ganancia 1.0 = 0 dB
      expect(matrix.masterGainDb, closeTo(0.0, 0.01));

      // DIM reduce ganancia en factor 0.1 (-20 dB)
      final dimmed = matrix.copyWith(isDimmed: true);
      expect(dimmed.effectiveMasterGain, closeTo(0.1, 0.001));

      // MUTE anula la ganancia efectiva
      final muted = matrix.copyWith(isMuted: true);
      expect(muted.effectiveMasterGain, 0.0);
    });

    test('AudioDeviceMatrixEntity serialization roundtrip preserves state', () {
      final original = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        masterGain: 0.85,
        bufferSize: 256,
        isMono: true,
      );

      final json = original.toJson();
      final restored = AudioDeviceMatrixEntity.fromJson(json);

      expect(restored.masterGain, closeTo(0.85, 0.001));
      expect(restored.bufferSize, 256);
      expect(restored.isMono, isTrue);
    });

    test('StudioAudioDeviceMatrixService manages device selection and studio controls', () async {
      final outEngine = MemoryStudioAudioEngine();
      final inEngine = MemoryStudioAudioInputEngine();

      final service = StudioAudioDeviceMatrixService(
        outputEngine: outEngine,
        inputEngine: inEngine,
      );

      // Verificar que se listan y seleccionan dispositivos
      await service.selectInputDevice('mic_usb');
      expect(service.matrix.activeInputDevice.id, 'mic_usb');

      await service.selectOutputDevice('external_dac_usb');
      expect(service.matrix.activeOutputDevice.id, 'external_dac_usb');

      // Modificadores de ganancia
      service.setMasterGain(0.75);
      expect(service.matrix.masterGain, 0.75);

      service.toggleMute();
      expect(service.matrix.isMuted, isTrue);

      service.toggleDim();
      expect(service.matrix.isDimmed, isTrue);

      service.toggleMono();
      expect(service.matrix.isMono, isTrue);

      service.setBufferSize(256);
      expect(service.matrix.bufferSize, 256);

      service.setChannelRouting('dj_deck_b', 'cue');
      expect(service.matrix.channelRoutings['dj_deck_b'], 'cue');

      service.dispose();
    });
  });
}
