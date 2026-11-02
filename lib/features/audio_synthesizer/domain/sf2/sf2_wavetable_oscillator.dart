import 'dart:math' as math;
import 'dart:typed_data';
import 'sf2_models.dart';

/// Parámetros calculados de la envolvente de volumen VolEG.
class Sf2EnvelopeParams {
  final double delaySeconds;
  final double attackSeconds;
  final double holdSeconds;
  final double decaySeconds;
  final double sustainLevel; // 0.0 a 1.0 (amplitud)
  final double releaseSeconds;

  const Sf2EnvelopeParams({
    this.delaySeconds = 0.001,
    this.attackSeconds = 0.015,
    this.holdSeconds = 0.010,
    this.decaySeconds = 0.400,
    this.sustainLevel = 0.40,
    this.releaseSeconds = 0.080,
  });

  /// Convierte timecents de SoundFont a segundos: $t = 2^{\frac{tc}{1200}}$.
  static double timecentsToSeconds(int timecents) {
    if (timecents <= -32768) return 0.001;
    final sec = math.pow(2.0, timecents / 1200.0).toDouble();
    return sec.clamp(0.0005, 30.0);
  }

  /// Convierte centibeles de atenuación a ganancia lineal: $G = 10^{-\frac{cb}{200}}$.
  static double centibelsToGain(int centibels) {
    if (centibels >= 1000) return 0.0;
    return math.pow(10.0, -centibels / 200.0).toDouble().clamp(0.0, 1.0);
  }
}

/// Oscilador wavetable con interpolación cúbica de Hermite (4-point spline)
/// y generador de envolvente SoundFont VolEG.
class Sf2WavetableOscillator {
  const Sf2WavetableOscillator();

  /// Interpola una muestra usando Hermite de 4 puntos para máxima pureza espectral.
  ///
  /// Fórmula canónica:
  /// $c_0 = y_1$
  /// $c_1 = 0.5 \cdot (y_2 - y_0)$
  /// $c_2 = y_0 - 2.5 \cdot y_1 + 2.0 \cdot y_2 - 0.5 \cdot y_3$
  /// $c_3 = 0.5 \cdot (y_3 - y_0) + 1.5 \cdot (y_1 - y_2)$
  /// $y(t) = ((c_3 \cdot t + c_2) \cdot t + c_1) \cdot t + c_0$
  static double interpolateHermite4(double y0, double y1, double y2, double y3, double t) {
    final c0 = y1;
    final c1 = 0.5 * (y2 - y0);
    final c2 = y0 - 2.5 * y1 + 2.0 * y2 - 0.5 * y3;
    final c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2);
    return ((c3 * t + c2) * t + c1) * t + c0;
  }

  /// Evalúa el multiplicador de amplitud de la envolvente VolEG en el tiempo $t$ (segundos).
  static double evaluateVolEg(double t, double noteDurationSeconds, Sf2EnvelopeParams env) {
    if (t < 0.0) return 0.0;

    // Fase 1: Delay
    if (t < env.delaySeconds) return 0.0;
    double curT = t - env.delaySeconds;

    // Fase 2: Attack (rampa convexa hacia 1.0)
    if (curT < env.attackSeconds) {
      if (env.attackSeconds <= 0.0) return 1.0;
      return (curT / env.attackSeconds).clamp(0.0, 1.0);
    }
    curT -= env.attackSeconds;

    // Fase 3: Hold (se mantiene en 1.0)
    if (curT < env.holdSeconds) {
      return 1.0;
    }
    curT -= env.holdSeconds;

    // Fase 4: Note Release (si la nota finaliza antes del decaimiento completo)
    if (t >= noteDurationSeconds) {
      final releaseTime = t - noteDurationSeconds;
      if (releaseTime >= env.releaseSeconds) return 0.0;
      final releaseRatio = (1.0 - (releaseTime / env.releaseSeconds)).clamp(0.0, 1.0);
      return env.sustainLevel * releaseRatio;
    }

    // Fase 5: Decay hacia Sustain
    if (curT < env.decaySeconds) {
      if (env.decaySeconds <= 0.0) return env.sustainLevel;
      final decayRatio = (curT / env.decaySeconds).clamp(0.0, 1.0);
      return 1.0 - (1.0 - env.sustainLevel) * decayRatio;
    }

    // Fase 6: Sustain
    return env.sustainLevel;
  }

  /// Renderiza un flujo de audio PCM Float64 a partir de un sample SF2 y la relación de tono.
  Float64List renderNoteSamples({
    required Int16List sampleData,
    required Sf2SampleHeader header,
    required int targetMidiPitch,
    required double durationSeconds,
    required int outputSampleRate,
    int velocity = 100,
    Sf2EnvelopeParams envelope = const Sf2EnvelopeParams(),
  }) {
    final totalSamples = (durationSeconds * outputSampleRate).round();
    if (totalSamples <= 0) return Float64List(0);

    final out = Float64List(totalSamples);

    final rootPitch = header.originalPitch > 0 ? header.originalPitch : 60;
    final semitoneDiff = (targetMidiPitch - rootPitch) + (header.pitchCorrection / 100.0);
    final pitchRatio = math.pow(2.0, semitoneDiff / 12.0) * (header.sampleRate / outputSampleRate);

    final startIdx = header.start;
    final endIdx = header.end;
    final loopStart = header.startLoop;
    final loopEnd = header.endLoop;
    final hasLoop = header.hasLoop && loopEnd > loopStart && loopEnd <= endIdx;

    double samplePos = startIdx.toDouble();
    final double velGain = (velocity / 127.0).clamp(0.1, 1.0);

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / outputSampleRate;
      final env = evaluateVolEg(t, durationSeconds, envelope);
      if (env <= 0.0001 && t > durationSeconds) break;

      final int intPos = samplePos.floor();
      final double frac = samplePos - intPos;

      // Obtener 4 muestras para interpolación Hermite
      final y0 = _getSample(sampleData, intPos - 1, startIdx, endIdx, hasLoop, loopStart, loopEnd);
      final y1 = _getSample(sampleData, intPos, startIdx, endIdx, hasLoop, loopStart, loopEnd);
      final y2 = _getSample(sampleData, intPos + 1, startIdx, endIdx, hasLoop, loopStart, loopEnd);
      final y3 = _getSample(sampleData, intPos + 2, startIdx, endIdx, hasLoop, loopStart, loopEnd);

      final val = interpolateHermite4(y0, y1, y2, y3, frac);
      out[i] = val * env * velGain;

      samplePos += pitchRatio;

      if (hasLoop) {
        if (samplePos >= loopEnd) {
          samplePos = loopStart + (samplePos - loopEnd) % (loopEnd - loopStart);
        }
      } else {
        if (samplePos >= endIdx - 2) {
          // Si no tiene loop y llega al fin del sample, detener
          break;
        }
      }
    }

    return out;
  }

  static double _getSample(
    Int16List data,
    int idx,
    int start,
    int end,
    bool hasLoop,
    int loopStart,
    int loopEnd,
  ) {
    if (idx < start) idx = start;
    if (hasLoop) {
      if (idx >= loopEnd) {
        idx = loopStart + ((idx - loopStart) % (loopEnd - loopStart));
      }
    } else {
      if (idx >= end) return 0.0;
    }

    if (idx < 0 || idx >= data.length) return 0.0;
    return data[idx].toDouble();
  }
}
