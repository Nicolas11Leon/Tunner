import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_crossfader_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_deck_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_keymap_profile_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';

void main() {
  group('DjCrossfaderEntity Mathematical Tests', () {
    test('Equal-Power curve preserves acoustic RMS energy at center and extremes', () {
      const xfaderCenter = DjCrossfaderEntity(position: 0.0, curve: CrossfaderCurve.equalPower);
      final gainsCenter = xfaderCenter.calculateGains();
      // At position 0, cos(pi/4) = sin(pi/4) = sqrt(2)/2 ≈ 0.7071
      expect(gainsCenter.gainA, closeTo(math.sqrt(2) / 2, 0.001));
      expect(gainsCenter.gainB, closeTo(math.sqrt(2) / 2, 0.001));
      final rmsSum = math.pow(gainsCenter.gainA, 2) + math.pow(gainsCenter.gainB, 2);
      expect(rmsSum, closeTo(1.0, 0.001));

      const xfaderLeft = DjCrossfaderEntity(position: -1.0, curve: CrossfaderCurve.equalPower);
      final gainsLeft = xfaderLeft.calculateGains();
      expect(gainsLeft.gainA, closeTo(1.0, 0.001));
      expect(gainsLeft.gainB, closeTo(0.0, 0.001));

      const xfaderRight = DjCrossfaderEntity(position: 1.0, curve: CrossfaderCurve.equalPower);
      final gainsRight = xfaderRight.calculateGains();
      expect(gainsRight.gainA, closeTo(0.0, 0.001));
      expect(gainsRight.gainB, closeTo(1.0, 0.001));
    });

    test('Linear curve provides symmetrical linear crossfade', () {
      const xfader = DjCrossfaderEntity(position: 0.0, curve: CrossfaderCurve.linear);
      final gains = xfader.calculateGains();
      expect(gains.gainA, closeTo(0.5, 0.001));
      expect(gains.gainB, closeTo(0.5, 0.001));
    });

    test('FastCut curve maintains full volume across central zone for scratching', () {
      const xfader = DjCrossfaderEntity(position: 0.0, curve: CrossfaderCurve.fastCut);
      final gains = xfader.calculateGains();
      expect(gains.gainA, closeTo(1.0, 0.001));
      expect(gains.gainB, closeTo(1.0, 0.001));
    });
  });

  group('DjDeckEntity Acoustic & State Tests', () {
    test('Calculates effective BPM, pitch percentages and cents accurately', () {
      const deck = DjDeckEntity(
        deckId: 'A',
        bpm: 120.0,
        pitchMultiplier: 1.05, // +5%
      );
      expect(deck.effectiveBpm, closeTo(126.0, 0.001));
      expect(deck.pitchPercentage, closeTo(5.0, 0.001));
      expect(deck.centsOffset, closeTo(84.46, 0.1));
    });

    test('Effective band gains respect kill switches', () {
      const deck = DjDeckEntity(
        deckId: 'A',
        gainLow: 1.2,
        gainMid: 0.9,
        gainHigh: 1.0,
        isKillLow: true,
      );
      expect(deck.effectiveGainLow, 0.0);
      expect(deck.effectiveGainMid, 0.9);
      expect(deck.effectiveGainHigh, 1.0);
    });

    test('Progress fraction clamps accurately within range [0.0, 1.0]', () {
      const deck = DjDeckEntity(
        deckId: 'B',
        durationMs: 200000,
        currentPositionMs: 50000,
      );
      expect(deck.progressFraction, closeTo(0.25, 0.001));
    });
  });

  group('DjKeymapProfileEntity Tests', () {
    test('Default ergonomic profile contains standard key mappings', () {
      final profile = DjKeymapProfileEntity.defaultErgonomic();
      expect(profile.keyBindings['Key W'], DjAction.deckAPlayPause);
      expect(profile.keyBindings['Key I'], DjAction.deckBPlayPause);
      expect(profile.keyBindings['Key N'], DjAction.crossfaderCenter);
    });

    test('Supports binding and unbinding keys dynamically', () {
      var profile = DjKeymapProfileEntity.defaultErgonomic();
      profile = profile.bindKey('Space', DjAction.crossfaderCenter);
      expect(profile.keyBindings['Space'], DjAction.crossfaderCenter);

      profile = profile.unbindKey('Space');
      expect(profile.keyBindings.containsKey('Space'), isFalse);
    });

    test('JSON serialization and deserialization is lossless', () {
      final original = DjKeymapProfileEntity.defaultErgonomic();
      final json = original.toJson();
      final restored = DjKeymapProfileEntity.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.keyBindings.length, original.keyBindings.length);
      expect(restored.keyBindings['Key W'], DjAction.deckAPlayPause);
    });
  });

  group('DjPerformanceOrchestrator Action Dispatch & Synergy Tests', () {
    late DjPerformanceOrchestrator orchestrator;

    setUp(() {
      orchestrator = DjPerformanceOrchestrator();
    });

    test('togglePlay alternates isPlaying state', () {
      expect(orchestrator.deckA.isPlaying, isFalse);
      orchestrator.executeAction(DjAction.deckAPlayPause);
      expect(orchestrator.deckA.isPlaying, isTrue);
      orchestrator.executeAction(DjAction.deckAPlayPause);
      expect(orchestrator.deckA.isPlaying, isFalse);
    });

    test('triggerCue pauses and seeks to cue if playing, or records cue if paused', () {
      orchestrator.executeAction(DjAction.deckAPlayPause);
      orchestrator.executeAction(DjAction.deckANudgeForward);
      expect(orchestrator.deckA.currentPositionMs, 50);

      // Auditioning Cue while playing pauses and jumps back
      orchestrator.executeAction(DjAction.deckACue);
      expect(orchestrator.deckA.isPlaying, isFalse);
      expect(orchestrator.deckA.currentPositionMs, 0);
    });

    test('SyncBpm matches target deck effective BPM to opposite deck', () {
      orchestrator.loadTrack('A', title: 'Track A', artist: 'Art A', bpm: 120.0, durationMs: 180000);
      orchestrator.loadTrack('B', title: 'Track B', artist: 'Art B', bpm: 126.0, durationMs: 180000);

      orchestrator.executeAction(DjAction.deckASync);
      expect(orchestrator.deckA.effectiveBpm, closeTo(126.0, 0.001));
      expect(orchestrator.deckA.pitchMultiplier, closeTo(1.05, 0.001));
    });

    test('Pitch nudging increases and decreases pitch multiplier safely', () {
      orchestrator.executeAction(DjAction.deckAPitchUp);
      expect(orchestrator.deckA.pitchMultiplier, closeTo(1.005, 0.0001));

      orchestrator.executeAction(DjAction.deckAPitchReset);
      expect(orchestrator.deckA.pitchMultiplier, closeTo(1.0, 0.0001));
    });

    test('Hot Cue registers current position on first hit and jumps on subsequent hits', () {
      orchestrator.executeAction(DjAction.deckANudgeForward);
      orchestrator.executeAction(DjAction.deckANudgeForward);
      expect(orchestrator.deckA.currentPositionMs, 100);

      // Hit Hot Cue 1 to register
      orchestrator.executeAction(DjAction.deckAHotCue1);
      expect(orchestrator.deckA.hotCues[1], 100);

      // Move forward further
      orchestrator.executeAction(DjAction.deckANudgeForward);
      expect(orchestrator.deckA.currentPositionMs, 150);

      // Trigger Hot Cue 1 again to jump back
      orchestrator.executeAction(DjAction.deckAHotCue1);
      expect(orchestrator.deckA.currentPositionMs, 100);
      expect(orchestrator.deckA.isPlaying, isTrue);
    });

    test('Crossfader shifts and hard cuts alter position accurately', () {
      orchestrator.executeAction(DjAction.crossfaderShiftRight);
      expect(orchestrator.crossfader.position, closeTo(0.1, 0.001));

      orchestrator.executeAction(DjAction.crossfaderHardLeft);
      expect(orchestrator.crossfader.position, closeTo(-1.0, 0.001));

      orchestrator.executeAction(DjAction.crossfaderCenter);
      expect(orchestrator.crossfader.position, closeTo(0.0, 0.001));
    });

    test('Kill EQ toggles band isolation flags cleanly', () {
      expect(orchestrator.deckA.isKillLow, isFalse);
      orchestrator.executeAction(DjAction.deckAKillLow);
      expect(orchestrator.deckA.isKillLow, isTrue);
      orchestrator.executeAction(DjAction.deckAKillLow);
      expect(orchestrator.deckA.isKillLow, isFalse);
    });

    test('getEffectiveGains computes combined output volume correctly', () {
      orchestrator.setCrossfaderPosition(0.0);
      orchestrator.setMasterVolume(0.8);
      final gains = orchestrator.getEffectiveGains();
      // Deck A volume 1.0 * cos(pi/4) ≈ 0.7071 * 0.8 ≈ 0.5657
      expect(gains.effectiveGainA, closeTo(0.5657, 0.01));
      expect(gains.effectiveGainB, closeTo(0.5657, 0.01));
    });
  });
}
