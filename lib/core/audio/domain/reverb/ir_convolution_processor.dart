import 'dart:math' as math;
import 'dart:typed_data';

/// Procesador de convolución directa de respuesta al impulso (IR) para post-producción acústica offline.
///
/// Modela matemáticamente la transformación de un recinto sobre una señal de audio discreta:
/// $$y[n] = (x * h)[n] = \sum_{k=0}^{M-1} x[n - k] \cdot h[k]$$
class IrConvolutionProcessor {
  const IrConvolutionProcessor();

  /// Aplica convolución lineal discreta entre una señal de audio y una respuesta al impulso.
  Float32List convolve(
    Float32List signal,
    Float32List impulseResponse, {
    bool normalize = true,
  }) {
    final signalLength = signal.length;
    final irLength = impulseResponse.length;

    if (signalLength == 0 || irLength == 0) {
      return Float32List(0);
    }

    final outputLength = signalLength + irLength - 1;
    final output = Float32List(outputLength);

    // Convolución directa en dominio temporal
    for (var i = 0; i < signalLength; i++) {
      final sample = signal[i];
      if (sample == 0.0) continue;

      for (var k = 0; k < irLength; k++) {
        output[i + k] += sample * impulseResponse[k];
      }
    }

    if (normalize) {
      var peak = 0.0;
      for (var i = 0; i < outputLength; i++) {
        final absVal = output[i].abs();
        if (absVal > peak) peak = absVal;
      }

      if (peak > 1.0) {
        final scale = 0.95 / peak;
        for (var i = 0; i < outputLength; i++) {
          output[i] *= scale;
        }
      }
    }

    return output;
  }

  /// Convoluciona un par estéreo L/R con respuestas al impulso independientes o idénticas.
  List<Float32List> convolveStereo(
    Float32List leftSignal,
    Float32List rightSignal,
    Float32List impulseResponse, {
    bool normalize = true,
  }) {
    final outLeft = convolve(leftSignal, impulseResponse, normalize: normalize);
    final outRight = convolve(rightSignal, impulseResponse, normalize: normalize);
    return [outLeft, outRight];
  }

  /// Genera una respuesta al impulso exponencial sintética en base a tiempo de decaimiento RT60.
  /// Útil para pruebas y como generador de recintos procedimentales.
  static Float32List generateSyntheticIr({
    required double rt60Seconds,
    required double sampleRate,
    double initialDelayMs = 0.0,
  }) {
    final totalSamples = (rt60Seconds * sampleRate).round();
    final delaySamples = ((initialDelayMs / 1000.0) * sampleRate).round();
    final ir = Float32List(totalSamples + delaySamples);

    final decayRate = -6.90775527898 / (rt60Seconds * sampleRate); // ln(0.001) para -60 dB
    final random = math.Random(42); // Semilla determinista

    for (var i = 0; i < totalSamples; i++) {
      final env = math.exp(decayRate * i);
      final noise = (random.nextDouble() * 2.0) - 1.0;
      ir[delaySamples + i] = (noise * env).toDouble();
    }

    return ir;
  }
}
