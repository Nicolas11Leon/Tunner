import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';

void main() {
  group('US-1.2 Master DSP Chain, Real Ballistic VU Meter & Master Recording', () {
    late MemoryStudioAudioEngine outEngine;
    late MemoryStudioAudioInputEngine inEngine;
    late MemoryStudioMasterCaptureService captureService;
    late StudioAudioDeviceMatrixService matrixService;

    setUp(() {
      outEngine = MemoryStudioAudioEngine();
      inEngine = MemoryStudioAudioInputEngine();
      captureService = MemoryStudioMasterCaptureService();
      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: outEngine,
        inputEngine: inEngine,
        persistenceService: MemoryAudioHardwarePersistenceService(),
        captureService: captureService,
      );
    });

    tearDown(() {
      matrixService.dispose();
    });

    test('Zero signal decays ballistically to zero level without fake pseudo-values', () async {
      // Allow ballistic loop to settle on silence
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(matrixService.masterMeterData.leftRms, lessThanOrEqualTo(0.0001));
      expect(matrixService.masterMeterData.rightRms, lessThanOrEqualTo(0.0001));
    });

    test('processMasterStereoSamples computes real RMS, peak and broadcasts meter data', () {
      const sampleCount = 512;
      // 0.8 amplitude sine wave
      final left = List.generate(sampleCount, (i) => 0.8 * math.sin(2 * math.pi * i / 32));
      final right = List.generate(sampleCount, (i) => 0.5 * math.cos(2 * math.pi * i / 32));

      matrixService.processMasterStereoSamples(left, right);

      final meter = matrixService.masterMeterData;
      // Left channel has higher amplitude than right channel
      expect(meter.leftRms, greaterThan(meter.rightRms));
      expect(meter.leftRms, greaterThan(0.4));
      expect(meter.leftPeakDb, greaterThan(-3.0));
      expect(meter.rightPeakDb, lessThan(meter.leftPeakDb));
    });

    test('processMasterStereoSamples collapses stereo to mono when isMono is enabled', () {
      matrixService.toggleMono();
      expect(matrixService.matrix.isMono, isTrue);

      const sampleCount = 256;
      final left = List.filled(sampleCount, 0.8);
      final right = List.filled(sampleCount, 0.0);

      matrixService.processMasterStereoSamples(left, right);

      final meter = matrixService.masterMeterData;
      // In mono, left and right channels are identical (0.5 * 0.8 = 0.4)
      expect(meter.leftRms, closeTo(meter.rightRms, 0.01));
      expect(meter.leftPeakDb, closeTo(meter.rightPeakDb, 0.1));
    });

    test('processMasterStereoSamples silences to zero when isMuted is enabled', () {
      matrixService.toggleMute();
      expect(matrixService.matrix.isMuted, isTrue);

      const sampleCount = 256;
      final left = List.filled(sampleCount, 0.9);
      final right = List.filled(sampleCount, 0.9);

      matrixService.processMasterStereoSamples(left, right);

      final meter = matrixService.masterMeterData;
      expect(meter.leftRms, equals(0.0));
      expect(meter.rightRms, equals(0.0));
      expect(meter.leftPeakDb, equals(-96.0));
    });

    test('isMasterRecording writes processed stereo samples directly to capture service', () async {
      await matrixService.startMasterRecording('/tmp/test_master.wav');
      expect(matrixService.matrix.isMasterRecording, isTrue);
      expect(captureService.isCapturing, isTrue);

      const sampleCount = 256;
      final left = List.generate(sampleCount, (i) => 0.6);
      final right = List.generate(sampleCount, (i) => -0.6);

      matrixService.processMasterStereoSamples(left, right);

      expect(captureService.appendedSampleCount, equals(sampleCount));

      final savedPath = await matrixService.stopMasterRecording();
      expect(savedPath, equals('/tmp/test_master.wav'));
      expect(matrixService.matrix.isMasterRecording, isFalse);
    });
  });
}
