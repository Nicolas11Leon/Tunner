import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/harmonic_tutor/data/harmonic_reference_synth.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';

void main() {
  group('HarmonicReferenceSynth Procedural Audio Tests', () {
    final synth = HarmonicReferenceSynth(sampleRate: 44100);

    test('Synthesizes pure reference chord buffer with correct length and sample bounds', () {
      final buffer = synth.generateChordBuffer(
        rootFrequency: 261.63,
        roles: [HarmonicRole.root, HarmonicRole.perfectFifth],
        durationMs: 500,
        volume: 0.5,
      );

      // 44100 * 0.5 = 22050 samples
      expect(buffer.length, 22050);

      // Verify no NaN or infinite values
      expect(buffer.every((s) => !s.isNaN && !s.isInfinite), isTrue);

      // Verify bounded by [-1.0, 1.0]
      expect(buffer.every((s) => s >= -1.0 && s <= 1.0), isTrue);
    });

    test('Returns empty buffer when parameters are invalid', () {
      final emptyRoot = synth.generateChordBuffer(
        rootFrequency: 0.0,
        roles: [HarmonicRole.root],
      );
      expect(emptyRoot.isEmpty, isTrue);

      final emptyRoles = synth.generateChordBuffer(
        rootFrequency: 440.0,
        roles: [],
      );
      expect(emptyRoles.isEmpty, isTrue);

      final zeroDuration = synth.generateChordBuffer(
        rootFrequency: 440.0,
        roles: [HarmonicRole.root],
        durationMs: 0,
      );
      expect(zeroDuration.isEmpty, isTrue);
    });
  });
}
