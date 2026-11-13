import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/harmonic_tutor/domain/just_intonation_calculator.dart';

void main() {
  group('HarmonicRole Entity Mathematical Standards', () {
    test('Verifies canonical Just Intonation ratios and 12-TET offsets', () {
      // Root: 1/1, 0.0 cents
      expect(HarmonicRole.root.ratio, 1.0);
      expect(HarmonicRole.root.tetOffsetCents, 0.0);

      // Major Third: 5/4 = 1.25, 386.31 cents (-13.69 cents relative to 400 cents)
      expect(HarmonicRole.majorThird.ratio, 1.25);
      expect(HarmonicRole.majorThird.justCents, closeTo(386.31, 0.01));
      expect(HarmonicRole.majorThird.tetOffsetCents, closeTo(-13.69, 0.01));

      // Minor Third: 6/5 = 1.20, 315.64 cents (+15.64 cents relative to 300 cents)
      expect(HarmonicRole.minorThird.ratio, 1.20);
      expect(HarmonicRole.minorThird.justCents, closeTo(315.64, 0.01));
      expect(HarmonicRole.minorThird.tetOffsetCents, closeTo(15.64, 0.01));

      // Perfect Fifth: 3/2 = 1.50, 701.96 cents (+1.96 cents relative to 700 cents)
      expect(HarmonicRole.perfectFifth.ratio, 1.50);
      expect(HarmonicRole.perfectFifth.justCents, closeTo(701.96, 0.01));
      expect(HarmonicRole.perfectFifth.tetOffsetCents, closeTo(1.96, 0.01));

      // Harmonic Seventh: 7/4 = 1.75, 968.83 cents (-31.17 cents relative to 1000 cents)
      expect(HarmonicRole.harmonicSeventh.ratio, 1.75);
      expect(HarmonicRole.harmonicSeventh.justCents, closeTo(968.83, 0.01));
      expect(HarmonicRole.harmonicSeventh.tetOffsetCents, closeTo(-31.17, 0.01));
    });

    test('Maps modular semitones to correct harmonic role', () {
      expect(HarmonicRole.fromSemitones(0), HarmonicRole.root);
      expect(HarmonicRole.fromSemitones(4), HarmonicRole.majorThird);
      expect(HarmonicRole.fromSemitones(7), HarmonicRole.perfectFifth);
      expect(HarmonicRole.fromSemitones(10), HarmonicRole.harmonicSeventh);
      expect(HarmonicRole.fromSemitones(16), HarmonicRole.majorThird); // 16 % 12 = 4
    });
  });

  group('JustIntonationCalculator Acoustic Analysis', () {
    const rootC4 = 261.63; // Middle C

    test('Identifies pure Major Third with Zero Beat Lock', () {
      // Pure 5/4 third: 261.63 * 1.25 = 327.0375 Hz
      final pureThirdFreq = rootC4 * 1.25;

      final result = JustIntonationCalculator.analyze(
        userFrequency: pureThirdFreq,
        rootFrequency: rootC4,
      );

      expect(result.role, HarmonicRole.majorThird);
      expect(result.targetFrequencyJi, closeTo(pureThirdFreq, 0.001));
      expect(result.centsOffsetFromJi, closeTo(0.0, 0.01));
      expect(result.beatFrequencyHz, closeTo(0.0, 0.01));
      expect(result.status, HarmonicLockStatus.pureConsonance);
      expect(result.isLocked, isTrue);
    });

    test('Detects 12-TET Major Third beating and roughness', () {
      // 12-TET third: 261.63 * 2^(4/12) ≈ 329.6275 Hz (+13.69 cents above pure JI)
      final tetThirdFreq = rootC4 * 1.25992104989;

      final result = JustIntonationCalculator.analyze(
        userFrequency: tetThirdFreq,
        rootFrequency: rootC4,
      );

      expect(result.role, HarmonicRole.majorThird);
      expect(result.centsOffsetFromJi, closeTo(13.69, 0.05));
      // f_beat = |5 * 261.63 - 4 * 329.6275| = |1308.15 - 1318.51| ≈ 10.36 Hz
      expect(result.beatFrequencyHz, closeTo(10.36, 0.2));
      expect(result.status, HarmonicLockStatus.roughness);
      expect(result.isLocked, isFalse);
    });

    test('Normalizes octave shifts accurately for high soprano register', () {
      // Pure 5/4 third one octave higher (E5): 261.63 * 1.25 * 2 = 654.075 Hz
      final highThird = rootC4 * 1.25 * 2.0;

      final result = JustIntonationCalculator.analyze(
        userFrequency: highThird,
        rootFrequency: rootC4,
      );

      expect(result.role, HarmonicRole.majorThird);
      expect(result.targetFrequencyJi, closeTo(highThird, 0.001));
      expect(result.centsOffsetFromJi, closeTo(0.0, 0.01));
      expect(result.status, HarmonicLockStatus.pureConsonance);
    });

    test('Handles zero or negative frequencies gracefully without throwing', () {
      final resultZero = JustIntonationCalculator.analyze(userFrequency: 0.0, rootFrequency: rootC4);
      expect(resultZero.status, HarmonicLockStatus.pureConsonance);

      final resultNeg = JustIntonationCalculator.analyze(userFrequency: -100.0, rootFrequency: rootC4);
      expect(resultNeg.status, HarmonicLockStatus.pureConsonance);
    });
  });
}
