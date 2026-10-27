import 'dart:math' as math;
import 'dart:typed_data';

/// Generador matemático de audio digital en formato canónico RIFF/WAVE PCM.
/// Puro Dart: 100% libre de dependencias de Flutter o plugins de plataforma.
class PcmWavSynthesizer {
  const PcmWavSynthesizer();

  static const int defaultSampleRate = 44100;

  /// Construye la cabecera canónica RIFF/WAVE de 44 bytes para audio PCM Mono de 16 bits.
  static Uint8List buildWavHeader({
    required int pcmDataBytes,
    int sampleRate = defaultSampleRate,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final totalFileSize = 36 + pcmDataBytes;

    final header = ByteData(44);

    // 0..3: "RIFF"
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F

    // 4..7: Tamaño total del archivo menos 8 bytes (Little-Endian)
    header.setUint32(4, totalFileSize, Endian.little);

    // 8..11: "WAVE"
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // 12..15: "fmt "
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space

    // 16..19: Tamaño del sub-chunk fmt (16 para PCM)
    header.setUint32(16, 16, Endian.little);

    // 20..21: Formato de audio (1 = PCM sin compresión)
    header.setUint16(20, 1, Endian.little);

    // 22..23: Número de canales (1 = Mono)
    header.setUint16(22, channels, Endian.little);

    // 24..27: Frecuencia de muestreo (44100 Hz)
    header.setUint32(24, sampleRate, Endian.little);

    // 28..31: Byte Rate
    header.setUint32(28, byteRate, Endian.little);

    // 32..33: Block Align
    header.setUint16(32, blockAlign, Endian.little);

    // 34..35: Bits por muestra (16 bits)
    header.setUint16(34, bitsPerSample, Endian.little);

    // 36..39: "data"
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a

    // 40..43: Tamaño de los datos de audio en bytes
    header.setUint32(40, pcmDataBytes, Endian.little);

    return header.buffer.asUint8List();
  }

  /// Sintetiza un clic percusivo de metrónomo tipo bloque de madera (Woodblock).
  ///
  /// * [isDownbeat]: Si es true, genera el pulso 1 con acento orquestal ($2200\text{ Hz}$, $25\text{ ms}$).
  /// * Si es false, genera los pulsos secundarios ($1400\text{ Hz}$, $18\text{ ms}$).
  static Uint8List generateMetronomeClickWav({
    required bool isDownbeat,
    int sampleRate = defaultSampleRate,
  }) {
    final double frequency = isDownbeat ? 2200.0 : 1400.0;
    final double durationMs = isDownbeat ? 25.0 : 18.0;
    final double decayTau = isDownbeat ? 0.0055 : 0.0035;

    final int totalSamples = (sampleRate * (durationMs / 1000.0)).round();
    final pcmBytes = ByteData(totalSamples * 2);

    const double maxAmplitude = 30000.0; // Amplitud máxima en rango 16-bit signed (-32768..32767)

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      final double envelope = math.exp(-t / decayTau);
      final double sampleValue = maxAmplitude * envelope * math.sin(2.0 * math.pi * frequency * t);
      final int sampleClamped = sampleValue.clamp(-32768.0, 32767.0).round();
      pcmBytes.setInt16(i * 2, sampleClamped, Endian.little);
    }

    final header = buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final wavBuffer = BytesBuilder(copy: false);
    wavBuffer.add(header);
    wavBuffer.add(pcmBytes.buffer.asUint8List());
    return wavBuffer.toBytes();
  }

  /// Sintetiza una onda senoidal pura para el diapasón de concierto con envolvente suave ADSR.
  ///
  /// * [frequency]: Frecuencia exacta en hercios (ej. 440.0, 442.0, 432.0, 415.0).
  /// * [durationSeconds]: Duración del tono continuo. Por defecto 1.5 segundos en bucle.
  static Uint8List generateSineToneWav({
    required double frequency,
    double durationSeconds = 1.5,
    int sampleRate = defaultSampleRate,
  }) {
    final int totalSamples = (sampleRate * durationSeconds).round();
    final pcmBytes = ByteData(totalSamples * 2);

    const double maxAmplitude = 24000.0; // Amplitud confortable sin distorsión

    // Envolvente anti-pop: 15 ms de rampa ascendente y 20 ms de rampa descendente
    final int attackSamples = (sampleRate * 0.015).round();
    final int releaseSamples = (sampleRate * 0.020).round();
    final int releaseStartIndex = totalSamples - releaseSamples;

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;

      // Cálculo de envolvente de amplitud
      double envelope = 1.0;
      if (i < attackSamples) {
        envelope = i / attackSamples; // Rampa lineal de entrada
      } else if (i >= releaseStartIndex) {
        envelope = (totalSamples - i) / releaseSamples; // Rampa lineal de salida
      }

      final double sampleValue = maxAmplitude * envelope * math.sin(2.0 * math.pi * frequency * t);
      final int sampleClamped = sampleValue.clamp(-32768.0, 32767.0).round();
      pcmBytes.setInt16(i * 2, sampleClamped, Endian.little);
    }

    final header = buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final wavBuffer = BytesBuilder(copy: false);
    wavBuffer.add(header);
    wavBuffer.add(pcmBytes.buffer.asUint8List());
    return wavBuffer.toBytes();
  }
}
