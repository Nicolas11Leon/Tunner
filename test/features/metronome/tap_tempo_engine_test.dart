import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_engine.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_result.dart';

void main() {
  group('TapTempoEngine Domain Tests', () {
    late TapTempoEngine engine;

    setUp(() {
      engine = TapTempoEngine();
    });

    test('Initial tap sets tapCount to 1 and isCalibrated to false', () {
      final result = engine.recordTap(1000);

      expect(result.tapCount, equals(1));
      expect(result.isCalibrated, isFalse);
      expect(engine.hasActiveSession, isTrue);
    });

    test('Two taps separated by 500 ms calculate exactly 120 BPM', () {
      engine.recordTap(1000);
      final result = engine.recordTap(1500); // 500 ms delta

      expect(result.tapCount, equals(2));
      expect(result.isCalibrated, isTrue);
      expect(result.bpm, equals(120));
      expect(result.tempoMark.italianName, equals('Allegro'));
    });

    test('Steady taps separated by 1000 ms calculate 60 BPM with near-zero jitter', () {
      int time = 0;
      TapTempoResult? lastResult;

      for (int i = 0; i < 5; i++) {
        lastResult = engine.recordTap(time);
        time += 1000;
      }

      expect(lastResult, isNotNull);
      expect(lastResult!.bpm, equals(60));
      expect(lastResult.jitterMs, lessThan(1.0));
      expect(lastResult.stabilityDescription, contains('Metronómico'));
      expect(lastResult.tempoMark.italianName, equals('Adagio'));
    });

    test('Fast steady taps separated by 250 ms calculate 240 BPM', () {
      int time = 1000;
      TapTempoResult? lastResult;

      for (int i = 0; i < 4; i++) {
        lastResult = engine.recordTap(time);
        time += 250;
      }

      expect(lastResult!.bpm, equals(240));
      expect(lastResult.tempoMark.italianName, equals('Prestissimo'));
    });

    test('Inactivity exceeding 2500 ms resets the engine session', () {
      engine.recordTap(1000);
      engine.recordTap(1500); // 120 BPM
      expect(engine.tapCount, equals(2));

      // Wait 3000 ms (greater than default 2500 ms timeout)
      final resetResult = engine.recordTap(4500);

      expect(resetResult.tapCount, equals(1));
      expect(resetResult.isCalibrated, isFalse);
    });

    test('Irregular taps calculate non-zero jitter and appropriate stability label', () {
      engine.recordTap(0);
      engine.recordTap(450);  // delta 450
      engine.recordTap(1000); // delta 550
      final result = engine.recordTap(1480); // delta 480

      expect(result.tapCount, equals(4));
      expect(result.jitterMs, greaterThan(15.0));
      expect(result.jitterPercentage, greaterThan(2.0));
    });

    test('Clamps BPM strictly between minBpm (30) and maxBpm (300)', () {
      // Very fast (100 ms = 600 BPM)
      engine.recordTap(0);
      final fastResult = engine.recordTap(100);
      expect(fastResult.bpm, equals(300));

      engine.reset();

      // Very slow (2300 ms = 26 BPM)
      engine.recordTap(0);
      final slowResult = engine.recordTap(2300);
      expect(slowResult.bpm, equals(30));
    });

    test('reset clears internal timestamps and intervals', () {
      engine.recordTap(1000);
      engine.recordTap(1500);
      expect(engine.hasActiveSession, isTrue);

      engine.reset();
      expect(engine.hasActiveSession, isFalse);
      expect(engine.tapCount, equals(0));
    });
  });
}
