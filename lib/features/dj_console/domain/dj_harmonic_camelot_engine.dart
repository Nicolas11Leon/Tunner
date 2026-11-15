import 'dart:math' as math;
import 'dart:typed_data';

/// Harmonic compatibility classification on the Camelot Wheel.
enum CamelotCompatibility {
  perfectUnison,
  harmonicStep,
  relativeSwitch,
  energyBoost,
  harmonicClash,
}

extension CamelotCompatibilityExtension on CamelotCompatibility {
  String get label {
    switch (this) {
      case CamelotCompatibility.perfectUnison:
        return 'PERFECT MATCH';
      case CamelotCompatibility.harmonicStep:
        return 'HARMONIC STEP';
      case CamelotCompatibility.relativeSwitch:
        return 'RELATIVE KEY';
      case CamelotCompatibility.energyBoost:
        return 'ENERGY BOOST';
      case CamelotCompatibility.harmonicClash:
        return 'KEY CLASH';
    }
  }
}

/// Represents a musical key projected onto the 24-key Camelot Easymix Wheel.
class CamelotKey {
  final int number; // 1..12
  final String letter; // 'A' (Minor) or 'B' (Major)
  final String musicalName;
  final int rootPitchClass; // 0=C, 1=C#, ..., 11=B
  final bool isMinor;

  const CamelotKey({
    required this.number,
    required this.letter,
    required this.musicalName,
    required this.rootPitchClass,
    required this.isMinor,
  });

  String get code => '$number$letter';
}

/// Pure Dart harmonic mixing engine implementing the Camelot Wheel (1A-12B)
/// and Krumhansl-Kessler chromatic key estimation.
class DjHarmonicCamelotEngine {
  DjHarmonicCamelotEngine._();

  /// Canonical 24-key Camelot Wheel table ordered by Camelot number & mode.
  static const List<CamelotKey> wheel = [
    // Minor keys (Inner wheel - A)
    CamelotKey(number: 1, letter: 'A', musicalName: 'Abm', rootPitchClass: 8, isMinor: true),
    CamelotKey(number: 2, letter: 'A', musicalName: 'Ebm', rootPitchClass: 3, isMinor: true),
    CamelotKey(number: 3, letter: 'A', musicalName: 'Bbm', rootPitchClass: 10, isMinor: true),
    CamelotKey(number: 4, letter: 'A', musicalName: 'Fm', rootPitchClass: 5, isMinor: true),
    CamelotKey(number: 5, letter: 'A', musicalName: 'Cm', rootPitchClass: 0, isMinor: true),
    CamelotKey(number: 6, letter: 'A', musicalName: 'Gm', rootPitchClass: 7, isMinor: true),
    CamelotKey(number: 7, letter: 'A', musicalName: 'Dm', rootPitchClass: 2, isMinor: true),
    CamelotKey(number: 8, letter: 'A', musicalName: 'Am', rootPitchClass: 9, isMinor: true),
    CamelotKey(number: 9, letter: 'A', musicalName: 'Em', rootPitchClass: 4, isMinor: true),
    CamelotKey(number: 10, letter: 'A', musicalName: 'Bm', rootPitchClass: 11, isMinor: true),
    CamelotKey(number: 11, letter: 'A', musicalName: 'F#m', rootPitchClass: 6, isMinor: true),
    CamelotKey(number: 12, letter: 'A', musicalName: 'Dbm', rootPitchClass: 1, isMinor: true),

    // Major keys (Outer wheel - B)
    CamelotKey(number: 1, letter: 'B', musicalName: 'B', rootPitchClass: 11, isMinor: false),
    CamelotKey(number: 2, letter: 'B', musicalName: 'F#', rootPitchClass: 6, isMinor: false),
    CamelotKey(number: 3, letter: 'B', musicalName: 'Db', rootPitchClass: 1, isMinor: false),
    CamelotKey(number: 4, letter: 'B', musicalName: 'Ab', rootPitchClass: 8, isMinor: false),
    CamelotKey(number: 5, letter: 'B', musicalName: 'Eb', rootPitchClass: 3, isMinor: false),
    CamelotKey(number: 6, letter: 'B', musicalName: 'Bb', rootPitchClass: 10, isMinor: false),
    CamelotKey(number: 7, letter: 'B', musicalName: 'F', rootPitchClass: 5, isMinor: false),
    CamelotKey(number: 8, letter: 'B', musicalName: 'C', rootPitchClass: 0, isMinor: false),
    CamelotKey(number: 9, letter: 'B', musicalName: 'G', rootPitchClass: 7, isMinor: false),
    CamelotKey(number: 10, letter: 'B', musicalName: 'D', rootPitchClass: 2, isMinor: false),
    CamelotKey(number: 11, letter: 'B', musicalName: 'A', rootPitchClass: 9, isMinor: false),
    CamelotKey(number: 12, letter: 'B', musicalName: 'E', rootPitchClass: 4, isMinor: false),
  ];

  // Krumhansl-Kessler tonal pitch-class profiles (12 semitones from tonic)
  static const List<double> _majorProfile = [
    6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
  ];
  static const List<double> _minorProfile = [
    6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
  ];

  /// Finds a CamelotKey by code (e.g. '8A', '11B'). Falls back to '8A' (A minor).
  static CamelotKey findByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final k in wheel) {
      if (k.code == normalized) return k;
    }
    return wheel[7]; // 8A (Am)
  }

  /// Transposes a Camelot key by [semitones] in [-12, +12].
  /// On the circle of fifths, +1 semitone corresponds to +7 steps on the 12-hour wheel.
  static CamelotKey transpose(String camelotCode, int semitones) {
    final base = findByCode(camelotCode);
    final newPitchClass = (base.rootPitchClass + semitones) % 12;
    final positivePitchClass = newPitchClass < 0 ? newPitchClass + 12 : newPitchClass;

    for (final k in wheel) {
      if (k.rootPitchClass == positivePitchClass && k.isMinor == base.isMinor) {
        return k;
      }
    }
    return base;
  }

  /// Evaluates harmonic compatibility between two Camelot codes.
  static CamelotCompatibility analyzeCompatibility(String codeA, String codeB) {
    final keyA = findByCode(codeA);
    final keyB = findByCode(codeB);

    if (keyA.number == keyB.number && keyA.letter == keyB.letter) {
      return CamelotCompatibility.perfectUnison;
    }

    if (keyA.number == keyB.number && keyA.letter != keyB.letter) {
      return CamelotCompatibility.relativeSwitch;
    }

    final wheelDiff = (keyB.number - keyA.number) % 12;
    final positiveDiff = wheelDiff < 0 ? wheelDiff + 12 : wheelDiff;

    if (keyA.letter == keyB.letter && (positiveDiff == 1 || positiveDiff == 11)) {
      return CamelotCompatibility.harmonicStep;
    }

    // Energy boost (+1 semitone = +7 steps, or +2 semitones = +2 steps on Camelot wheel)
    if (keyA.letter == keyB.letter && (positiveDiff == 2 || positiveDiff == 7)) {
      return CamelotCompatibility.energyBoost;
    }

    return CamelotCompatibility.harmonicClash;
  }

  /// Computes the minimal semitone shift in [-6, +6] needed to align [sourceCode]
  /// into harmonic compatibility (matching pitch center) with [targetCode].
  static int calculateOptimalSemitoneShift(String sourceCode, String targetCode) {
    final src = findByCode(sourceCode);
    final dst = findByCode(targetCode);

    // If they share the same mode (both A or both B), align root pitch classes directly.
    // If relative modes differ (A vs B), align to the relative major/minor equivalent first.
    final targetRoot = dst.isMinor == src.isMinor
        ? dst.rootPitchClass
        : wheel.firstWhere((k) => k.number == dst.number && k.isMinor == src.isMinor).rootPitchClass;

    int delta = (targetRoot - src.rootPitchClass) % 12;
    if (delta > 6) delta -= 12;
    if (delta < -6) delta += 12;
    return delta;
  }

  /// Estimates the musical key in Camelot notation from raw PCM samples
  /// using a 12-bin chromagram via Goertzel resonance across octaves 2..5.
  static CamelotKey estimateCamelotKeyFromSamples(
    Float32List samples, {
    int sampleRate = 44100,
  }) {
    if (samples.isEmpty || sampleRate <= 0) {
      return wheel[7]; // 8A fallback
    }

    // Analyze up to 1 second of audio to guarantee deterministic sub-5ms execution
    final windowLength = math.min(samples.length, sampleRate);
    final chroma = List<double>.filled(12, 0.0);

    // Compute energy for each pitch class across octaves 2, 3, and 4 (MIDI 36..71)
    for (int pitchClass = 0; pitchClass < 12; pitchClass++) {
      double classEnergy = 0.0;
      for (int octave = 2; octave <= 4; octave++) {
        final midiNote = (octave + 1) * 12 + pitchClass;
        final freq = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
        classEnergy += _goertzelMagnitudeSquared(samples, windowLength, freq, sampleRate);
      }
      chroma[pitchClass] = math.sqrt(classEnergy);
    }

    double bestCorrelation = -double.infinity;
    CamelotKey bestKey = wheel[7];

    for (final candidate in wheel) {
      final profile = candidate.isMinor ? _minorProfile : _majorProfile;
      final corr = _pearsonCorrelation(chroma, profile, candidate.rootPitchClass);
      if (corr > bestCorrelation) {
        bestCorrelation = corr;
        bestKey = candidate;
      }
    }

    return bestKey;
  }

  static double _goertzelMagnitudeSquared(
    Float32List samples,
    int length,
    double targetFreq,
    int sampleRate,
  ) {
    final k = (0.5 + ((length * targetFreq) / sampleRate)).floor();
    final omega = (2.0 * math.pi * k) / length;
    final coeff = 2.0 * math.cos(omega);

    double q1 = 0.0;
    double q2 = 0.0;

    for (int i = 0; i < length; i++) {
      final q0 = coeff * q1 - q2 + samples[i];
      q2 = q1;
      q1 = q0;
    }

    return (q1 * q1) + (q2 * q2) - (q1 * q2 * coeff);
  }

  static double _pearsonCorrelation(
    List<double> chroma,
    List<double> profile,
    int rootOffset,
  ) {
    double sumX = 0.0;
    double sumY = 0.0;
    for (int i = 0; i < 12; i++) {
      sumX += chroma[(rootOffset + i) % 12];
      sumY += profile[i];
    }
    final meanX = sumX / 12.0;
    final meanY = sumY / 12.0;

    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;
    for (int i = 0; i < 12; i++) {
      final dx = chroma[(rootOffset + i) % 12] - meanX;
      final dy = profile[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }

    final den = math.sqrt(denX * denY);
    return den > 1e-9 ? (num / den) : 0.0;
  }
}
