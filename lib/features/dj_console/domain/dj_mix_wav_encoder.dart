import 'dart:typed_data';

/// Canonical, lossless RIFF WAVE 16-bit PCM encoder for Tunner.
///
/// Encodes normalized floating-point audio buffers [-1.0, 1.0] into a valid
/// uncompressed .wav byte stream without external dependencies.
class DjMixWavEncoder {
  /// Encodes [samples] into a RIFF WAVE byte buffer.
  ///
  /// - [samples]: Normalized audio buffer in range [-1.0, 1.0].
  /// - [sampleRate]: Sampling frequency in Hz (defaults to 44100 Hz).
  /// - [numChannels]: Number of channels (1 for mono, 2 for stereo, defaults to 2).
  static Uint8List encode({
    required Float32List samples,
    int sampleRate = 44100,
    int numChannels = 2,
  }) {
    const bitsPerSample = 16;
    final bytesPerSample = bitsPerSample ~/ 8;
    final blockAlign = numChannels * bytesPerSample;
    final byteRate = sampleRate * blockAlign;
    final dataSize = samples.length * bytesPerSample;
    final fileSize = 36 + dataSize;

    final byteData = ByteData(44 + dataSize);

    // RIFF chunk descriptor
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // "fmt " subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat: 1 = PCM
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // "data" subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, dataSize, Endian.little);

    // Sample data conversion (Float32 to Int16 PCM)
    int offset = 44;
    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i].clamp(-1.0, 1.0);
      final intSample = (sample < 0.0)
          ? (sample * 32768.0).round().clamp(-32768, 32767)
          : (sample * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
}
