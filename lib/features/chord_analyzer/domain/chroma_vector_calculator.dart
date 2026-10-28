import 'dart:math' as math;

/// Motor de extracción de características de cromagrama (Pitch Class Profile / Chroma Vectors).
/// Mapea la energía acústica continua en un vector normalizado de 12 clases cromáticas (C a B).
/// Emplea detección de picos espectrales con Supresión de No-Máximos (NMS) para eliminar
/// fugas espectrales de lóbulos laterales de ventana entre semitonos adyacentes.
/// Arquitectura de Dominio Puro en Dart: Cero dependencias de UI o plugins nativos.
class ChromaVectorCalculator {
  final int minMidiNote;
  final int maxMidiNote;

  const ChromaVectorCalculator({
    this.minMidiNote = 45, // A2 (~110.00 Hz)
    this.maxMidiNote = 88, // E6 (~1318.51 Hz)
  });

  /// Calcula el vector de cromagrama de 12 clases a partir de un búfer de muestras PCM normalizadas [-1.0, 1.0].
  List<double> calculateFromSamples({
    required List<double> samples,
    double sampleRate = 44100.0,
    double a4Ref = 440.0,
    double noiseGateRms = 0.008,
  }) {
    if (samples.length < 64) {
      return List.filled(12, 0.0);
    }

    // Comprobación de energía cuadrática media (RMS) para rechazo de silencio
    double sumSquares = 0.0;
    final int n = samples.length;
    for (int i = 0; i < n; i++) {
      sumSquares += samples[i] * samples[i];
    }
    final double rms = math.sqrt(sumSquares / n);
    if (rms < noiseGateRms) {
      return List.filled(12, 0.0);
    }

    // Límite de muestras analizadas para garantizar alta resolución espectral y ejecución determinista
    final int analysisLength = math.min(n, 4096);

    // Búfer de magnitudes en cada semitono MIDI analizado
    final rawMags = List<double>.filled(128, 0.0);

    for (int midi = minMidiNote; midi <= maxMidiNote; midi++) {
      final double freq = a4Ref * math.pow(2.0, (midi - 69) / 12.0);
      if (freq >= sampleRate / 2.0) continue;

      final double omega = 2.0 * math.pi * freq / sampleRate;
      double sumCos = 0.0;
      double sumSin = 0.0;

      for (int i = 0; i < analysisLength; i++) {
        // Envolvente de ventana Hann para mitigar fugas espectrales
        final double window = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (analysisLength - 1)));
        final double s = samples[i] * window;
        sumCos += s * math.cos(omega * i);
        sumSin += s * math.sin(omega * i);
      }

      rawMags[midi] = (2.0 / analysisLength) * math.sqrt(sumCos * sumCos + sumSin * sumSin);
    }

    // Aplicar Supresión de No-Máximos (NMS) a lo largo del eje cromático
    // para retener exclusivamente las componentes espectrales reales y descartar lóbulos laterales
    final chroma = List<double>.filled(12, 0.0);
    final double peakThreshold = math.max(0.02, rms * 0.15);

    for (int midi = minMidiNote + 1; midi < maxMidiNote; midi++) {
      final double cur = rawMags[midi];
      if (cur > rawMags[midi - 1] && cur > rawMags[midi + 1] && cur > peakThreshold) {
        final int pitchClass = midi % 12;
        chroma[pitchClass] += cur;
      }
    }

    return normalizeChroma(chroma);
  }

  /// Calcula el vector de cromagrama a partir de un espectro discreto de frecuencias y amplitudes.
  List<double> calculateFromFrequencies({
    required Map<double, double> frequencyAmplitudes,
    double a4Ref = 440.0,
  }) {
    final chroma = List<double>.filled(12, 0.0);

    for (final entry in frequencyAmplitudes.entries) {
      final double freq = entry.key;
      final double amp = entry.value;

      if (freq <= 20.0 || amp <= 0.0001) continue;

      // Cálculo del semitono MIDI continuo
      final double midi = 69.0 + 12.0 * (math.log(freq / a4Ref) / math.ln2);
      final int roundedMidi = midi.round();

      if (roundedMidi >= 21 && roundedMidi <= 108) {
        final int pitchClass = ((roundedMidi % 12) + 12) % 12;
        final double deviation = (midi - roundedMidi).abs();
        final double weight = math.max(0.0, 1.0 - deviation * 2.0);
        chroma[pitchClass] += amp * weight;
      }
    }

    return normalizeChroma(chroma);
  }

  /// Normaliza el vector de 12 clases a longitud euclídea unitaria L2.
  static List<double> normalizeChroma(List<double> rawChroma) {
    double sumSquares = 0.0;
    for (int i = 0; i < 12; i++) {
      sumSquares += rawChroma[i] * rawChroma[i];
    }

    final double norm = math.sqrt(sumSquares);
    if (norm < 1e-7) {
      return List.filled(12, 0.0);
    }

    return List<double>.generate(12, (i) => rawChroma[i] / norm);
  }
}
