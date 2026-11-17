import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_wav_capture_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StudioMasterCaptureService Tests (Épica 2 - UC-104)', () {
    test('creates a standard 44-byte WAV RIFF file with correct PCM samples', () async {
      final service = StudioMasterCaptureService();
      final destination = '${tempDir.path}/test_master_mix.wav';

      await service.startCapture(
        destinationPath: destination,
        sampleRate: 44100,
        channels: 2,
      );

      expect(service.isCapturing, isTrue);

      // Escribir 100 muestras estéreo (0.5 a la izquierda, -0.5 a la derecha)
      final left = List.filled(100, 0.5);
      final right = List.filled(100, -0.5);
      service.appendStereoSamples(left, right);

      final returnedPath = await service.stopCapture();
      expect(returnedPath, destination);
      expect(service.isCapturing, isFalse);

      final file = File(destination);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      // 44 bytes de cabecera + 100 muestras * 4 bytes (2 canales * 2 bytes/muestra) = 444 bytes
      expect(bytes.length, 444);

      final byteData = ByteData.sublistView(bytes);

      // Verificar cabecera RIFF
      expect(String.fromCharCode(byteData.getUint8(0)), 'R');
      expect(String.fromCharCode(byteData.getUint8(1)), 'I');
      expect(String.fromCharCode(byteData.getUint8(2)), 'F');
      expect(String.fromCharCode(byteData.getUint8(3)), 'F');

      // ChunkSize = 36 + 400 = 436
      expect(byteData.getUint32(4, Endian.little), 436);

      // "WAVE"
      expect(String.fromCharCode(byteData.getUint8(8)), 'W');
      expect(String.fromCharCode(byteData.getUint8(9)), 'A');
      expect(String.fromCharCode(byteData.getUint8(10)), 'V');
      expect(String.fromCharCode(byteData.getUint8(11)), 'E');

      // AudioFormat = 1 (PCM)
      expect(byteData.getUint16(20, Endian.little), 1);
      // Channels = 2
      expect(byteData.getUint16(22, Endian.little), 2);
      // SampleRate = 44100
      expect(byteData.getUint32(24, Endian.little), 44100);
      // Subchunk2Size (data size) = 400 bytes
      expect(byteData.getUint32(40, Endian.little), 400);

      // Verificar primera muestra PCM en 16-bit signed little-endian
      // 0.5 * 32767 = 16384 (aprox)
      final sampleL = byteData.getInt16(44, Endian.little);
      final sampleR = byteData.getInt16(46, Endian.little);
      expect(sampleL, closeTo(16384, 5));
      expect(sampleR, closeTo(-16384, 5));

      service.dispose();
    });
  });

  group('StudioAudioDeviceMatrixService Mastering & Recording Integration', () {
    test('updates EQ and dynamics parameters and persists changes', () async {
      final persistence = MemoryAudioHardwarePersistenceService();
      final capture = MemoryStudioMasterCaptureService();

      final matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: persistence,
        captureService: capture,
      );

      // 1. Modificar EQ
      matrixService.setEqLow(4.0);
      matrixService.setEqMid(-3.0);
      matrixService.setEqHigh(2.5);
      matrixService.toggleEqBypass();

      expect(matrixService.matrix.eqLowDb, 4.0);
      expect(matrixService.matrix.eqMidDb, -3.0);
      expect(matrixService.matrix.eqHighDb, 2.5);
      expect(matrixService.matrix.isEqBypassed, isTrue);

      // 2. Modificar Compresor
      matrixService.setCompThreshold(-15.0);
      matrixService.setCompRatio(4.0);
      matrixService.toggleCompBypass();

      expect(matrixService.matrix.compThresholdDb, -15.0);
      expect(matrixService.matrix.compRatio, 4.0);
      expect(matrixService.matrix.isCompBypassed, isTrue);

      // 3. Iniciar y detener grabación maestra
      expect(matrixService.matrix.isMasterRecording, isFalse);
      await matrixService.startMasterRecording('/tmp/dummy_recording.wav');
      expect(matrixService.matrix.isMasterRecording, isTrue);
      expect(capture.isCapturing, isTrue);

      final stoppedPath = await matrixService.stopMasterRecording();
      expect(matrixService.matrix.isMasterRecording, isFalse);
      expect(capture.isCapturing, isFalse);
      expect(stoppedPath, '/tmp/dummy_recording.wav');

      // 4. Verificar persistencia de valores
      final persisted = await persistence.loadMatrix();
      expect(persisted.eqLowDb, 4.0);
      expect(persisted.compThresholdDb, -15.0);

      matrixService.dispose();
    });
  });
}
