import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/domain/dj_audio_processor.dart';
import 'package:tunner/features/dj_console/domain/dj_stem_isolation_entity.dart';

void main() {
  group('US-2.1 DJ Deck DSP Chain Tests', () {
    late DjAudioProcessor processor;

    setUp(() {
      processor = DjAudioProcessor(sampleRate: 44100);
    });

    test('StatefulDelayLine maintains echo feedback across consecutive audio blocks', () {
      final delay = StatefulDelayLine(maxDelaySamples: 1000);
      final delaySamples = 10;
      final feedback = 0.5;

      // Block 1: Single impulse at index 0 followed by zeros
      final block1 = Float32List(20);
      block1[0] = 1.0;

      final out1 = delay.process(
        input: block1,
        delaySamples: delaySamples,
        feedback: feedback,
        dryWet: 1.0, // 100% wet to inspect echoes directly
      );

      // In block 1, delay of 10 samples means echo appears at sample index 10
      expect(out1[10], closeTo(1.0, 1e-4));
      expect(out1[0], closeTo(0.0, 1e-4));

      // Block 2: Complete silence input [0.0, 0.0, ...]
      final block2 = Float32List(20);
      final out2 = delay.process(
        input: block2,
        delaySamples: delaySamples,
        feedback: feedback,
        dryWet: 1.0,
      );

      // Echo of sample 10 with feedback should appear at sample index 0 in block 2 (10 + 10 = 20 samples from start)
      expect(out2[0], closeTo(0.5, 1e-4));

      // Reset silences line
      delay.reset();
      final outReset = delay.process(
        input: block2,
        delaySamples: delaySamples,
        feedback: feedback,
        dryWet: 1.0,
      );
      expect(outReset.every((sample) => sample == 0.0), isTrue);
    });

    test('3-Band Equalizer produces silence when all bands are killed (0.0)', () {
      final input = Float32List(100);
      for (int i = 0; i < input.length; i++) {
        input[i] = math.sin(2.0 * math.pi * 440.0 * (i / 44100.0));
      }

      final killed = processor.apply3BandEq(
        input,
        eqLow: 0.0,
        eqMid: 0.0,
        eqHigh: 0.0,
      );

      expect(killed.length, equals(input.length));
      expect(killed.every((s) => s == 0.0), isTrue);
    });

    test('Bipolar filter provides smooth low-pass, bypass, and high-pass filtering', () {
      final input = Float32List(200);
      for (int i = 0; i < input.length; i++) {
        // Sum of 50 Hz sub and 8000 Hz high tone
        input[i] = math.sin(2.0 * math.pi * 50.0 * (i / 44100.0)) +
            math.sin(2.0 * math.pi * 8000.0 * (i / 44100.0));
      }

      // Neutral bypass (0.0) returns identical signal
      final bypass = processor.applyBipolarFilter(input, 0.0);
      expect(bypass, equals(input));

      // Low-pass filter (-0.8): attenuates high frequencies (variance decreases)
      final lpf = processor.applyBipolarFilter(input, -0.8);
      double energyInput = input.fold(0.0, (acc, s) => acc + s * s);
      double energyLpf = lpf.fold(0.0, (acc, s) => acc + s * s);
      expect(energyLpf, lessThan(energyInput));

      // High-pass filter (+0.8): attenuates low frequencies
      final hpf = processor.applyBipolarFilter(input, 0.8);
      double energyHpf = hpf.fold(0.0, (acc, s) => acc + s * s);
      expect(energyHpf, lessThan(energyInput));
    });

    test('mixBuffers applies 4-Stem isolation and kills in real time', () {
      final bufferA = processor.generateDemoGroove(
        bpm: 124.0,
        frequencyHz: 55.0,
        durationMs: 500,
      );
      final bufferB = Float32List(bufferA.length); // silent deck B

      // Full mix without isolation
      final fullMix = processor.mixBuffers(
        bufferA: bufferA,
        bufferB: bufferB,
        gainA: 1.0,
        gainB: 0.0,
      );
      final energyFull = fullMix.fold(0.0, (acc, s) => acc + s * s);

      // Bass muted via Stems
      final stemsBassMuted = const DjStemIsolationEntity(isBassMuted: true);
      final bassMutedMix = processor.mixBuffers(
        bufferA: bufferA,
        bufferB: bufferB,
        gainA: 1.0,
        gainB: 0.0,
        stemsA: stemsBassMuted,
      );
      final energyBassMuted = bassMutedMix.fold(0.0, (acc, s) => acc + s * s);
      expect(energyBassMuted, lessThan(energyFull));

      // Acapella isolated: only vocal band remains
      final stemsAcapella = const DjStemIsolationEntity().isolateAcapella();
      final acapellaMix = processor.mixBuffers(
        bufferA: bufferA,
        bufferB: bufferB,
        gainA: 1.0,
        gainB: 0.0,
        stemsA: stemsAcapella,
      );
      final energyAcapella = acapellaMix.fold(0.0, (acc, s) => acc + s * s);
      expect(energyAcapella, lessThan(energyFull));
      expect(energyAcapella, greaterThan(0.0));

      // Total EQ Kill on Deck A
      final killedMix = processor.mixBuffers(
        bufferA: bufferA,
        bufferB: bufferB,
        gainA: 1.0,
        gainB: 0.0,
        eqLowA: 0.0,
        eqMidA: 0.0,
        eqHighA: 0.0,
      );
      expect(killedMix.every((s) => s == 0.0), isTrue);
    });

    test('mixBuffers streams delay feedback across chunks when usePersistentDelay is true', () {
      final chunk1 = Float32List(200);
      chunk1[0] = 1.0; // impulse
      final chunk2 = Float32List(200); // silence
      final emptyB = Float32List(200);

      final mixed1 = processor.mixBuffers(
        bufferA: chunk1,
        bufferB: emptyB,
        gainA: 1.0,
        gainB: 0.0,
        delayActiveA: true,
        delaySamplesA: 100,
        delayFeedbackA: 0.5,
        delayDryWetA: 0.7,
        usePersistentDelay: true,
      );
      expect(mixed1.length, equals(200));

      final mixed2 = processor.mixBuffers(
        bufferA: chunk2,
        bufferB: emptyB,
        gainA: 1.0,
        gainB: 0.0,
        delayActiveA: true,
        delaySamplesA: 100,
        delayFeedbackA: 0.5,
        delayDryWetA: 0.7,
        usePersistentDelay: true,
      );

      // Verify that chunk 2 received the persisting delayed reflections
      final energyChunk2 = mixed2.fold(0.0, (acc, s) => acc + s.abs());
      expect(energyChunk2, greaterThan(0.0));
    });
  });
}
