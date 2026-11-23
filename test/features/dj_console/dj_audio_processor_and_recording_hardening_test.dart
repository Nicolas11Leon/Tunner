import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/data/local_disk_studio_file_system_repository.dart';
import 'package:tunner/features/dj_console/data/dj_audio_processor.dart';
import 'package:tunner/features/dj_console/data/dj_mix_wav_encoder.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DjAudioProcessor 3-Band EQ and Recording Hardening Tests', () {
    late DjAudioProcessor processor;
    const sampleRate = 44100;

    setUp(() {
      processor = DjAudioProcessor(sampleRate: sampleRate);
    });

    test('apply3BandEq provides unity reconstruction when all bands are at 1.0', () {
      const len = 1024;
      final input = Float32List(len);
      for (int i = 0; i < len; i++) {
        input[i] = 0.5 * math.sin(2.0 * math.pi * 440.0 * (i / sampleRate));
      }

      final reconstructed = processor.apply3BandEq(
        input,
        eqLow: 1.0,
        eqMid: 1.0,
        eqHigh: 1.0,
      );

      expect(reconstructed.length, equals(len));
      for (int i = 0; i < len; i++) {
        expect(reconstructed[i], closeTo(input[i], 1e-4));
      }
    });

    test('apply3BandEq kills low frequencies when eqLow = 0.0', () {
      const len = 2048;
      final bassInput = Float32List(len);
      for (int i = 0; i < len; i++) {
        bassInput[i] = 0.8 * math.sin(2.0 * math.pi * 60.0 * (i / sampleRate)); // 60 Hz bass
      }

      final killedBass = processor.apply3BandEq(
        bassInput,
        eqLow: 0.0,
        eqMid: 1.0,
        eqHigh: 1.0,
      );

      double rms(Float32List buf) {
        double sum = 0.0;
        for (final s in buf) {
          sum += s * s;
        }
        return math.sqrt(sum / buf.length);
      }

      // Bass energy must be heavily attenuated (> 70% reduction)
      expect(rms(killedBass), lessThan(rms(bassInput) * 0.30));
    });

    test('DjMixWavEncoder produces canonical 44-byte RIFF header with 16-bit PCM', () {
      final samples = Float32List.fromList([0.0, 0.5, -0.5, 1.0, -1.0]);
      final wav = DjMixWavEncoder.encode(
        samples: samples,
        sampleRate: 44100,
        numChannels: 2,
      );

      expect(wav.length, equals(44 + (samples.length * 2)));
      expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(wav.sublist(12, 16)), equals('fmt '));
      expect(String.fromCharCodes(wav.sublist(36, 40)), equals('data'));
    });

    test('DjConsoleViewModel saveRecordingToDisk writes valid WAV file to disk', () async {
      final tempDir = Directory.systemTemp.createTempSync('tunner_dj_test_');
      final vm = DjConsoleViewModel(
        fileSystemRepository: LocalDiskStudioFileSystemRepository(customRootPath: tempDir.path),
      );
      final targetFile = '${tempDir.path}/test_mix.wav';

      try {
        vm.startRecording();
        expect(vm.recorder.isRecording, isTrue);

        // Advance recording with real chunk
        final chunk = Float32List.fromList([0.1, 0.2, -0.1, -0.2]);
        vm.orchestrator.appendRecordingChunk(chunk, DateTime.now().millisecondsSinceEpoch);

        final recordedBytes = vm.stopRecording();
        expect(recordedBytes, isNotNull);
        expect(recordedBytes!.isNotEmpty, isTrue);

        final saved = await vm.saveRecordingToDisk(targetFile);
        expect(saved, isTrue);

        final file = File(targetFile);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThanOrEqualTo(44));
      } finally {
        vm.dispose();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
