import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/features/dj_console/data/dj_deck_audio_service.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/vector_jog_wheel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DJ Tactile Fluidity, Jog Wheel Scrub & Volume Pipeline Tests (UC-98)', () {
    testWidgets('VectorJogWheel polar gesture calculates accurate angular delta', (tester) async {
      double capturedDelta = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VectorJogWheel(
                deckLabel: 'A',
                accentColor: const Color(0xFF00E5FF),
                isPlaying: true,
                rotationAngle: 0.0,
                onScratch: (delta) {
                  capturedDelta += delta;
                },
              ),
            ),
          ),
        ),
      );

      final wheelFinder = find.byType(VectorJogWheel);
      expect(wheelFinder, findsOneWidget);

      final center = tester.getCenter(wheelFinder);

      // Start drag at top edge (center.dx, center.dy - 60)
      final gesture = await tester.startGesture(Offset(center.dx, center.dy - 60));
      await tester.pump();

      // Drag clockwise towards right edge (center.dx + 60, center.dy)
      await gesture.moveTo(Offset(center.dx + 60, center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Clockwise drag must produce positive angular delta
      expect(capturedDelta, greaterThan(0.5));
    });

    testWidgets('VectorJogWheel counter-clockwise drag rewinds with negative delta', (tester) async {
      double capturedDelta = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VectorJogWheel(
                deckLabel: 'A',
                accentColor: const Color(0xFF00E5FF),
                isPlaying: true,
                rotationAngle: 0.0,
                onScratch: (delta) {
                  capturedDelta += delta;
                },
              ),
            ),
          ),
        ),
      );

      final wheelFinder = find.byType(VectorJogWheel);
      final center = tester.getCenter(wheelFinder);

      // Start at right edge, drag counter-clockwise up to top edge
      final gesture = await tester.startGesture(Offset(center.dx + 60, center.dy));
      await tester.pump();

      await gesture.moveTo(Offset(center.dx, center.dy - 60));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Counter-clockwise drag must produce negative delta radians
      expect(capturedDelta, lessThan(-0.5));
    });

    test('DjConsoleViewModel scratchDeck rewinds playback when rotating backwards', () {
      final vm = DjConsoleViewModel();

      // Set initial position to 5000 ms
      vm.seekDeck('A', 5000);
      expect(vm.deckA.currentPositionMs, equals(5000));

      // Rewind wheel backwards by -1.5 radians
      vm.scratchDeck('A', -1.5);

      // Position must have decreased (rewound)
      expect(vm.deckA.currentPositionMs, lessThan(5000));
      expect(vm.deckA.currentPositionMs, greaterThan(0));

      // Forward scrub advances position
      final prevPos = vm.deckA.currentPositionMs;
      vm.scratchDeck('A', 2.0);
      expect(vm.deckA.currentPositionMs, greaterThan(prevPos));

      vm.dispose();
    });

    test('DjPerformanceOrchestrator setDeckVolume modulates channel gain correctly', () {
      final orch = DjPerformanceOrchestrator();

      expect(orch.deckA.volume, equals(1.0));
      orch.setDeckVolume('A', 0.65);
      expect(orch.deckA.volume, equals(0.65));

      // At center crossfader position with equal-power curve (cos(pi/4) ~ 0.7071)
      final gainsCenter = orch.getEffectiveGains();
      expect(gainsCenter.effectiveGainA, closeTo(0.65 * 0.7071, 0.01));

      // Shift crossfader hard left to Deck A (-1.0)
      orch.setCrossfaderPosition(-1.0);
      final gainsHardLeft = orch.getEffectiveGains();
      expect(gainsHardLeft.effectiveGainA, closeTo(0.65, 0.01));

      // Zero attenuation check
      orch.setDeckVolume('A', 0.0);
      expect(orch.deckA.volume, equals(0.0));
      expect(orch.getEffectiveGains().effectiveGainA, equals(0.0));
    });

    test('DjDeckAudioService setDeckVolume handles rapid mute and unmute stably', () async {
      final audioService = DjDeckAudioService(audioEngine: MemoryStudioAudioEngine());

      await audioService.playDeck('A');
      expect(audioService.isDeckPlaying('A'), isTrue);

      // Rapid slider drag simulation to 0 and back to 1.0
      await audioService.setDeckVolume('A', 0.8);
      await audioService.setDeckVolume('A', 0.4);
      await audioService.setDeckVolume('A', 0.0);
      await audioService.setDeckVolume('A', 0.5);
      await audioService.setDeckVolume('A', 1.0);

      // Deck must remain in playing state
      expect(audioService.isDeckPlaying('A'), isTrue);

      audioService.dispose();
    });

    test('DjConsoleViewModel rewindDeck, fastForwardDeck and jumpToStart operate intuitively', () {
      final vm = DjConsoleViewModel();

      // Start at 20000 ms (20 seconds)
      vm.seekDeck('A', 20000);
      expect(vm.deckA.currentPositionMs, equals(20000));

      // Rewind 5 seconds
      vm.rewindDeck('A', milliseconds: 5000);
      expect(vm.deckA.currentPositionMs, equals(15000));

      // Rewind 10 seconds
      vm.rewindDeck('A', milliseconds: 10000);
      expect(vm.deckA.currentPositionMs, equals(5000));

      // Fast-forward 5 seconds
      vm.fastForwardDeck('A', milliseconds: 5000);
      expect(vm.deckA.currentPositionMs, equals(10000));

      // Jump to start (00:00)
      vm.jumpToStart('A');
      expect(vm.deckA.currentPositionMs, equals(0));
      expect(vm.rotationAngleA, equals(0.0));

      // Adjust volume up and down
      expect(vm.deckA.volume, equals(1.0));
      vm.adjustDeckVolume('A', -0.10);
      expect(vm.deckA.volume, closeTo(0.90, 0.001));

      vm.adjustDeckVolume('A', 0.05);
      expect(vm.deckA.volume, closeTo(0.95, 0.001));

      vm.dispose();
    });
  });
}
