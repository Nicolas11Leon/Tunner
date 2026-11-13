import 'dart:math' as math;
import 'harmonic_role_entity.dart';

/// Acoustical lock status evaluating the degree of pure harmonic consonance.
enum HarmonicLockStatus {
  /// Deviations <= 3.0 cents (beat frequency < 0.5 Hz). Pure conservatory harmony.
  pureConsonance('Consonancia Pura (Lock)', 'lock'),

  /// Deviations between 3.0 and 12.0 cents. Moderate audible beating.
  adjusting('Zona de Ajuste', 'adjust'),

  /// Deviations > 12.0 cents. Rapid roughness or out-of-tune friction.
  roughness('Fricción Armónica', 'friction');

  final String label;
  final String code;
  const HarmonicLockStatus(this.label, this.code);
}

/// Immutable result of a real-time harmonic Just Intonation analysis.
class HarmonicAnalysisResult {
  final double userFrequency;
  final double rootFrequency;
  final HarmonicRole role;
  final double targetFrequencyJi;
  final double centsOffsetFromJi;
  final double centsOffsetFrom12Tet;
  final double beatFrequencyHz;
  final HarmonicLockStatus status;
  final String tuningAdvice;

  const HarmonicAnalysisResult({
    required this.userFrequency,
    required this.rootFrequency,
    required this.role,
    required this.targetFrequencyJi,
    required this.centsOffsetFromJi,
    required this.centsOffsetFrom12Tet,
    required this.beatFrequencyHz,
    required this.status,
    required this.tuningAdvice,
  });

  bool get isLocked => status == HarmonicLockStatus.pureConsonance;
}

/// Pure Dart mathematical engine for calculating Dynamic Just Intonation (JI),
/// interval role identification, and acoustic beat frequencies.
class JustIntonationCalculator {
  /// Derives the full harmonic analysis from a detected user frequency against a root frequency.
  static HarmonicAnalysisResult analyze({
    required double userFrequency,
    required double rootFrequency,
    HarmonicRole? forcedRole,
  }) {
    if (userFrequency <= 0.0 || rootFrequency <= 0.0) {
      return HarmonicAnalysisResult(
        userFrequency: userFrequency,
        rootFrequency: rootFrequency,
        role: HarmonicRole.root,
        targetFrequencyJi: rootFrequency,
        centsOffsetFromJi: 0.0,
        centsOffsetFrom12Tet: 0.0,
        beatFrequencyHz: 0.0,
        status: HarmonicLockStatus.pureConsonance,
        tuningAdvice: 'Silencio / Sin señal',
      );
    }

    // 1. Identify modular interval distance in semitones relative to root
    final semitonesRaw = 12.0 * (math.log(userFrequency / rootFrequency) / math.ln2);
    final nearestSemitoneDiff = semitonesRaw.round();
    final modularSemitones = ((nearestSemitoneDiff % 12) + 12) % 12;

    final role = forcedRole ?? HarmonicRole.fromSemitones(modularSemitones);

    // 2. Calculate octave offset to bring target frequency into user's octave register
    final baseTargetInRootOctave = rootFrequency * role.ratio;
    final octaveK = (math.log(userFrequency / baseTargetInRootOctave) / math.ln2).round();
    final targetFrequencyJi = baseTargetInRootOctave * math.pow(2.0, octaveK);

    // 3. Compute cents deviation from Pure JI target
    final centsOffsetFromJi = 1200.0 * (math.log(userFrequency / targetFrequencyJi) / math.ln2);

    // 4. Compute cents deviation from standard 12-TET nominal pitch
    final nominal12TetFreq = rootFrequency * math.pow(2.0, nearestSemitoneDiff / 12.0);
    final centsOffsetFrom12Tet = 1200.0 * (math.log(userFrequency / nominal12TetFreq) / math.ln2);

    // 5. Calculate physical acoustic beat frequency (f_beat = |p * f_root_oct - q * f_user|)
    final rootOctaveFreq = rootFrequency * math.pow(2.0, octaveK);
    final pOvertone = role.numerator * rootOctaveFreq;
    final qOvertone = role.denominator * userFrequency;
    final rawBeat = (pOvertone - qOvertone).abs();

    // 6. Evaluate Harmonic Lock Status & Pedagogical Advice
    final absOffsetJi = centsOffsetFromJi.abs();
    HarmonicLockStatus status;
    String advice;

    if (absOffsetJi <= 3.0) {
      status = HarmonicLockStatus.pureConsonance;
      advice = 'Consonancia Pura: Batimiento anulado.';
    } else if (absOffsetJi <= 12.0) {
      status = HarmonicLockStatus.adjusting;
      if (centsOffsetFromJi > 0) {
        advice = 'Baja tu tono ligeramente (${centsOffsetFromJi.toStringAsFixed(1)} c) para anclar el acorde.';
      } else {
        advice = 'Sube tu tono ligeramente (${centsOffsetFromJi.abs().toStringAsFixed(1)} c) para anclar el acorde.';
      }
    } else {
      status = HarmonicLockStatus.roughness;
      if (centsOffsetFromJi > 0) {
        advice = 'Tono alto (+${centsOffsetFromJi.toStringAsFixed(1)} c). Ajusta hacia abajo.';
      } else {
        advice = 'Tono bajo (-${centsOffsetFromJi.abs().toStringAsFixed(1)} c). Ajusta hacia arriba.';
      }
    }

    return HarmonicAnalysisResult(
      userFrequency: userFrequency,
      rootFrequency: rootFrequency,
      role: role,
      targetFrequencyJi: targetFrequencyJi,
      centsOffsetFromJi: centsOffsetFromJi,
      centsOffsetFrom12Tet: centsOffsetFrom12Tet,
      beatFrequencyHz: rawBeat,
      status: status,
      tuningAdvice: advice,
    );
  }

  /// Calculates target JI frequency directly for a given root and role.
  static double targetFrequency({
    required double rootFrequency,
    required HarmonicRole role,
    int octaveOffset = 0,
  }) {
    return rootFrequency * role.ratio * math.pow(2.0, octaveOffset);
  }
}
