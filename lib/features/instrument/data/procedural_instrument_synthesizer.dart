import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/universal_instrument_definition.dart';
import '../domain/instrument_customization_profile.dart';
import '../domain/musical_phrase_entity.dart';

/// Motor de síntesis procedural acústica en memoria.
/// Emula cualquier instrumento del catálogo universal calculando la forma de onda
/// mediante síntesis aditiva armónica, envolvente ADSR, personalización tímbrica y micro-afinaciones.
class ProceduralInstrumentSynthesizer {
  static const int sampleRate = 44100;

  /// Genera un buffer PCM flotante normalizado [-1.0, 1.0] para una nota y duración dada.
  static Float32List synthesizeNote({
    required UniversalInstrumentDefinition instrument,
    required double frequencyHz,
    required double durationSeconds,
    double velocity = 0.8,
  }) {
    final customization = InstrumentCustomizationProfile.defaultFor(instrument);
    return synthesizeCustomNote(
      customization: customization,
      frequencyHz: frequencyHz,
      durationSeconds: durationSeconds,
      velocity: velocity,
    );
  }

  /// Genera un buffer PCM considerando el perfil completo de personalización del instrumento.
  static Float32List synthesizeCustomNote({
    required InstrumentCustomizationProfile customization,
    required double frequencyHz,
    required double durationSeconds,
    double velocity = 0.8,
  }) {
    final numSamples = (sampleRate * durationSeconds).toInt();
    if (numSamples <= 0) return Float32List(0);

    final buffer = Float32List(numSamples);

    final adsr = customization.instrument.timbralProfile.adsr;
    final baseHarmonics = customization.instrument.timbralProfile.harmonicOvertoneAmplitudes;
    final noiseRatio = customization.instrument.timbralProfile.noiseTransientRatio;

    // Aplicar multiplicadores de personalización tímbrica
    final attackMs = adsr.attackMs * customization.attackMultiplier;
    final sustainLevel = (adsr.sustainLevel * customization.sustainMultiplier).clamp(0.0, 1.0);

    final attackSamples = (attackMs * sampleRate / 1000.0).clamp(1.0, numSamples.toDouble()).toInt();
    final decaySamples = (adsr.decayMs * sampleRate / 1000.0).clamp(1.0, numSamples.toDouble()).toInt();
    final releaseSamples = (adsr.releaseMs * sampleRate / 1000.0).clamp(1.0, numSamples.toDouble()).toInt();
    final sustainSamples = math.max(0, numSamples - attackSamples - decaySamples - releaseSamples);

    final random = math.Random(42);

    for (int i = 0; i < numSamples; i++) {
      // 1. Ganancia ADSR
      double envelope = 0.0;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i < attackSamples + decaySamples) {
        final progress = (i - attackSamples) / decaySamples;
        envelope = 1.0 - progress * (1.0 - sustainLevel);
      } else if (i < attackSamples + decaySamples + sustainSamples) {
        envelope = sustainLevel;
      } else {
        final relProgress = (i - (attackSamples + decaySamples + sustainSamples)) / releaseSamples;
        envelope = sustainLevel * (1.0 - relProgress.clamp(0.0, 1.0));
      }

      // 2. Síntesis aditiva armónica con brillo ajustado
      double sampleValue = 0.0;
      final t = i / sampleRate;

      for (int h = 0; h < baseHarmonics.length; h++) {
        final harmonicFreq = frequencyHz * (h + 1);
        if (harmonicFreq < sampleRate / 2.0) {
          // Si h > 0 (sobretonos), se modula con harmonicBrightness
          final brightnessScale = (h == 0) ? 1.0 : customization.harmonicBrightness;
          final amp = (baseHarmonics[h] * brightnessScale).clamp(0.0, 1.0);
          sampleValue += amp * math.sin(2.0 * math.pi * harmonicFreq * t);
        }
      }

      // 3. Transiente de ruido de ataque
      if (noiseRatio > 0.0 && i < attackSamples * 2) {
        final noise = (random.nextDouble() * 2.0 - 1.0) * noiseRatio;
        sampleValue += noise;
      }

      // 4. Normalización y escalado
      buffer[i] = (sampleValue * envelope * velocity * 0.35).clamp(-1.0, 1.0);
    }

    return buffer;
  }

  /// Sintetiza una estrofa musical completa reproduciendo secuencialmente cada una de sus notas.
  static Float32List synthesizePhrase({
    required InstrumentCustomizationProfile customization,
    required MusicalPhraseEntity phrase,
    int? bpmOverride,
  }) {
    final bpm = bpmOverride ?? phrase.defaultBpm;
    // Un tick (semicorchea) en segundos: 60 / (bpm * 4)
    final secondsPerTick = 60.0 / (bpm * 4.0);

    // Calcular tamaño total del buffer
    final totalDurationSeconds = phrase.totalTicks * secondsPerTick;
    final totalSamples = (sampleRate * totalDurationSeconds).toInt();
    final phraseBuffer = Float32List(totalSamples);

    int writeOffset = 0;

    for (final note in phrase.notes) {
      final noteDuration = note.durationTicks * secondsPerTick;
      final noteSampleCount = (sampleRate * noteDuration).toInt();

      if (!note.isRest) {
        // Calcular frecuencia exacta considerando micro-afinaciones y temperamento
        final freqHz = customization.calculateFrequencyForMidiNote(note.midiNote);

        final noteBuffer = synthesizeCustomNote(
          customization: customization,
          frequencyHz: freqHz,
          durationSeconds: noteDuration,
          velocity: note.velocity,
        );

        // Copiar muestras al buffer de la estrofa
        for (int i = 0; i < noteBuffer.length && (writeOffset + i) < totalSamples; i++) {
          phraseBuffer[writeOffset + i] += noteBuffer[i];
        }
      }

      writeOffset += noteSampleCount;
    }

    return phraseBuffer;
  }
}
