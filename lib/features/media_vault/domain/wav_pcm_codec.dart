import 'dart:math' as math;
import 'dart:typed_data';

/// Decoded PCM representation of a RIFF/WAVE audio file.
class DecodedWavPcm {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Float64List monoSamples;

  const DecodedWavPcm({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.monoSamples,
  });

  int get durationMs {
    if (sampleRate <= 0 || monoSamples.isEmpty) {
      return 0;
    }
    return ((monoSamples.length / sampleRate) * 1000.0).round();
  }
}

/// Pure Dart RIFF/WAVE PCM 16-bit encoder/decoder for 100% offline lossless
/// audio import, waveform extraction, and multi-track timeline mixdown export.
class WavPcmCodec {
  /// Standard 44-byte RIFF/WAVE PCM header size.
  static const int standardHeaderBytes = 44;

  /// PCM audio format code in RIFF `fmt ` subchunk.
  static const int pcmFormatTag = 1;

  /// Maximum positive signed 16-bit integer amplitude (`2^15 - 1`).
  static const double int16MaxAmplitude = 32767.0;

  const WavPcmCodec();

  /// Encodes normalized mono [samples] in [-1.0, 1.0] into a valid 16-bit
  /// RIFF/WAVE byte buffer.
  Uint8List encodeMono16Bit(
    Float64List samples, {
    int sampleRate = 44100,
  }) {
    const int channels = 1;
    const int bitsPerSample = 16;
    const int bytesPerSample = bitsPerSample ~/ 8;
    final int dataSize = samples.length * bytesPerSample;
    final int totalSize = standardHeaderBytes + dataSize;

    final buffer = Uint8List(totalSize);
    final view = ByteData.view(buffer.buffer);

    // "RIFF" chunk descriptor
    buffer.setRange(0, 4, 'RIFF'.codeUnits);
    view.setUint32(4, 36 + dataSize, Endian.little);
    buffer.setRange(8, 12, 'WAVE'.codeUnits);

    // "fmt " subchunk
    buffer.setRange(12, 16, 'fmt '.codeUnits);
    view.setUint32(16, 16, Endian.little); // PCM subchunk size
    view.setUint16(20, pcmFormatTag, Endian.little);
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(
      28,
      sampleRate * channels * bytesPerSample,
      Endian.little,
    );
    view.setUint16(32, channels * bytesPerSample, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);

    // "data" subchunk
    buffer.setRange(36, 40, 'data'.codeUnits);
    view.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final pcmInt = (clamped * int16MaxAmplitude).round();
      view.setInt16(standardHeaderBytes + (i * 2), pcmInt, Endian.little);
    }

    return buffer;
  }

  /// Decodes a 16-bit PCM RIFF/WAVE file into normalized mono [Float64List].
  /// Returns `null` if the header is invalid or unsupported.
  DecodedWavPcm? decode(Uint8List bytes) {
    if (bytes.length < standardHeaderBytes) {
      return null;
    }
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') {
      return null;
    }

    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    int offset = 12;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? audioFormat;
    int? dataOffset;
    int? dataLength;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = view.getUint32(offset + 4, Endian.little);
      final payloadStart = offset + 8;

      if (chunkId == 'fmt ' && payloadStart + 16 <= bytes.length) {
        audioFormat = view.getUint16(payloadStart, Endian.little);
        channels = view.getUint16(payloadStart + 2, Endian.little);
        sampleRate = view.getUint32(payloadStart + 4, Endian.little);
        bitsPerSample = view.getUint16(payloadStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = payloadStart;
        dataLength = math.min(chunkSize, bytes.length - payloadStart);
        break;
      }

      offset = payloadStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat != pcmFormatTag ||
        channels == null ||
        channels <= 0 ||
        sampleRate == null ||
        sampleRate <= 0 ||
        bitsPerSample == null ||
        bitsPerSample != 16 ||
        dataOffset == null ||
        dataLength == null ||
        dataLength < 2) {
      return null;
    }

    final frameBytes = channels * 2;
    final frameCount = dataLength ~/ frameBytes;
    final mono = Float64List(frameCount);

    for (int f = 0; f < frameCount; f++) {
      double sum = 0.0;
      for (int ch = 0; ch < channels; ch++) {
        final sampleOffset = dataOffset + (f * frameBytes) + (ch * 2);
        final rawInt = view.getInt16(sampleOffset, Endian.little);
        sum += rawInt / int16MaxAmplitude;
      }
      mono[f] = (sum / channels).clamp(-1.0, 1.0);
    }

    return DecodedWavPcm(
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      monoSamples: mono,
    );
  }

  /// Extracts downsampled peak amplitudes in [0.0, 1.0] for fast timeline UI painting.
  List<double> extractPeaks(Float64List samples, {int bucketCount = 64}) {
    if (samples.isEmpty || bucketCount <= 0) {
      return const <double>[];
    }
    final step = math.max(1, samples.length ~/ bucketCount);
    final peaks = <double>[];
    for (int i = 0; i < samples.length && peaks.length < bucketCount; i += step) {
      double maxAbs = 0.0;
      final end = math.min(samples.length, i + step);
      for (int j = i; j < end; j++) {
        final a = samples[j].abs();
        if (a > maxAbs) {
          maxAbs = a;
        }
      }
      peaks.add(maxAbs.clamp(0.0, 1.0));
    }
    return peaks;
  }
}
