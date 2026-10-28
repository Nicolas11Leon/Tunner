import 'dart:math' as math;
import 'chord_entity.dart';
import 'polyphonic_pitch_entity.dart';
import 'polyphonic_chord_recognizer.dart';

/// Detector DSP en Pure Dart para la descomposición multitonal en tiempo real de notas simultáneas.
/// Emplea la técnica de Tamiz Armónico y Función de Salience con sustracción iterativa
/// de armónicos superiores para aislar voces polifónicas en guitarra y piano.
class PolyphonicMultiToneDetector {
  final int minMidiNote;
  final int maxMidiNote;
  final int maxVoices;
  final double noiseGateRms;
  final double salienceThresholdRatio;

  final PolyphonicChordRecognizer _chordRecognizer;

  PolyphonicMultiToneDetector({
    this.minMidiNote = 40, // E2 (~82.41 Hz)
    this.maxMidiNote = 84, // C6 (~1046.50 Hz)
    this.maxVoices = 6,    // Hasta 6 cuerdas simultáneas de guitarra / voces de piano
    this.noiseGateRms = 0.008,
    this.salienceThresholdRatio = 0.22,
    PolyphonicChordRecognizer? chordRecognizer,
  }) : _chordRecognizer = chordRecognizer ?? PolyphonicChordRecognizer();

  /// Nombres silábicos de notas en español por clase cromática [0..11].
  static const List<String> solfegeNames = [
    'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si',
  ];

  /// Nombres internacionales de notas por clase cromática [0..11].
  static const List<String> internationalNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Analiza un búfer de muestras PCM normalizadas y retorna el desglose multitonal polifónico.
  PolyphonicMultiToneAnalysisResult detectFromSamples({
    required List<double> samples,
    double sampleRate = 44100.0,
    double a4Ref = 440.0,
  }) {
    if (samples.length < 128) {
      return PolyphonicMultiToneAnalysisResult.empty;
    }

    // 1. Verificación de umbral de energía RMS (Noise Gate)
    double sumSq = 0.0;
    final int n = samples.length;
    for (int i = 0; i < n; i++) {
      sumSq += samples[i] * samples[i];
    }
    final double rms = math.sqrt(sumSq / n);
    if (rms < noiseGateRms) {
      return PolyphonicMultiToneAnalysisResult.empty;
    }

    final int analysisLength = math.min(n, 4096);

    // 2. Cálculo del espectro discreto en la grilla cromática MIDI
    final List<double> rawMagnitudes = List<double>.filled(128, 0.0);

    for (int midi = minMidiNote; midi <= maxMidiNote; midi++) {
      final double freq = a4Ref * math.pow(2.0, (midi - 69) / 12.0);
      if (freq >= sampleRate / 2.0) continue;

      final double omega = 2.0 * math.pi * freq / sampleRate;
      double sumCos = 0.0;
      double sumSin = 0.0;

      for (int i = 0; i < analysisLength; i++) {
        final double window = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (analysisLength - 1)));
        final double s = samples[i] * window;
        sumCos += s * math.cos(omega * i);
        sumSin += s * math.sin(omega * i);
      }

      rawMagnitudes[midi] = (2.0 / analysisLength) * math.sqrt(sumCos * sumCos + sumSin * sumSin);
    }

    // 3. Extracción de Cromagrama y Reconocimiento de Acorde
    final recognizedChord = _chordRecognizer.identifyFromSamples(
      samples: samples,
      sampleRate: sampleRate,
      a4Ref: a4Ref,
      noiseGateRms: noiseGateRms,
    );

    // 4. Algoritmo de Tamiz Armónico y Función de Salience
    final detectedVoices = <DetectedPolyphonicVoice>[];
    final remainingMags = List<double>.from(rawMagnitudes);

    // Ponderaciones decrecientes para los primeros 5 armónicos (1f0, 2f0, 3f0, 4f0, 5f0)
    const harmonicWeights = [1.0, 0.65, 0.40, 0.25, 0.15];

    double maxInitialSalience = 0.0;

    for (int voiceIteration = 0; voiceIteration < maxVoices; voiceIteration++) {
      int bestMidi = -1;
      double highestSalience = 0.0;

      for (int candidate = minMidiNote; candidate <= maxMidiNote; candidate++) {
        // La fundamental debe ser un pico local respecto a semitonos adyacentes
        final double cur = remainingMags[candidate];
        if (candidate > minMidiNote && cur <= remainingMags[candidate - 1]) continue;
        if (candidate < maxMidiNote && cur <= remainingMags[candidate + 1]) continue;
        if (cur < 0.015) continue;

        // Suma ponderada de la función de salience sobre la serie armónica
        double salience = 0.0;
        final double baseFreq = a4Ref * math.pow(2.0, (candidate - 69) / 12.0);

        for (int h = 1; h <= 5; h++) {
          final double harmonicFreq = baseFreq * h;
          if (harmonicFreq >= sampleRate / 2.0) break;

          final double harmonicMidiExact = 69.0 + 12.0 * (math.log(harmonicFreq / a4Ref) / math.ln2);
          final int harmonicMidi = harmonicMidiExact.round();
          if (harmonicMidi <= 127) {
            salience += remainingMags[harmonicMidi] * harmonicWeights[h - 1];
          }
        }

        if (salience > highestSalience) {
          highestSalience = salience;
          bestMidi = candidate;
        }
      }

      if (voiceIteration == 0) {
        maxInitialSalience = highestSalience;
      }

      // Detener si el salience cae por debajo del umbral relativo o absoluto
      if (bestMidi == -1 ||
          highestSalience < 0.02 ||
          (maxInitialSalience > 0 && highestSalience < maxInitialSalience * salienceThresholdRatio)) {
        break;
      }

      // Voz confirmada: derivar propiedades acústicas
      final nominalFreq = a4Ref * math.pow(2.0, (bestMidi - 69) / 12.0);
      final pitchClass = bestMidi % 12;
      final octave = (bestMidi ~/ 12) - 1;

      // Estimación de refinamiento de pico cuadrático para desviación en cents
      final double y1 = remainingMags[math.max(0, bestMidi - 1)];
      final double y2 = remainingMags[bestMidi];
      final double y3 = remainingMags[math.min(127, bestMidi + 1)];
      double deltaSemitone = 0.0;
      if (y1 + y3 - 2 * y2 != 0.0) {
        deltaSemitone = 0.5 * (y1 - y3) / (y1 - 2 * y2 + y3);
        deltaSemitone = deltaSemitone.clamp(-0.5, 0.5);
      }
      final double centsDev = deltaSemitone * 100.0;
      final double exactFreq = nominalFreq * math.pow(2.0, deltaSemitone / 12.0);

      final normalizedSalience = maxInitialSalience > 0
          ? (highestSalience / maxInitialSalience).clamp(0.0, 1.0)
          : 1.0;

      final role = _deriveHarmonicRole(pitchClass, recognizedChord);

      detectedVoices.add(DetectedPolyphonicVoice(
        noteName: solfegeNames[pitchClass],
        noteNameInternational: internationalNames[pitchClass],
        octave: octave,
        pitchClassIndex: pitchClass,
        frequencyHz: exactFreq,
        midiNumber: bestMidi,
        centsDeviation: centsDev,
        salience: normalizedSalience,
        harmonicRole: role,
      ));

      // 5. Sustracción del peine armónico de la voz confirmada
      final double baseFreq = nominalFreq;
      for (int h = 1; h <= 5; h++) {
        final double harmonicFreq = baseFreq * h;
        final double harmonicMidiExact = 69.0 + 12.0 * (math.log(harmonicFreq / a4Ref) / math.ln2);
        final int harmonicMidi = harmonicMidiExact.round();
        if (harmonicMidi <= 127) {
          final double subtractionAmount = remainingMags[harmonicMidi] * (0.80 / h);
          remainingMags[harmonicMidi] = math.max(0.0, remainingMags[harmonicMidi] - subtractionAmount);
        }
      }
    }

    // 6. Ordenar voces de más grave (bajo) a más aguda (soprano)
    detectedVoices.sort((a, b) => a.midiNumber.compareTo(b.midiNumber));

    // Determinar etiqueta descriptiva del voicing
    String voicingDesc = 'Silencio';
    if (detectedVoices.isEmpty) {
      voicingDesc = 'Sin voces detectadas';
    } else if (detectedVoices.length == 1) {
      voicingDesc = 'Monofonía / Nota Individual';
    } else if (detectedVoices.length == 2) {
      voicingDesc = 'Intervalo / Diada';
    } else if (detectedVoices.length == 3) {
      voicingDesc = 'Tríada Polifónica';
    } else if (detectedVoices.length == 4) {
      voicingDesc = 'Tétrada / Acorde de 4 Notas';
    } else {
      voicingDesc = 'Voicing Completo de ${detectedVoices.length} Voces';
    }

    return PolyphonicMultiToneAnalysisResult(
      voices: detectedVoices,
      chord: recognizedChord,
      voicingName: voicingDesc,
      isSilence: false,
    );
  }

  /// Deduce el papel armónico de una clase de altura en función del acorde reconocido.
  String _deriveHarmonicRole(int pitchClass, ChordEntity chord) {
    if (!chord.isRecognized) return 'Voz Polifónica';

    final root = chord.rootNoteIndex;
    final interval = (pitchClass - root + 12) % 12;

    switch (interval) {
      case 0:
        return 'Fundamental (Raíz)';
      case 3:
        return 'Tercera Menor';
      case 4:
        return 'Tercera Mayor';
      case 5:
        return 'Cuarta Justa';
      case 6:
        return 'Quinta Disminuida';
      case 7:
        return 'Quinta Justa';
      case 8:
        return 'Quinta Aumentada';
      case 10:
        return 'Séptima Menor';
      case 11:
        return 'Séptima Mayor';
      case 2:
        return 'Segunda / Novena';
      case 9:
        return 'Sexta / Treceava';
      default:
        return 'Nota Polifónica';
    }
  }
}
