import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/offline_wav_decoder.dart';

Uint8List _buildTestWav({
  required int audioFormat,
  required int bitsPerSample,
  required int channels,
  required int sampleRate,
  required List<List<double>> channelSamples,
  bool includeJunkChunk = false,
}) {
  final int frames = channelSamples.first.length;
  final int bytesPerSample = bitsPerSample ~/ 8;
  final int dataSize = frames * channels * bytesPerSample;
  final Uint8List dataBytes = Uint8List(dataSize);
  final ByteData dataView = ByteData.sublistView(dataBytes);

  for (int frame = 0; frame < frames; frame++) {
    for (int ch = 0; ch < channels; ch++) {
      final double v = channelSamples[ch][frame].clamp(-1.0, 1.0);
      final int offset = (frame * channels + ch) * bytesPerSample;
      if (audioFormat == 1 && bitsPerSample == 16) {
        final int s16 = (v * 32767.0).round().clamp(-32768, 32767);
        dataView.setInt16(offset, s16, Endian.little);
      } else if (audioFormat == 1 && bitsPerSample == 24) {
        final int s24 = (v * 8388607.0).round().clamp(-8388608, 8388607);
        dataBytes[offset] = s24 & 0xFF;
        dataBytes[offset + 1] = (s24 >> 8) & 0xFF;
        dataBytes[offset + 2] = (s24 >> 16) & 0xFF;
      } else if (audioFormat == 3 && bitsPerSample == 32) {
        dataView.setFloat32(offset, v, Endian.little);
      }
    }
  }

  final builder = BytesBuilder(copy: false);
  final int junkBytes = includeJunkChunk ? 12 : 0; // 8 header + 4 payload
  final int riffSize = 4 + (8 + 16) + junkBytes + (8 + dataSize);

  final header = ByteData(12);
  builder.add('RIFF'.codeUnits);
  header.setUint32(0, riffSize, Endian.little);
  builder.add(header.buffer.asUint8List(0, 4));
  builder.add('WAVE'.codeUnits);

  if (includeJunkChunk) {
    builder.add('JUNK'.codeUnits);
    final junkSize = ByteData(4)..setUint32(0, 4, Endian.little);
    builder.add(junkSize.buffer.asUint8List());
    builder.add(Uint8List(4));
  }

  // fmt chunk
  builder.add('fmt '.codeUnits);
  final fmt = ByteData(20);
  fmt.setUint32(0, 16, Endian.little);
  fmt.setUint16(4, audioFormat, Endian.little);
  fmt.setUint16(6, channels, Endian.little);
  fmt.setUint32(8, sampleRate, Endian.little);
  fmt.setUint32(12, sampleRate * channels * bytesPerSample, Endian.little);
  fmt.setUint16(16, channels * bytesPerSample, Endian.little);
  fmt.setUint16(18, bitsPerSample, Endian.little);
  builder.add(fmt.buffer.asUint8List());

  // data chunk
  builder.add('data'.codeUnits);
  final dataHeader = ByteData(4)..setUint32(0, dataSize, Endian.little);
  builder.add(dataHeader.buffer.asUint8List());
  builder.add(dataBytes);

  return builder.toBytes();
}

void main() {
  group('OfflineWavDecoder Pure Dart Codec Tests', () {
    test('Decodifica PCM 16-bit mono correctamente', () {
      const int sr = 44100;
      final input = List<double>.generate(
        512,
        (i) => 0.75 * math.sin(2.0 * math.pi * 440.0 * i / sr),
      );
      final wav = _buildTestWav(
        audioFormat: 1,
        bitsPerSample: 16,
        channels: 1,
        sampleRate: sr,
        channelSamples: [input],
      );

      final decoded = OfflineWavDecoder.decode(wav);
      expect(decoded.sampleRate, equals(sr));
      expect(decoded.channels, equals(1));
      expect(decoded.bitsPerSample, equals(16));
      expect(decoded.frameCount, equals(512));
      expect(decoded.durationSeconds, closeTo(512 / sr, 1e-6));
      expect(decoded.isStereo, isFalse);
      expect(decoded.isFloat, isFalse);

      for (int i = 0; i < 512; i++) {
        expect(decoded.samples[i], closeTo(input[i], 0.001));
      }
    });

    test('Decodifica PCM 24-bit estereo con downmix mono y canales separados', () {
      const int sr = 48000;
      final left = List<double>.generate(256, (i) => i.isEven ? 0.5 : -0.5);
      final right = List<double>.generate(256, (i) => i.isEven ? -0.1 : 0.9);
      final wav = _buildTestWav(
        audioFormat: 1,
        bitsPerSample: 24,
        channels: 2,
        sampleRate: sr,
        channelSamples: [left, right],
        includeJunkChunk: true,
      );

      final decoded = OfflineWavDecoder.decode(wav);
      expect(decoded.sampleRate, equals(sr));
      expect(decoded.channels, equals(2));
      expect(decoded.bitsPerSample, equals(24));
      expect(decoded.isStereo, isTrue);
      expect(decoded.channelSamples.length, equals(2));

      for (int i = 0; i < 256; i++) {
        expect(decoded.channelSamples[0][i], closeTo(left[i], 1e-5));
        expect(decoded.channelSamples[1][i], closeTo(right[i], 1e-5));
        expect(decoded.samples[i], closeTo((left[i] + right[i]) * 0.5, 1e-5));
      }
    });

    test('Decodifica IEEE Float 32-bit estereo con alta precision', () {
      const int sr = 44100;
      final left = List<double>.generate(
        200,
        (i) => 0.8 * math.sin(2.0 * math.pi * 220.0 * i / sr),
      );
      final right = List<double>.generate(
        200,
        (i) => 0.4 * math.cos(2.0 * math.pi * 220.0 * i / sr),
      );
      final wav = _buildTestWav(
        audioFormat: 3,
        bitsPerSample: 32,
        channels: 2,
        sampleRate: sr,
        channelSamples: [left, right],
      );

      final decoded = OfflineWavDecoder.decode(wav);
      expect(decoded.sampleRate, equals(sr));
      expect(decoded.channels, equals(2));
      expect(decoded.bitsPerSample, equals(32));
      expect(decoded.isFloat, isTrue);

      for (int i = 0; i < 200; i++) {
        expect(decoded.channelSamples[0][i], closeTo(left[i], 1e-5));
        expect(decoded.channelSamples[1][i], closeTo(right[i], 1e-5));
        expect(decoded.samples[i], closeTo((left[i] + right[i]) * 0.5, 1e-5));
      }
    });

    test('Lanza FormatException ante buffers corruptos o formatos no soportados', () {
      expect(
        () => OfflineWavDecoder.decode(Uint8List(16)),
        throwsA(isA<FormatException>()),
      );

      final badHeader = Uint8List(64);
      expect(
        () => OfflineWavDecoder.decode(badHeader),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
