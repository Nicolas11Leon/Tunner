import 'dart:math' as math;
import 'dart:typed_data';

/// Motor DSP en Pure Dart para modificación tonal mediante TD-PSOLA
/// (Time-Domain Pitch Synchronous Overlap-Add) con preservación de formantes.
class TdPsolaPitchShifter {
  const TdPsolaPitchShifter();

  /// Desplaza la afinación del buffer de audio [inputSamples] según [pitchShiftRatio]
  /// a la frecuencia fundamental [detectedPitchHz].
  Float64List shiftPitch({
    required Float64List inputSamples,
    required double pitchShiftRatio,
    required double detectedPitchHz,
    required int sampleRate,
    bool preserveFormants = true,
    double leadVocalMix = 1.0,
  }) {
    final int len = inputSamples.length;
    if (len == 0) return Float64List(0);

    // Bypass transparente si no hay tono vocal o el cambio es imperceptible
    if (detectedPitchHz <= 20.0 || (pitchShiftRatio - 1.0).abs() < 0.005) {
      if ((leadVocalMix - 1.0).abs() < 0.001) {
        return Float64List.fromList(inputSamples);
      }
    }

    final double effectivePitch = detectedPitchHz.clamp(50.0, 1500.0);
    final double rawP0 = sampleRate / effectivePitch;
    final int p0 = rawP0.round().clamp(16, len ~/ 3);

    // Periodo de síntesis modificado por el ratio de afinación
    final double rawPs = p0 / pitchShiftRatio.clamp(0.5, 2.0);
    final int ps = rawPs.round().clamp(8, len ~/ 2);

    // Si los periodos son inválidos, devolver copia
    if (p0 <= 0 || ps <= 0 || len < p0 * 2) {
      return Float64List.fromList(inputSamples);
    }

    // Ventana de análisis de Hann fija de tamaño 2*P0 para preservar la envolvente tímbrica
    final int winSize = p0 * 2;
    final Float64List window = Float64List(winSize);
    for (int i = 0; i < winSize; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / winSize));
    }

    // Identificación de marcas de análisis glótico sincrónicas (t_a)
    final List<int> analysisMarks = [];
    for (int t = p0; t < len - p0; t += p0) {
      // Búsqueda del pico local más prominente para anclar el instante de cierre glótico
      int bestT = t;
      double maxAmp = -1.0;
      final int searchRadius = (p0 * 0.25).round().clamp(2, 20);

      final int startSearch = (t - searchRadius).clamp(0, len - 1);
      final int endSearch = (t + searchRadius).clamp(0, len - 1);

      for (int k = startSearch; k <= endSearch; k++) {
        final double amp = inputSamples[k].abs();
        if (amp > maxAmp) {
          maxAmp = amp;
          bestT = k;
        }
      }
      analysisMarks.add(bestT);
    }

    if (analysisMarks.isEmpty) {
      return Float64List.fromList(inputSamples);
    }

    // Buffers de acumulación de síntesis y normalización
    final Float64List output = Float64List(len);
    final Float64List normWeights = Float64List(len);

    int synthMark = p0;
    while (synthMark < len - p0) {
      // Encontrar la marca de análisis más cercana a la posición temporal relativa
      final double relativePos = synthMark.toDouble();
      int nearestAnalysis = analysisMarks.first;
      double minDiff = (relativePos - nearestAnalysis).abs();

      for (int i = 1; i < analysisMarks.length; i++) {
        final double diff = (relativePos - analysisMarks[i]).abs();
        if (diff < minDiff) {
          minDiff = diff;
          nearestAnalysis = analysisMarks[i];
        } else {
          break; // Lista ordenada crecientemente
        }
      }

      // Superposición de grano con ventana de Hann (Overlap-Add)
      final int halfWin = p0;
      for (int i = -halfWin; i < halfWin; i++) {
        final int inIdx = nearestAnalysis + i;
        final int outIdx = synthMark + i;

        if (inIdx >= 0 && inIdx < len && outIdx >= 0 && outIdx < len) {
          final double w = window[i + halfWin];
          output[outIdx] += inputSamples[inIdx] * w;
          normWeights[outIdx] += w;
        }
      }

      synthMark += ps;
    }

    // Normalización de energía y mezcla dry/wet
    final double wet = leadVocalMix.clamp(0.0, 1.0);
    final double dry = 1.0 - wet;

    final Float64List finalBuffer = Float64List(len);
    for (int i = 0; i < len; i++) {
      double synthSample = 0.0;
      if (normWeights[i] > 1e-4) {
        synthSample = output[i] / normWeights[i];
      } else {
        synthSample = inputSamples[i];
      }

      // Mezcla Dry/Wet
      final double mixed = (inputSamples[i] * dry) + (synthSample * wet);
      finalBuffer[i] = mixed.clamp(-1.0, 1.0);
    }

    return finalBuffer;
  }
}
