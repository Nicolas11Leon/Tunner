import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_clock_service.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_engine.dart';

void main() {
  group('StudioMasterClockService Immediate Beat 1 & Transport Hardening', () {
    test('Beat 1 and downbeat are emitted immediately upon starting transport', () async {
      final clock = StudioMasterClockService(initialBpm: 120.0);

      int firstEmittedBeat = -1;
      bool firstEmittedDownbeat = false;

      final beatSub = clock.onBeat.listen((b) {
        if (firstEmittedBeat == -1) firstEmittedBeat = b;
      });
      final downbeatSub = clock.onDownbeat.listen((db) {
        firstEmittedDownbeat = db;
      });

      clock.startTransport();

      // Esperar breve tick de 15 ms para que el temporizador procese el pulso inicial a t = 0
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(firstEmittedBeat, equals(1));
      expect(firstEmittedDownbeat, isTrue);

      await beatSub.cancel();
      await downbeatSub.cancel();
      clock.stopTransport();
      clock.dispose();
    });

    test('Stopping transport resets phase and beat counters to initial state', () async {
      final clock = StudioMasterClockService(initialBpm: 120.0);
      clock.startTransport();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(clock.isPlaying, isTrue);

      clock.stopTransport();
      expect(clock.isStopped, isTrue);
      expect(clock.currentBeat, equals(1));
      expect(clock.currentMeasure, equals(1));

      clock.dispose();
    });
  });

  group('TapTempoEngine Dynamic Range and Inactivity Hardening', () {
    test('Calculates tempo down to 20 BPM without resetting on slow intervals (3000 ms)', () {
      final engine = TapTempoEngine(minBpm: 20, maxBpm: 300, inactivityTimeoutMs: 3500);

      // Primer toque a t = 0
      final res1 = engine.recordTap(1000000);
      expect(res1.isCalibrated, isFalse);

      // Segundo toque a t = 3000 ms (20 BPM)
      final res2 = engine.recordTap(1003000);
      expect(res2.isCalibrated, isTrue);
      expect(res2.bpm, equals(20));

      // Tercer toque a t = 6000 ms (20 BPM)
      final res3 = engine.recordTap(1006000);
      expect(res3.bpm, equals(20));
    });

    test('Inactivity beyond timeout resets sequence safely', () {
      final engine = TapTempoEngine(minBpm: 20, maxBpm: 300, inactivityTimeoutMs: 3500);

      engine.recordTap(1000000);
      engine.recordTap(1000500); // 120 BPM
      expect(engine.tapCount, equals(2));

      // Pausa mayor a 3500 ms (ej: 4000 ms después)
      final resReset = engine.recordTap(1004500);
      expect(resReset.isCalibrated, isFalse);
      expect(engine.tapCount, equals(1));
    });
  });
}
