import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/universal_instrument_definition.dart';

/// Motor de síntesis procedural acústica en memoria.
/// Emula cualquier instrumento del catálogo universal calculando la forma de onda
/// mediante síntesis aditiva armónica y envolvente ADSR en tiempo real offline.
class ProceduralInstrumentSynthesizer {
  static const int sampleRate = 44100;

  /// Genera un buffer PCM flotante normalizado [-1.0, 1.0] para una nota y duración dada.
  static Float32List synthesizeNote({
    required UniversalInstrumentDefinition instrument,
    required double frequencyHz,
    required double durationSeconds,
    double velocity = 0.8,
  }) {
    final numSamples = (sampleRate * durationSeconds).toInt();
    final buffer = Float32List(numSamples);

    final adsr = instrument.timbralProfile.adsr;
    final harmonics = instrument.timbralProfile.harmonicOvertoneAmplitudes;
    final noiseRatio = instrument.timbralProfile.noiseTransientRatio;

    // Conversión de tiempos de ADSR a número de muestras
    final attackSamples = (adsr.attackMs * sampleRate / 1000.0).clamp(1.0, numSamples.toDouble()).toInt();
    final decaySamples = (adsr.decayMs * sampleRate / 1000.0).clamp(1.0, numSamples.toDouble()).toInt();
    final releaseSamples = (adsr.releaseMs * sampleRate / 1000.0).clamp(1.0, numSamples.toDouble()).toInt();
    final sustainSamples = math.max(0, numSamples - attackSamples - decaySamples - releaseSamples);

    final random = math.Random(42);

    for (int i = 0; i < numSamples; i++) {
      // 1. Cálculo de ganancia ADSR en la muestra i
      double envelope = 0.0;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i < attackSamples + decaySamples) {
        final progress = (i - attackSamples) / decaySamples;
        envelope = 1.0 - progress * (1.0 - adsr.sustainLevel);
      } else if (i < attackSamples + decaySamples + sustainSamples) {
        envelope = adsr.sustainLevel;
      } else {
        final relProgress = (i - (attackSamples + decaySamples + sustainSamples)) / releaseSamples;
        envelope = adsr.sustainLevel * (1.0 - relProgress.clamp(0.0, 1.0));
      }

      // 2. Síntesis aditiva de armónicos (H1 a H8)
      double sampleValue = 0.0;
      final t = i / sampleRate;

      for (int h = 0; h < harmonics.length; h++) {
        final harmonicFreq = frequencyHz * (h + 1);
        if (harmonicFreq < sampleRate / 2.0) { // Límite de Nyquist
          final amp = harmonics[h];
          sampleValue += amp * math.sin(2.0 * math.pi * harmonicFreq * t);
        }
      }

      // 3. Inyección de transiente de ruido (golpe de parche, púa o soplido)
      if (noiseRatio > 0.0 && i < attackSamples * 2) {
        final noise = (random.nextDouble() * 2.0 - 1.0) * noiseRatio;
        sampleValue += noise;
      }

      // 4. Normalización y escalado por velocidad y envolvente
      buffer[i] = (sampleValue * envelope * velocity * 0.35).clamp(-1.0, 1.0);
    }

    return buffer;
  }
}
