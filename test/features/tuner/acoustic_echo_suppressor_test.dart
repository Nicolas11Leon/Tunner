import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/acoustic_echo_suppressor.dart';

void main() {
  group('AcousticEchoSuppressor Domain Tests', () {
    late AcousticEchoSuppressor suppressor;

    setUp(() {
      suppressor = AcousticEchoSuppressor(blankingDurationMs: 70);
    });

    test('Allows all pitches when no click has been emitted', () {
      expect(suppressor.shouldSuppressPitch(440.0, timestampMs: 1000), isFalse);
      expect(suppressor.shouldSuppressPitch(2200.0, timestampMs: 1050), isFalse);
      expect(suppressor.shouldSuppressPitch(1400.0, timestampMs: 1100), isFalse);
    });

    test('Suppresses metronome click bleed occurring inside blanking window', () {
      const clickTime = 2000;
      suppressor.notifyClickEmitted(timestampMs: clickTime);

      // Pitch at clickTime + 15ms (peak of click bleed)
      expect(suppressor.shouldSuppressPitch(2200.0, timestampMs: clickTime + 15), isTrue);

      // Pitch at clickTime + 50ms (reverberation of click bleed)
      expect(suppressor.shouldSuppressPitch(1400.0, timestampMs: clickTime + 50), isTrue);

      // Pitch at clickTime + 85ms (outside the 70ms blanking window)
      expect(suppressor.shouldSuppressPitch(440.0, timestampMs: clickTime + 85), isFalse);
    });

    test('Preserves legitimate sustained note during metronome click', () {
      // User has been playing A4 (440 Hz) continuously before the click
      suppressor.shouldSuppressPitch(440.0, timestampMs: 1000);
      suppressor.shouldSuppressPitch(440.5, timestampMs: 1030);

      const clickTime = 1050;
      suppressor.notifyClickEmitted(timestampMs: clickTime);

      // The user continues sustaining A4 (439.8 Hz) through the click window (at 1070ms = clickTime + 20ms)
      expect(
        suppressor.shouldSuppressPitch(439.8, timestampMs: clickTime + 20),
        isFalse,
        reason: 'Sustained user pitch should not be interrupted by click',
      );
    });

    test('Suppresses high-frequency click bleed even if user had played a note earlier', () {
      // User played A4 (440 Hz) at 1000ms
      suppressor.shouldSuppressPitch(440.0, timestampMs: 1000);

      const clickTime = 1050;
      suppressor.notifyClickEmitted(timestampMs: clickTime);

      // At clickTime + 10ms, the microphone receives 2200 Hz from the metronome click
      expect(
        suppressor.shouldSuppressPitch(2200.0, timestampMs: clickTime + 10),
        isTrue,
        reason: 'Bleed frequency differing from sustained note must be suppressed',
      );
    });

    test('Reset clears click timestamps and sustained pitch state', () {
      suppressor.notifyClickEmitted(timestampMs: 5000);
      expect(suppressor.shouldSuppressPitch(2200.0, timestampMs: 5020), isTrue);

      suppressor.reset();

      // After reset, no clicks are active
      expect(suppressor.shouldSuppressPitch(2200.0, timestampMs: 5030), isFalse);
    });
  });
}
