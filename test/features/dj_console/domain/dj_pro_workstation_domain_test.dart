import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_cue_monitor_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_harmonic_camelot_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_loop_and_slip_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/domain/dj_sampler_bank_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_smart_automix_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_stem_isolation_entity.dart';

void main() {
  group('DjStemIsolationEntity Tests', () {
    test('Presets isolate Acapella, Instrumental, Rhythm and reset cleanly', () {
      const initial = DjStemIsolationEntity();
      expect(initial.isBypass, isTrue);

      final acapella = initial.isolateAcapella();
      expect(acapella.isVocalMuted, isFalse);
      expect(acapella.isDrumsMuted, isTrue);
      expect(acapella.isBassMuted, isTrue);
      expect(acapella.isMelodyMuted, isTrue);
      expect(acapella.effectiveVocalGain, equals(1.0));
      expect(acapella.effectiveBassGain, equals(0.0));

      final instrumental = initial.isolateInstrumental();
      expect(instrumental.isVocalMuted, isTrue);
      expect(instrumental.isDrumsMuted, isFalse);
      expect(instrumental.isBassMuted, isFalse);
      expect(instrumental.isMelodyMuted, isFalse);

      final rhythm = initial.isolateRhythm();
      expect(rhythm.isDrumsMuted, isFalse);
      expect(rhythm.isBassMuted, isFalse);
      expect(rhythm.isVocalMuted, isTrue);
      expect(rhythm.isMelodyMuted, isTrue);

      final reset = rhythm.resetAll();
      expect(reset.isBypass, isTrue);
    });
  });

  group('DjHarmonicCamelotEngine Tests', () {
    test('Analyzes Camelot compatibility across wheel relationships', () {
      expect(
        DjHarmonicCamelotEngine.analyzeCompatibility('8A', '8A'),
        equals(CamelotCompatibility.perfectUnison),
      );
      expect(
        DjHarmonicCamelotEngine.analyzeCompatibility('8A', '8B'),
        equals(CamelotCompatibility.relativeSwitch),
      );
      expect(
        DjHarmonicCamelotEngine.analyzeCompatibility('8A', '9A'),
        equals(CamelotCompatibility.harmonicStep),
      );
      expect(
        DjHarmonicCamelotEngine.analyzeCompatibility('12A', '1A'),
        equals(CamelotCompatibility.harmonicStep),
      );
      expect(
        DjHarmonicCamelotEngine.analyzeCompatibility('8A', '10A'),
        equals(CamelotCompatibility.energyBoost),
      );
      expect(
        DjHarmonicCamelotEngine.analyzeCompatibility('8A', '2A'),
        equals(CamelotCompatibility.harmonicClash),
      );
    });

    test('calculateOptimalSemitoneShift finds minimal shift in [-6, +6]', () {
      // 9A (Em, pitchClass 4) -> 8A (Am, pitchClass 9): delta = +5 semitones
      final shift = DjHarmonicCamelotEngine.calculateOptimalSemitoneShift('9A', '8A');
      expect(shift, inInclusiveRange(-6, 6));
      final transposed = DjHarmonicCamelotEngine.transpose('9A', shift);
      expect(transposed.code, equals('8A'));
    });

    test('estimateCamelotKeyFromSamples detects A minor chord/tone accurately', () {
      const sampleRate = 44100;
      final samples = Float32List(sampleRate); // 1 second
      // Synthesize A minor triad (A3=220Hz, C4=261.63Hz, E4=329.63Hz)
      for (int i = 0; i < sampleRate; i++) {
        final t = i / sampleRate;
        samples[i] = (0.4 * math.sin(2.0 * math.pi * 220.0 * t) +
                0.35 * math.sin(2.0 * math.pi * 261.63 * t) +
                0.35 * math.sin(2.0 * math.pi * 329.63 * t))
            .clamp(-1.0, 1.0);
      }
      final key = DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
        samples,
        sampleRate: sampleRate,
      );
      expect(['8A', '8B', '9A'].contains(key.code), isTrue);
    });
  });

  group('DjLoopAndSlipEngine Tests', () {
    test('Computes exact quantized loop duration and respects 1/32 floor', () {
      // At 120 BPM, 1 beat = 500 ms -> 4 beats = 2000 ms
      expect(
        DjLoopAndSlipEngine.computeLoopDurationMs(beats: 4.0, effectiveBpm: 120.0),
        equals(2000),
      );
      expect(DjLoopAndSlipEngine.halveBeats(1.0), equals(0.5));
      expect(DjLoopAndSlipEngine.halveBeats(0.03125), equals(0.03125)); // floor
      expect(DjLoopAndSlipEngine.doubleBeats(8.0), equals(16.0));
      expect(DjLoopAndSlipEngine.doubleBeats(16.0), equals(16.0)); // ceiling
    });

    test('Slip Mode preserves phantom timeline and restores position on loop exit', () {
      final orch = DjPerformanceOrchestrator();
      orch.togglePlay('A');
      orch.toggleSlipMode('A');
      expect(orch.deckA.isSlipModeActive, isTrue);

      orch.engageAutoLoop('A', 0.5); // short 0.5-beat loop
      expect(orch.deckA.isLoopActive, isTrue);

      // Advance playback by 1500 ms (longer than loop length)
      for (int i = 0; i < 15; i++) {
        orch.advanceDeckPlayback('A', 100);
      }

      // Audible playhead wrapped inside loop, while slipPositionMs advanced ~1500ms
      expect(orch.deckA.currentPositionMs, lessThan(orch.deckA.loopEndMs));
      expect(orch.deckA.slipPositionMs, greaterThanOrEqualTo(1400));

      // Exiting loop snaps playhead back to phantom timeline
      orch.exitLoop('A');
      expect(orch.deckA.isLoopActive, isFalse);
      expect(orch.deckA.currentPositionMs, equals(orch.deckA.slipPositionMs));
    });
  });

  group('DjSmartAutomixEngine, Sampler & Split-Cue Tests', () {
    test('Smart Automix interpolates crossfader and executes Bass-Swap at midpoint', () {
      final orch = DjPerformanceOrchestrator();
      orch.setCrossfaderPosition(-1.0);
      orch.startSmartAutomix(AutomixDirection.deckAToDeckB, durationBars: 4);

      expect(orch.automix.isActive, isTrue);
      // At 124 BPM, 4 bars = 16 beats ~= 7742 ms
      // Advance halfway (~3900 ms) -> crossfader near 0.0, Bass-Swap crossing
      orch.advanceAutomix(3900);
      expect(orch.crossfader.position, closeTo(0.0, 0.15));

      // Advance to completion
      orch.advanceAutomix(5000);
      expect(orch.automix.isActive, isFalse);
      expect(orch.crossfader.position, closeTo(1.0, 0.001));
      expect(orch.deckA.gainLow, closeTo(0.25, 0.01));
      expect(orch.deckB.gainLow, closeTo(1.0, 0.01));
    });

    test('Orchestrator executes Pro Workstation DjActions cleanly', () {
      final orch = DjPerformanceOrchestrator();
      orch.executeAction(DjAction.deckAToggleVocalStem);
      expect(orch.deckA.stems.isVocalMuted, isTrue);

      orch.executeAction(DjAction.deckBKeySync);
      expect(
        orch.harmonicCompatibility,
        isNot(equals(CamelotCompatibility.harmonicClash)),
      );

      orch.executeAction(DjAction.triggerSamplerRiser);
      expect(orch.sampler.lastTriggeredPad, equals(DjSamplerPadType.whiteNoiseRiser));
      expect(orch.sampler.triggerSequence, equals(1));

      orch.executeAction(DjAction.toggleSplitCue);
      expect(orch.cueMonitor.isSplitCueActive, isTrue);
    });

    test('DjCueMonitorEntity toggles PFL and Split-Cue immutably', () {
      const cue = DjCueMonitorEntity();
      final updated = cue.toggleCueA().toggleSplitCue().copyWith(cueMasterMix: 0.4);
      expect(updated.cueDeckA, isTrue);
      expect(updated.cueDeckB, isFalse);
      expect(updated.isSplitCueActive, isTrue);
      expect(updated.cueMasterMix, closeTo(0.4, 1e-4));
    });
  });
}
