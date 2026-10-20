import 'dart:math';
import 'dart:typed_data';

/// Servicio de generación matemática de tonos de audio senoidales puros en formato PCM16 / WAV RIFF.
/// Opera 100% en memoria local sin dependencias de red ni librerías pesadas.
class ToneGeneratorService {
  static const int sampleRate = 44100;
  static const int bitsPerSample = 16;
  static const int numChannels = 1;

  /// Sintetiza un archivo WAV canónico en memoria para una frecuencia dada (en Hz),
  /// duración (en milisegundos) y con rampa de envolvente anti-pop (attack/release).
  static Uint8List generateSineWav({
    required double frequency,
    int durationMs = 1500,
    double volume = 0.5,
    int attackMs = 15,
    int releaseMs = 30,
  }) {
    if (frequency <= 0) return Uint8List(0);

    final int numSamples = ((sampleRate * durationMs) / 1000).round();
    final int attackSamples = ((sampleRate * attackMs) / 1000).round();
    final int releaseSamples = ((sampleRate * releaseMs) / 1000).round();
    final int releaseStart = max(0, numSamples - releaseSamples);

    final int dataChunkSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final int totalFileSize = 36 + dataChunkSize;

    final bytes = ByteData(44 + dataChunkSize);

    // 1. Encabezado RIFF canónico
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, totalFileSize, Endian.little);
    bytes.setUint8(8, 0x57);  // 'W'
    bytes.setUint8(9, 0x41);  // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // 2. Sub-chunk 'fmt '
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Tamaño del sub-chunk fmt (16 para PCM)
    bytes.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM lineal)
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    // ByteRate = SampleRate * NumChannels * BitsPerSample/8
    bytes.setUint32(28, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little);
    // BlockAlign = NumChannels * BitsPerSample/8
    bytes.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);

    // 3. Sub-chunk 'data'
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataChunkSize, Endian.little);

    // 4. Muestras PCM con Envolvente de Amplitud Anti-Pop
    const double twoPi = 2.0 * pi;
    final double maxInt16 = 32767.0 * volume.clamp(0.0, 1.0);

    int offset = 44;
    for (int n = 0; n < numSamples; n++) {
      // Cálculo de Envolvente lineal Attack / Release
      double envelope = 1.0;
      if (n < attackSamples && attackSamples > 0) {
        envelope = n / attackSamples;
      } else if (n >= releaseStart && releaseSamples > 0) {
        envelope = max(0.0, 1.0 - ((n - releaseStart) / releaseSamples));
      }

      // Muestra senoidal pura
      final double sampleValue = sin((twoPi * frequency * n) / sampleRate) * maxInt16 * envelope;
      final int int16Sample = sampleValue.round().clamp(-32768, 32767);

      bytes.setInt16(offset, int16Sample, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }
}
