import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/core/audio/domain/ffi/native_dsp_bridge_fallback.dart';
import 'package:tunner/core/audio/domain/studio_master_clock_service.dart';
import 'package:tunner/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_dsp_chain.dart';
import 'package:tunner/core/terminal/domain/tunner_os_kernel.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/metronome/data/metronome_service.dart';
import 'package:tunner/features/universal_importer/domain/canonical_midi_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ola 1 Regression Tests: DSP, Clock, DJ, DSL & Resource Lifecycle', () {
    test('Asymmetric buffer lengths in vectorSum, processMasterBlock(isMono), and mixChannels do not throw RangeError', () {
      const fallback = NativeDspBridgeFallback();
      final shortBuf = Float32List.fromList([1.0, 2.0]);
      final longBuf = Float32List.fromList([10.0, 20.0, 30.0, 40.0]);
      final outBuf = Float32List(4);

      expect(() => fallback.vectorSum(longBuf, shortBuf, outBuf), returnsNormally);
      expect(outBuf[0], closeTo(11.0, 1e-5));
      expect(outBuf[1], closeTo(22.0, 1e-5));
      expect(outBuf[2], equals(0.0));

      final ffiBridge = NativeDspFfiBridge();
      final chain = StudioMasterDspChain(bridge: ffiBridge);
      final left = Float32List.fromList([2.0, 4.0, 6.0, 8.0]);
      final right = Float32List.fromList([4.0, 6.0]);

      expect(() => chain.processMasterBlock(left, right, isMono: true), returnsNormally);
      expect(left[0], closeTo(3.0, 1e-5));
      expect(right[0], closeTo(3.0, 1e-5));
      expect(left[1], closeTo(5.0, 1e-5));
      expect(right[1], closeTo(5.0, 1e-5));

      final mixOut = Float32List(4);
      expect(() => chain.mixChannels([shortBuf, longBuf], [1.0, 0.5], mixOut), returnsNormally);
      expect(mixOut[0], closeTo(6.0, 1e-5));
      expect(mixOut[1], closeTo(12.0, 1e-5));
      expect(mixOut[2], closeTo(15.0, 1e-5));
      expect(mixOut[3], closeTo(20.0, 1e-5));

      ffiBridge.dispose();
      expect(ffiBridge.isNativeAvailable, isFalse);
    });

    test('StudioMasterClockService live BPM reduction does not freeze or jump measure', () async {
      final clock = StudioMasterClockService(initialBpm: 240.0);
      clock.startTransport();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      final measureBefore = clock.currentMeasure;
      final beatBefore = clock.currentBeat;

      // Reduce BPM sharply mid-playback
      clock.setBpm(60.0);
      expect(clock.currentMeasure, equals(measureBefore));
      expect(clock.currentBeat, equals(beatBefore));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(clock.currentMeasure, greaterThanOrEqualTo(measureBefore));

      clock.dispose();
    });

    test('DjConsoleViewModel normalizes deck_a/A and playDeck/pauseDeck are idempotent', () {
      final dj = DjConsoleViewModel();
      expect(dj.deckA.isPlaying, isFalse);
      expect(dj.deckB.isPlaying, isFalse);

      dj.playDeck('deck_a');
      expect(dj.deckA.isPlaying, isTrue);
      expect(dj.deckB.isPlaying, isFalse);

      // Calling playDeck again must NOT toggle it off
      dj.playDeck('A');
      expect(dj.deckA.isPlaying, isTrue);

      dj.pauseDeck('deck_a');
      expect(dj.deckA.isPlaying, isFalse);

      // Calling pauseDeck again must NOT toggle it on
      dj.pauseDeck('A');
      expect(dj.deckA.isPlaying, isFalse);

      dj.dispose();
    });

    test('TunnerOsKernel propagates late-bound synthVoicePool to kernelBridge and separates dj play/pause', () async {
      String? playedDeck;
      String? pausedDeck;
      final kernel = TunnerOsKernel(
        onDjPlayDeck: (d) => playedDeck = d,
        onDjPauseDeck: (d) => pausedDeck = d,
      );

      final pool = PolyphonicVoicePool();
      kernel.synthVoicePool = pool;
      expect(kernel.kernelBridge.synthVoicePool, same(pool));

      final playRes = await kernel.execute('dj play A');
      expect(playRes.isSuccess, isTrue);
      expect(playedDeck, equals('A'));
      expect(pausedDeck, isNull);

      final pauseRes = await kernel.execute('dj pause A');
      expect(pauseRes.isSuccess, isTrue);
      expect(pausedDeck, equals('A'));

      kernel.dispose();
    });

    test('MetronomeService clamps invalid BPM and cleans up ReceivePort/Isolate on stop', () async {
      final metro = MetronomeService();
      int ticks = 0;
      metro.onSubTick = (_) => ticks++;

      await metro.start(0, ticksPerMeasure: 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await metro.stop();
      expect(ticks, greaterThanOrEqualTo(0));
    });

    test('CanonicalMidiExporter.encodeVlq encodes 32-bit web-safe VLQ values accurately', () {
      expect(CanonicalMidiExporter.encodeVlq(0), equals([0x00]));
      expect(CanonicalMidiExporter.encodeVlq(127), equals([0x7F]));
      expect(CanonicalMidiExporter.encodeVlq(128), equals([0x81, 0x00]));
      expect(CanonicalMidiExporter.encodeVlq(16383), equals([0xFF, 0x7F]));
      expect(CanonicalMidiExporter.encodeVlq(16384), equals([0x81, 0x80, 0x00]));
      expect(CanonicalMidiExporter.encodeVlq(0x0FFFFFFF), equals([0xFF, 0xFF, 0xFF, 0x7F]));
    });
  });
}
