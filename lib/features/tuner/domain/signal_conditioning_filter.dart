import 'dart:math' as math;
import 'dart:typed_data';
import 'microphone_calibration_models.dart';

/// Filtros y acondicionamiento digital de señal acústica (DSP) en Pure Dart.
class SignalConditioningFilter {
  /// Coeficiente del filtro IIR paso alto DC-blocker.
  /// $R = 1 - (2\pi \cdot f_c / f_s)$. Para $f_c = 15\text{ Hz}$ y $f_s = 44100\text{ Hz}$, $R \approx 0.9978$.
  static const double defaultDcBlockerPole = 0.99786;

  double _xPrev = 0.0;
  double _yPrev = 0.0;

  /// Restablece el estado interno del filtro recursivo.
  void reset() {
    _xPrev = 0.0;
    _yPrev = 0.0;
  }

  /// Aplica el filtro DC-Blocker IIR muestra a muestra:
  /// $y[n] = x[n] - x[n-1] + R \cdot y[n-1]$
  double processDcBlockerSample(double x, [double pole = defaultDcBlockerPole]) {
    final y = x - _xPrev + (pole * _yPrev);
    _xPrev = x;
    _yPrev = y;
    return y;
  }

  /// Procesa un arreglo de muestras de punto flotante en el lugar o generando una nueva copia:
  /// 1. Elimina la polarización DC (DC-offset) si [enableDcBlocker] es true.
  /// 2. Aplica el multiplicador de ganancia digital [gain].
  /// 3. Aplica un limitador suave tipo tangente hiperbólica si la señal supera 1.0 para evitar recortes bruscos.
  Float64List conditionSamples(
    Float64List input, {
    double gain = 1.0,
    bool enableDcBlocker = true,
  }) {
    final length = input.length;
    final output = Float64List(length);

    for (int i = 0; i < length; i++) {
      double s = input[i];

      if (enableDcBlocker) {
        s = processDcBlockerSample(s);
      }

      s *= gain;

      // Limitador suave analógico (soft saturation tanh) si rebasa los límites lineales
      if (s > 1.0) {
        s = 1.0 + (math.atan(s - 1.0) / (math.pi / 2)) * 0.1;
      } else if (s < -1.0) {
        s = -1.0 + (math.atan(s + 1.0) / (math.pi / 2)) * 0.1;
      }

      output[i] = s;
    }

    return output;
  }

  /// Analiza un conjunto de frames de audio tomados en silencio ambiental y genera un reporte
  /// estadístico para la configuración adaptativa del Noise Gate y la ganancia.
  static NoiseProfileReport analyzeNoiseFrames(List<Float64List> frames) {
    if (frames.isEmpty) {
      return const NoiseProfileReport(
        meanRms: 0.002,
        peakRms: 0.005,
        recommendedNoiseGate: 0.005,
        detectedDcOffset: 0.0,
        totalFramesAnalyzed: 0,
      );
    }

    double sumRms = 0.0;
    double maxRms = 0.0;
    double sumDc = 0.0;
    int totalSamples = 0;

    for (final frame in frames) {
      if (frame.isEmpty) continue;
      double frameSquares = 0.0;
      double frameSum = 0.0;

      for (int i = 0; i < frame.length; i++) {
        final sample = frame[i];
        frameSum += sample;
        frameSquares += sample * sample;
      }

      final frameRms = math.sqrt(frameSquares / frame.length);
      sumRms += frameRms;
      if (frameRms > maxRms) {
        maxRms = frameRms;
      }

      sumDc += frameSum;
      totalSamples += frame.length;
    }

    final meanRms = frames.isNotEmpty ? (sumRms / frames.length) : 0.002;
    final averageDc = totalSamples > 0 ? (sumDc / totalSamples) : 0.0;

    // Fórmula del umbral recomendado: 1.8 veces el RMS medio o el pico + margen de seguridad
    // Garantiza que la compuerta no caiga por debajo de 0.003 ni supere 0.080 en salas ruidosas
    final recommendedGate = math.max(0.003, math.min(0.080, math.max(meanRms * 1.8, maxRms * 1.15)));

    return NoiseProfileReport(
      meanRms: meanRms,
      peakRms: maxRms,
      recommendedNoiseGate: recommendedGate,
      detectedDcOffset: averageDc,
      totalFramesAnalyzed: frames.length,
    );
  }
}
