import 'dart:math' as math;
import 'dart:typed_data';

/// Resultado inmutable del análisis acústico de tono mediante McLeod Pitch Method (MPM).
class PitchDetectionResult {
  /// Indica si se detectó una altura tonal válida con claridad suficiente.
  final bool pitched;

  /// Frecuencia fundamental estimada en Hertz (Hz). 0.0 si no hay tono.
  final double pitchHz;

  /// Métrica de claridad y periodicidad del tono en el rango [0.0, 1.0].
  /// Derivada de la altura del pico de la función de correlación normalizada (NSDF).
  final double clarity;

  /// Valor cuadrático medio (RMS) de la amplitud de la señal en el rango [0.0, 1.0].
  final double rms;

  const PitchDetectionResult({
    required this.pitched,
    required this.pitchHz,
    required this.clarity,
    required this.rms,
  });

  const PitchDetectionResult.unpitched({this.rms = 0.0})
      : pitched = false,
        pitchHz = 0.0,
        clarity = 0.0;

  @override
  String toString() {
    return 'PitchDetectionResult(pitched: $pitched, pitchHz: ${pitchHz.toStringAsFixed(2)}, clarity: ${clarity.toStringAsFixed(3)}, rms: ${rms.toStringAsFixed(4)})';
  }
}

/// Implementación canónica y en Pure Dart del algoritmo McLeod Pitch Method (MPM)
/// para la estimación de alta fidelidad de la frecuencia fundamental en tiempo real.
///
/// Referencia:
/// Philip McLeod and Geoff Wyvill (2005). "A Smarter Way to Find Pitch".
/// ICMC Proceedings, International Computer Music Conference.
class McleodPitchMethod {
  /// Umbral dinámico relativo para el primer pico local (típicamente 0.85 a 0.93).
  /// Previene eficazmente los errores de salto de octava ("octave jumps").
  final double kThreshold;

  /// Umbral mínimo absoluto de claridad para considerar un pico como armónicamente válido.
  final double minClarity;

  /// Umbral de corte de potencia RMS para el Noise Gate (silencio acústico).
  final double silenceThreshold;

  /// Frecuencia mínima detectable en Hz (por defecto 25 Hz, cubre hasta La0 = 27.5 Hz).
  final double minPitchHz;

  /// Frecuencia máxima detectable en Hz (por defecto 4200 Hz, cubre hasta Do8 = 4186 Hz).
  final double maxPitchHz;

  const McleodPitchMethod({
    this.kThreshold = 0.90,
    this.minClarity = 0.40,
    this.silenceThreshold = 0.005, // Aprox. -46 dBFS
    this.minPitchHz = 25.0,
    this.maxPitchHz = 4200.0,
  });

  /// Convierte un buffer de bytes PCM de 16 bits little-endian a un arreglo
  /// de muestras normalizadas de punto flotante en el rango [-1.0, 1.0].
  static Float64List convertPcm16BytesToFloats(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final floats = Float64List(sampleCount);
    final byteData = ByteData.sublistView(bytes);

    for (int i = 0; i < sampleCount; i++) {
      final sampleInt16 = byteData.getInt16(i * 2, Endian.little);
      floats[i] = sampleInt16 / 32768.0;
    }
    return floats;
  }

  /// Calcula el valor eficaz acústico (Root Mean Square - RMS) de la señal.
  static double calculateRms(Float64List samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      sumSquares += s * s;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Calcula la Función de Diferencia Cuadrada Normalizada (NSDF) r'(tau)
  /// para el rango de retardos tau = [0, maxLag].
  ///
  /// Fórmula:
  /// r'(tau) = (2 * sum(x[j] * x[j+tau])) / sum(x[j]^2 + x[j+tau]^2)
  static Float64List computeNsdf(Float64List samples, int maxLag) {
    final n = samples.length;
    final clampedMaxLag = math.min(maxLag, n - 2);
    if (clampedMaxLag <= 0) return Float64List(0);

    final nsdf = Float64List(clampedMaxLag + 1);
    nsdf[0] = 1.0; // r'(0) siempre es exactamente 1.0

    for (int tau = 1; tau <= clampedMaxLag; tau++) {
      double crossCorrelation = 0.0;
      double energySum = 0.0;

      final limit = n - tau;
      for (int j = 0; j < limit; j++) {
        final xj = samples[j];
        final xjTau = samples[j + tau];
        crossCorrelation += xj * xjTau;
        energySum += xj * xj + xjTau * xjTau;
      }

      if (energySum > 1e-12) {
        final val = (2.0 * crossCorrelation) / energySum;
        nsdf[tau] = val.clamp(-1.0, 1.0);
      } else {
        nsdf[tau] = 0.0;
      }
    }

    return nsdf;
  }

  /// Estima la frecuencia fundamental de un buffer de audio en punto flotante.
  PitchDetectionResult estimatePitch(
    Float64List samples, {
    int sampleRate = 44100,
  }) {
    if (samples.length < 64) {
      return const PitchDetectionResult.unpitched();
    }

    final rms = calculateRms(samples);
    if (rms < silenceThreshold) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    // El retardo máximo se determina por la frecuencia mínima que se desea detectar
    final maxLagForMinPitch = (sampleRate / minPitchHz).ceil();
    // El retardo mínimo se determina por la frecuencia máxima detectable
    final minLagForMaxPitch = math.max(1, (sampleRate / maxPitchHz).floor());

    final maxLag = math.min(maxLagForMinPitch, samples.length - 2);
    if (maxLag <= minLagForMaxPitch) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    final nsdf = computeNsdf(samples, maxLag);
    if (nsdf.isEmpty) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    // Detección de picos en lóbulos positivos
    final peaks = <int>[];
    bool inPositiveLobe = false;
    int currentPeakIdx = -1;
    double currentPeakVal = -1.0;

    for (int tau = minLagForMaxPitch; tau < nsdf.length - 1; tau++) {
      final val = nsdf[tau];

      if (val > 0) {
        if (!inPositiveLobe) {
          inPositiveLobe = true;
          currentPeakIdx = tau;
          currentPeakVal = val;
        } else if (val > currentPeakVal) {
          currentPeakIdx = tau;
          currentPeakVal = val;
        }
      } else {
        if (inPositiveLobe) {
          if (currentPeakIdx > 0 &&
              currentPeakIdx < nsdf.length - 1 &&
              nsdf[currentPeakIdx] >= nsdf[currentPeakIdx - 1] &&
              nsdf[currentPeakIdx] >= nsdf[currentPeakIdx + 1]) {
            peaks.add(currentPeakIdx);
          }
          inPositiveLobe = false;
          currentPeakIdx = -1;
          currentPeakVal = -1.0;
        }
      }
    }

    // Si terminó dentro de un lóbulo positivo
    if (inPositiveLobe && currentPeakIdx > 0 && currentPeakIdx < nsdf.length - 1) {
      if (nsdf[currentPeakIdx] >= nsdf[currentPeakIdx - 1] &&
          nsdf[currentPeakIdx] >= nsdf[currentPeakIdx + 1]) {
        peaks.add(currentPeakIdx);
      }
    }

    if (peaks.isEmpty) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    // Encontrar el valor del pico máximo global
    double maxPeakValue = 0.0;
    for (final p in peaks) {
      if (nsdf[p] > maxPeakValue) {
        maxPeakValue = nsdf[p];
      }
    }

    if (maxPeakValue < minClarity) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    // Dynamic Peak Picking: seleccionar el PRIMER pico que supere kThreshold * maxPeakValue
    final cutoff = maxPeakValue * kThreshold;
    int selectedPeak = -1;
    for (final p in peaks) {
      if (nsdf[p] >= cutoff) {
        selectedPeak = p;
        break;
      }
    }

    if (selectedPeak == -1) {
      selectedPeak = peaks.first;
    }

    // Interpolación parabólica sub-muestra alrededor de selectedPeak
    final p = selectedPeak;
    final alpha = nsdf[p - 1];
    final beta = nsdf[p];
    final gamma = nsdf[p + 1];

    final denominator = 2.0 * (alpha - 2.0 * beta + gamma);
    double delta = 0.0;
    if (denominator.abs() > 1e-12) {
      delta = (alpha - gamma) / denominator;
    }

    final tauExact = p + delta;
    if (tauExact <= 0) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    final pitchHz = sampleRate / tauExact;
    final clarity = (beta - 0.25 * (alpha - gamma) * delta).clamp(0.0, 1.0);

    if (pitchHz < minPitchHz || pitchHz > maxPitchHz) {
      return PitchDetectionResult.unpitched(rms: rms);
    }

    return PitchDetectionResult(
      pitched: true,
      pitchHz: pitchHz,
      clarity: clarity,
      rms: rms,
    );
  }

  /// Conveniencia: analiza directamente un buffer binario PCM de 16 bits.
  PitchDetectionResult estimatePitchFromPcm16(
    Uint8List pcmBytes, {
    int sampleRate = 44100,
  }) {
    final floatSamples = convertPcm16BytesToFloats(pcmBytes);
    return estimatePitch(floatSamples, sampleRate: sampleRate);
  }
}
