import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_pcm_frame.dart';
import 'package:tunner/core/audio/domain/audio_ring_buffer.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/features/tuner/data/pitch_detector_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRingBuffer Tests', () {
    test('Capacity rounds up to next power of two', () {
      final rb1 = AudioRingBuffer(requestedCapacity: 1000);
      expect(rb1.capacity, 1024);

      final rb2 = AudioRingBuffer(requestedCapacity: 4096);
      expect(rb2.capacity, 4096);

      final rb3 = AudioRingBuffer(requestedCapacity: 5000);
      expect(rb3.capacity, 8192);
    });

    test('Writing and reading data maintains exact sample values', () {
      final rb = AudioRingBuffer(requestedCapacity: 64);
      final input = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]);

      expect(rb.availableRead, 0);
      expect(rb.availableWrite, 64);

      final written = rb.write(input);
      expect(written, 5);
      expect(rb.availableRead, 5);
      expect(rb.availableWrite, 59);

      final readTarget = Float32List(5);
      final readCount = rb.read(readTarget);
      expect(readCount, 5);
      expect(readTarget[0], closeTo(0.1, 1e-5));
      expect(readTarget[4], closeTo(0.5, 1e-5));
      expect(rb.availableRead, 0);
    });

    test('Circular wrap-around operates smoothly across buffer boundary', () {
      final rb = AudioRingBuffer(requestedCapacity: 8); // Capacity = 8
      final chunk1 = Float32List.fromList([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      rb.write(chunk1);

      final temp = Float32List(4);
      rb.read(temp); // Consumes 1.0, 2.0, 3.0, 4.0; remaining: 5.0, 6.0
      expect(rb.availableRead, 2);

      // Write 4 more samples (crosses boundary)
      final chunk2 = Float32List.fromList([7.0, 8.0, 9.0, 10.0]);
      rb.write(chunk2);
      expect(rb.availableRead, 6);

      final output = Float32List(6);
      rb.read(output);
      expect(output, [5.0, 6.0, 7.0, 8.0, 9.0, 10.0]);
      expect(rb.availableRead, 0);
    });

    test('Peek inspects data without consuming read pointer', () {
      final rb = AudioRingBuffer(requestedCapacity: 16);
      rb.write(Float32List.fromList([0.25, 0.5, 0.75]));

      final peekBuf = Float32List(3);
      final peeked = rb.peek(peekBuf);
      expect(peeked, 3);
      expect(peekBuf[1], closeTo(0.5, 1e-5));
      expect(rb.availableRead, 3); // Still available!
    });

    test('Clear resets pointers and blanks buffer', () {
      final rb = AudioRingBuffer(requestedCapacity: 32);
      rb.write(Float32List.fromList([0.9, 0.8, 0.7]));
      expect(rb.availableRead, 3);

      rb.clear();
      expect(rb.availableRead, 0);
      expect(rb.availableWrite, 32);
    });
  });

  group('AudioPcmFrame Tests', () {
    test('Constructs normalized float samples from PCM 16-bit bytes', () {
      final byteData = ByteData(4);
      byteData.setInt16(0, 16384, Endian.little); // 16384 / 32768 = 0.5
      byteData.setInt16(2, -32768, Endian.little); // -32768 / 32768 = -1.0

      final frame = AudioPcmFrame.fromPcm16Bytes(
        bytes: byteData.buffer.asUint8List(),
        sampleRate: 44100,
      );

      expect(frame.samples.length, 2);
      expect(frame.samples[0], closeTo(0.5, 1e-4));
      expect(frame.samples[1], closeTo(-1.0, 1e-4));
      expect(frame.peakDb, greaterThan(-1.0));
      expect(frame.rmsDb, greaterThan(-10.0));
    });

    test('Silence frame produces -100 dBFS floor', () {
      final frame = AudioPcmFrame.silence(numSamples: 512);
      expect(frame.samples.length, 512);
      expect(frame.rmsDb, -100.0);
      expect(frame.peakDb, -100.0);
    });
  });

  group('StudioAudioInputEngine Tests', () {
    late MemoryStudioAudioInputEngine inputEngine;

    setUp(() {
      inputEngine = MemoryStudioAudioInputEngine();
    });

    tearDown(() {
      inputEngine.dispose();
    });

    test('listInputDevices enumerates physical and virtual interfaces', () async {
      final devices = await inputEngine.listInputDevices();
      expect(devices.isNotEmpty, isTrue);
      expect(devices.any((d) => d.id == 'default'), isTrue);
    });

    test('setInputDevice updates active device model', () async {
      await inputEngine.setInputDevice('mock_scarlett_usb');
      expect(inputEngine.currentDevice?.id, 'mock_scarlett_usb');
      expect(inputEngine.currentDevice?.label, contains('Focusrite Scarlett'));
    });

    test('startCapture and stopCapture cycle', () async {
      expect(inputEngine.isCapturing, isFalse);

      await inputEngine.startCapture(sampleRate: 44100, bufferSize: 512);
      expect(inputEngine.isCapturing, isTrue);

      await inputEngine.stopCapture();
      expect(inputEngine.isCapturing, isFalse);
    });

    test('emits AudioPcmFrame with real-time dBFS telemetry', () async {
      AudioPcmFrame? receivedFrame;
      double? receivedRms;

      final sub1 = inputEngine.pcmFrameStream.listen((f) => receivedFrame = f);
      final sub2 = inputEngine.rmsDbStream.listen((rms) => receivedRms = rms);

      final testFrame = AudioPcmFrame.fromPcm16Bytes(
        bytes: Uint8List.fromList([0x00, 0x40, 0x00, 0xC0]), // 0.5, -0.5
      );

      inputEngine.emitMockFrame(testFrame);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedFrame, isNotNull);
      expect(receivedFrame!.samples.length, 2);
      expect(receivedRms, isNotNull);
      expect(receivedRms!, greaterThan(-15.0));

      await sub1.cancel();
      await sub2.cancel();
    });
  });

  group('PitchDetectorService Core Input Integration Tests', () {
    test('PitchDetectorService lists devices via Core Audio Input Engine', () async {
      final memoryEngine = MemoryStudioAudioInputEngine();
      final pitchService = PitchDetectorService(inputEngine: memoryEngine);

      final devices = await pitchService.listInputDevices();
      expect(devices.isNotEmpty, isTrue);
      expect(devices.any((d) => d.contains('Focusrite') || d.contains('Predeterminado')), isTrue);
    });
  });
}
