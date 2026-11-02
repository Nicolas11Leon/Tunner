import 'dart:math' as math;
import 'dart:typed_data';
import 'sf2_models.dart';
import 'sf2_wavetable_oscillator.dart';

/// Banco SoundFont esencial integrado en el monolito de Tunner.
/// 
/// Genera proceduralmente muestras wavetable de alta fidelidad con características tímbricas
/// de armónicos y formantes reales para 5 instrumentos acústicos esenciales:
/// 1. Grand Piano (Acoustic Piano - General MIDI #0)
/// 2. Concert Flute (Flute - General MIDI #73)
/// 3. Orchestral Violin (Violin - General MIDI #40)
/// 4. Solo Cello (Cello - General MIDI #42)
/// 5. Classical Guitar (Acoustic Guitar Nylon - General MIDI #24)
class TunnerAcousticSoundFontBank {
  const TunnerAcousticSoundFontBank();

  static const int sampleRate = 44100;

  /// Retorna un `Sf2SoundFont` canónico listo para su síntesis inmediata.
  static Sf2SoundFont buildAcousticEssentialsBank() {
    final sampleDataBuilder = BytesBuilder();
    final sampleHeaders = <Sf2SampleHeader>[];
    final instruments = <Sf2Instrument>[];
    final presets = <Sf2Preset>[];

    int sampleOffset = 0;

    // Función auxiliar para registrar muestras wavetable de instrumentos
    void addInstrumentSample({
      required String instrumentName,
      required int patch,
      required int rootPitch,
      required double Function(double phase, double t) waveGenerator,
      required double durationSeconds,
      required Sf2EnvelopeParams envelope,
    }) {
      final totalSamples = (durationSeconds * sampleRate).round();
      final pcm = Int16List(totalSamples);

      final rootFreq = 440.0 * math.pow(2.0, (rootPitch - 69) / 12.0);

      double phase = 0.0;
      final phaseIncrement = (2.0 * math.pi * rootFreq) / sampleRate;

      for (int i = 0; i < totalSamples; i++) {
        final t = i / sampleRate;
        final rawSignal = waveGenerator(phase, t);
        final clampedVal = rawSignal.clamp(-1.0, 1.0);
        pcm[i] = (clampedVal * 30000.0).round();

        phase += phaseIncrement;
        if (phase >= 2.0 * math.pi) {
          phase -= 2.0 * math.pi;
        }
      }

      final start = sampleOffset;
      final end = start + totalSamples;
      // Loop a partir de la mitad del sample para sustain continuo
      final startLoop = start + (totalSamples * 0.4).round();
      final endLoop = end - (totalSamples * 0.1).round();

      sampleDataBuilder.add(pcm.buffer.asUint8List());
      sampleOffset = end;

      final sampleId = sampleHeaders.length;
      sampleHeaders.add(Sf2SampleHeader(
        name: '${instrumentName}_C',
        start: start,
        end: end,
        startLoop: startLoop,
        endLoop: endLoop,
        sampleRate: sampleRate,
        originalPitch: rootPitch,
        pitchCorrection: 0,
        sampleLink: 0,
        sampleType: 1, // Mono sample
      ));

      final instZone = Sf2Zone(
        keyRange: const Sf2Range(low: 0, high: 127),
        velRange: const Sf2Range(low: 0, high: 127),
        sampleId: sampleId,
        generators: {
          Sf2GeneratorType.sampleID: sampleId,
          Sf2GeneratorType.attackVolEnv: (math.log(envelope.attackSeconds) / math.ln2 * 1200).round(),
          Sf2GeneratorType.decayVolEnv: (math.log(envelope.decaySeconds) / math.ln2 * 1200).round(),
          Sf2GeneratorType.releaseVolEnv: (math.log(envelope.releaseSeconds) / math.ln2 * 1200).round(),
        },
      );

      final instrumentId = instruments.length;
      instruments.add(Sf2Instrument(
        name: instrumentName,
        zones: [instZone],
      ));

      final presetZone = Sf2Zone(
        keyRange: const Sf2Range(low: 0, high: 127),
        velRange: const Sf2Range(low: 0, high: 127),
        instrumentId: instrumentId,
        generators: {
          Sf2GeneratorType.instrument: instrumentId,
        },
      );

      presets.add(Sf2Preset(
        name: instrumentName,
        patch: patch,
        bank: 0,
        zones: [presetZone],
      ));
    }

    // 1. Grand Piano (Patch 0): C4 (60), percusión de martillo + decaimiento exponencial armónico
    addInstrumentSample(
      instrumentName: 'Grand Piano',
      patch: 0,
      rootPitch: 60,
      durationSeconds: 1.8,
      envelope: const Sf2EnvelopeParams(
        attackSeconds: 0.005,
        holdSeconds: 0.010,
        decaySeconds: 1.200,
        sustainLevel: 0.15,
        releaseSeconds: 0.120,
      ),
      waveGenerator: (phase, t) {
        // Armónicos de piano con leve inharmonicidad de cuerda de acero
        final h1 = 0.70 * math.sin(phase);
        final h2 = 0.22 * math.sin(2.001 * phase);
        final h3 = 0.09 * math.sin(3.003 * phase);
        final h4 = 0.04 * math.sin(4.006 * phase);
        return h1 + h2 + h3 + h4;
      },
    );

    // 2. Concert Flute (Patch 73): C5 (72), soplo de bisel + armónico impar suave y vibrato sutil
    addInstrumentSample(
      instrumentName: 'Concert Flute',
      patch: 73,
      rootPitch: 72,
      durationSeconds: 1.5,
      envelope: const Sf2EnvelopeParams(
        attackSeconds: 0.045,
        holdSeconds: 0.080,
        decaySeconds: 0.300,
        sustainLevel: 0.85,
        releaseSeconds: 0.090,
      ),
      waveGenerator: (phase, t) {
        final vibrato = 1.0 + 0.006 * math.sin(2.0 * math.pi * 5.5 * t);
        final h1 = 0.85 * math.sin(phase * vibrato);
        final h2 = 0.15 * math.sin(2.0 * phase * vibrato);
        final h3 = 0.08 * math.sin(3.0 * phase * vibrato);
        return h1 + h2 + h3;
      },
    );

    // 3. Orchestral Violin (Patch 40): A4 (69), frotamiento de arco (sawtooth redondeada) + vibrato
    addInstrumentSample(
      instrumentName: 'Violin',
      patch: 40,
      rootPitch: 69,
      durationSeconds: 1.6,
      envelope: const Sf2EnvelopeParams(
        attackSeconds: 0.060,
        holdSeconds: 0.050,
        decaySeconds: 0.250,
        sustainLevel: 0.80,
        releaseSeconds: 0.110,
      ),
      waveGenerator: (phase, t) {
        final vibrato = 1.0 + 0.008 * math.sin(2.0 * math.pi * 6.0 * t);
        double signal = 0.0;
        for (int k = 1; k <= 7; k++) {
          signal += (1.0 / k) * math.sin(k * phase * vibrato);
        }
        return signal * 0.45;
      },
    );

    // 4. Solo Cello (Patch 42): C3 (48), cuerpo resonante cálido y armónicos ricos
    addInstrumentSample(
      instrumentName: 'Cello',
      patch: 42,
      rootPitch: 48,
      durationSeconds: 1.8,
      envelope: const Sf2EnvelopeParams(
        attackSeconds: 0.080,
        holdSeconds: 0.060,
        decaySeconds: 0.350,
        sustainLevel: 0.75,
        releaseSeconds: 0.140,
      ),
      waveGenerator: (phase, t) {
        final vibrato = 1.0 + 0.005 * math.sin(2.0 * math.pi * 5.0 * t);
        final h1 = 0.60 * math.sin(phase * vibrato);
        final h2 = 0.40 * math.sin(2.0 * phase * vibrato);
        final h3 = 0.25 * math.sin(3.0 * phase * vibrato);
        final h4 = 0.12 * math.sin(4.0 * phase * vibrato);
        return (h1 + h2 + h3 + h4) * 0.70;
      },
    );

    // 5. Classical Guitar (Patch 24): E3 (52), ataque de uña/yema con decaimiento percusivo
    addInstrumentSample(
      instrumentName: 'Classical Guitar',
      patch: 24,
      rootPitch: 52,
      durationSeconds: 1.5,
      envelope: const Sf2EnvelopeParams(
        attackSeconds: 0.008,
        holdSeconds: 0.020,
        decaySeconds: 0.800,
        sustainLevel: 0.20,
        releaseSeconds: 0.100,
      ),
      waveGenerator: (phase, t) {
        final h1 = 0.70 * math.sin(phase);
        final h2 = 0.35 * math.sin(2.0 * phase);
        final h3 = 0.15 * math.sin(3.0 * phase);
        final h4 = 0.08 * math.sin(4.0 * phase);
        return h1 + h2 + h3 + h4;
      },
    );

    final allBytes = sampleDataBuilder.takeBytes();
    final sampleData = Int16List.view(allBytes.buffer);

    return Sf2SoundFont(
      soundFontName: 'Tunner Acoustic Essentials',
      presets: presets,
      instruments: instruments,
      sampleHeaders: sampleHeaders,
      sampleData: sampleData,
    );
  }
}
