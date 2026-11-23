import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import '../../tuner/domain/temperament_engine.dart';
import 'drone_timbre.dart';
import 'harmonic_drone_config.dart';

/// Generador matematico procedural de tonos pedal armonicos continuos para el estudio de dron.
/// Pure Dart: Cero dependencias de Flutter UI o plugins nativos.
class HarmonicDroneSynthesizer {
  final TemperamentEngine _temperamentEngine;

  const HarmonicDroneSynthesizer({
    TemperamentEngine? temperamentEngine,
  }) : _temperamentEngine = temperamentEngine ?? const TemperamentEngine();

  static const int defaultSampleRate = 44100;
  static const double defaultDurationSeconds = 2.0;

  /// Calcula las frecuencias exactas en Hz para las componentes activas del dron
  /// segun la configuracion, la calibracion A4 y el temperamento historico seleccionado.
  Map<String, double> calculateFrequencies({
    required HarmonicDroneConfig config,
    double a4Ref = 440.0,
    MusicalTemperament? temperament,
    int temperamentRootKey = 0,
  }) {
    final activeTemperament = temperament ?? TemperamentEngine.equalTemperament;

    // Frecuencia de la fundamental
    final fundamentalHz = _temperamentEngine.getTargetFrequency(
      midiNumber: config.rootMidiNumber,
      temperament: activeTemperament,
      a4Ref: a4Ref,
      rootKey: temperamentRootKey,
      anchorA4: true,
    );

    // Frecuencia de la quinta armónica (7 semitonos arriba)
    final fifthHz = config.includeFifth
        ? _temperamentEngine.getTargetFrequency(
            midiNumber: config.rootMidiNumber + 7,
            temperament: activeTemperament,
            a4Ref: a4Ref,
            rootKey: temperamentRootKey,
            anchorA4: true,
          )
        : 0.0;

    // Frecuencia de la octava superior (12 semitonos arriba)
    final octaveHz = config.includeOctave
        ? _temperamentEngine.getTargetFrequency(
            midiNumber: config.rootMidiNumber + 12,
            temperament: activeTemperament,
            a4Ref: a4Ref,
            rootKey: temperamentRootKey,
            anchorA4: true,
          )
        : 0.0;

    return {
      'fundamental': fundamentalHz,
      'fifth': fifthHz,
      'octave': octaveHz,
    };
  }

  /// Sintetiza el valor de una muestra normalizada [-1.0 .. 1.0] para una frecuencia dada
  /// en el instante temporal [t] segun el timbre acustico especificado, aplicando guarda
  /// anti-aliasing de Nyquist (harmonicFreq < sampleRate * 0.48).
  static double synthesizeVoiceSample(
    double frequency,
    double t,
    DroneTimbre timbre, {
    int sampleRate = defaultSampleRate,
  }) {
    if (frequency <= 10.0) return 0.0;
    final double nyquistLimit = sampleRate * 0.48;
    if (frequency >= nyquistLimit) return 0.0;

    final double omega = 2.0 * math.pi * frequency;

    double addHarmonic(int harmonicIndex, double weight) {
      final double harmonicFreq = frequency * harmonicIndex;
      if (harmonicFreq >= nyquistLimit) return 0.0;
      return weight * math.sin(harmonicIndex * omega * t);
    }

    switch (timbre) {
      case DroneTimbre.pureSine:
        // Onda senoidal pura sin armonicos superiores
        return addHarmonic(1, 1.0);

      case DroneTimbre.warmFlute:
        // Armonicos suaves redondeados (fundamental + 2do y 3er armonico calidos)
        return addHarmonic(1, 0.75) +
            addHarmonic(2, 0.20) +
            addHarmonic(3, 0.05);

      case DroneTimbre.richCello:
        // Serie armónica rica semejante a cuerda frotada
        return addHarmonic(1, 0.50) +
            addHarmonic(2, 0.25) +
            addHarmonic(3, 0.15) +
            addHarmonic(4, 0.07) +
            addHarmonic(5, 0.03);

      case DroneTimbre.organ:
        // Densidad polifonica de organo tubular
        return addHarmonic(1, 0.45) +
            addHarmonic(2, 0.25) +
            addHarmonic(3, 0.18) +
            addHarmonic(4, 0.12);
    }
  }

  /// Genera un buffer de audio en formato canónico RIFF/WAVE PCM 16-bit Mono
  /// con bucle continuo matematico sin clics (seamless zero-discontinuity crossfade loop).
  Uint8List generateDroneWavBuffer({
    required HarmonicDroneConfig config,
    double a4Ref = 440.0,
    MusicalTemperament? temperament,
    int temperamentRootKey = 0,
    int sampleRate = defaultSampleRate,
    double durationSeconds = defaultDurationSeconds,
  }) {
    final freqs = calculateFrequencies(
      config: config,
      a4Ref: a4Ref,
      temperament: temperament,
      temperamentRootKey: temperamentRootKey,
    );

    final double fFund = freqs['fundamental']!;
    final double fFifth = freqs['fifth']!;
    final double fOct = freqs['octave']!;

    final int loopSamples = (sampleRate * durationSeconds).round();
    // Region de fundido cruzado: 40 ms para transicion imperceptible
    final int crossfadeSamples = (sampleRate * 0.040).round();
    final int totalGeneratedSamples = loopSamples + crossfadeSamples;

    // Pesos de mezcla armonica
    final double balance = config.harmonicBalance; // 0.0 a 1.0
    final double fundWeight = 1.0;
    final double fifthWeight = config.includeFifth ? balance : 0.0;
    final double octaveWeight = config.includeOctave ? balance * 0.65 : 0.0;
    final double totalWeight = fundWeight + fifthWeight + octaveWeight;

    final double normFactor = totalWeight > 0.0 ? 1.0 / totalWeight : 1.0;
    const double targetMaxAmplitude = 26000.0; // Rango 16-bit confortable sin clipping

    // Generar muestras en punto flotante continuo
    final rawSamples = Float64List(totalGeneratedSamples);
    for (int i = 0; i < totalGeneratedSamples; i++) {
      final double t = i / sampleRate;
      double sample = fundWeight *
          synthesizeVoiceSample(
            fFund,
            t,
            config.timbre,
            sampleRate: sampleRate,
          );

      if (config.includeFifth && fFifth > 0) {
        sample += fifthWeight *
            synthesizeVoiceSample(
              fFifth,
              t,
              config.timbre,
              sampleRate: sampleRate,
            );
      }
      if (config.includeOctave && fOct > 0) {
        sample += octaveWeight *
            synthesizeVoiceSample(
              fOct,
              t,
              config.timbre,
              sampleRate: sampleRate,
            );
      }

      rawSamples[i] = sample * normFactor;
    }

    // Aplicar fundido cruzado matematico simetrico en el inicio del bucle
    // para que loopSamples - 1 transicione a 0 sin discontinuidad de fase
    final pcmBytes = ByteData(loopSamples * 2);

    for (int i = 0; i < loopSamples; i++) {
      double sampleVal;
      if (i < crossfadeSamples) {
        // En los primeros crossfadeSamples, fundimos suavemente lo que venia despues de loopSamples
        final double alpha = i / crossfadeSamples;
        final double sampleFromTail = rawSamples[loopSamples + i];
        final double sampleFromHead = rawSamples[i];
        sampleVal = (1.0 - alpha) * sampleFromTail + alpha * sampleFromHead;
      } else {
        sampleVal = rawSamples[i];
      }

      final int sampleClamped = (sampleVal * targetMaxAmplitude).clamp(-32768.0, 32767.0).round();
      pcmBytes.setInt16(i * 2, sampleClamped, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
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
