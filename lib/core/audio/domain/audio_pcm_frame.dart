import 'dart:math' as math;
import 'dart:typed_data';

/// Cuadro inmutable de audio PCM con muestras normalizadas en coma flotante
/// y metrología acústica calculada en decibelios Full Scale (dBFS).
class AudioPcmFrame {
  final Float32List samples;
  final Uint8List rawBytes;
  final int sampleRate;
  final int channels;
  final int timestampMicros;
  final double rmsDb;
  final double peakDb;

  const AudioPcmFrame({
    required this.samples,
    required this.rawBytes,
    required this.sampleRate,
    required this.channels,
    required this.timestampMicros,
    required this.rmsDb,
    required this.peakDb,
  });

  /// Construye un cuadro a partir de un buffer de bytes PCM crudos (16-bit little-endian con signo).
  factory AudioPcmFrame.fromPcm16Bytes({
    required Uint8List bytes,
    int sampleRate = 44100,
    int channels = 1,
    int? timestampMicros,
  }) {
    final numSamples = bytes.lengthInBytes ~/ 2;
    final samples = Float32List(numSamples);
    final byteData = ByteData.sublistView(bytes);

    double sumSquares = 0.0;
    double maxPeak = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final sampleInt16 = byteData.getInt16(i * 2, Endian.little);
      final normalized = (sampleInt16 / 32768.0).clamp(-1.0, 1.0);
      samples[i] = normalized;

      sumSquares += normalized * normalized;
      final absVal = normalized.abs();
      if (absVal > maxPeak) maxPeak = absVal;
    }

    final rms = numSamples > 0 ? math.sqrt(sumSquares / numSamples) : 0.0;
    final rmsDb = rms > 1e-5 ? (20.0 * math.log(rms) / math.ln10).clamp(-100.0, 0.0) : -100.0;
    final peakDb = maxPeak > 1e-5 ? (20.0 * math.log(maxPeak) / math.ln10).clamp(-100.0, 0.0) : -100.0;

    return AudioPcmFrame(
      samples: samples,
      rawBytes: bytes,
      sampleRate: sampleRate,
      channels: channels,
      timestampMicros: timestampMicros ?? DateTime.now().microsecondsSinceEpoch,
      rmsDb: rmsDb,
      peakDb: peakDb,
    );
  }

  /// Genera un cuadro de silencio digital de tamaño especificado.
  factory AudioPcmFrame.silence({
    int numSamples = 1024,
    int sampleRate = 44100,
    int channels = 1,
  }) {
    return AudioPcmFrame(
      samples: Float32List(numSamples),
      rawBytes: Uint8List(numSamples * 2),
      sampleRate: sampleRate,
      channels: channels,
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
      rmsDb: -100.0,
      peakDb: -100.0,
    );
  }
}
