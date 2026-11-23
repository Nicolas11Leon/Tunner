import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/offline_wav_decoder.dart';
import 'package:tunner/features/dj_console/domain/dj_console_headless_controller.dart';
import 'package:tunner/features/dj_console/domain/dj_crossfader_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_harmonic_camelot_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_mix_wav_encoder.dart';
import 'package:tunner/features/dj_console/domain/dj_smart_automix_engine.dart';

Float32List _generateChordSamples({
  required List<double> freqsHz,
  required int sampleRate,
  required double durationSeconds,
  double amplitude = 0.5,
}) {
  final count = (sampleRate * durationSeconds).round();
  final samples = Float32List(count);
  final scale = amplitude / freqsHz.length;
  for (int i = 0; i < count; i++) {
    final t = i / sampleRate;
    double sum = 0.0;
    for (final f in freqsHz) {
      sum += math.sin(2.0 * math.pi * f * t);
    }
    samples[i] = sum * scale;
  }
  return samples;
}

Uint8List _encodeMonoWav(Float32List samples, {int sampleRate = 44100}) {
  return DjMixWavEncoder.encode(
    samples: samples,
    sampleRate: sampleRate,
    numChannels: 1,
  );
}

void main() {
  group('DjHarmonicCamelotEngine multi-window estimation', () {
    test('skips percussive/silent intro on longer tracks and detects C major (8B)', () {
      const sampleRate = 22050;
      const totalSeconds = 5;
      final samples = Float32List(sampleRate * totalSeconds);

      // First 1.2s: percussive noise burst (no tonal content)
      final introSamples = (sampleRate * 1.2).round();
      for (int i = 0; i < introSamples; i++) {
        // Deterministic pseudo-random noise
        final noise = (((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0;
        samples[i] = noise * 0.25;
      }

      // Remaining 3.8s: strong C major triad (C3, E3, G3, C4, E4, G4)
      const cMajorFreqs = [130.81, 164.81, 196.00, 261.63, 329.63, 392.00];
      for (int i = introSamples; i < samples.length; i++) {
        final t = i / sampleRate;
        double sum = 0.0;
        for (final f in cMajorFreqs) {
          sum += math.sin(2.0 * math.pi * f * t);
        }
        samples[i] = (sum / cMajorFreqs.length) * 0.6;
      }

      final detected = DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
        samples,
        sampleRate: sampleRate,
      );

      // C major is 8B (or relative minor 8A share pitch classes; C major triad strongly matches 8B)
      expect(detected.code, equals('8B'));
    });

    test('maintains backward compatibility on short 1-second buffers', () {
      const sampleRate = 22050;
      final shortSamples = _generateChordSamples(
        freqsHz: [220.0, 261.63, 329.63, 440.0], // A minor triad
        sampleRate: sampleRate,
        durationSeconds: 1.0,
      );

      final detected = DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
        shortSamples,
        sampleRate: sampleRate,
      );

      expect(detected.code, equals('8A'));
    });
  });

  group('DjConsoleHeadlessController', () {
    test('loads WAV bytes via OfflineWavDecoder, analyzes BPM/Camelot, and updates DSP state', () {
      final controller = DjConsoleHeadlessController();
      const sampleRate = 22050;
      final samplesA = _generateChordSamples(
        freqsHz: [220.0, 261.63, 329.63],
        sampleRate: sampleRate,
        durationSeconds: 2.0,
      );
      final wavA = _encodeMonoWav(samplesA, sampleRate: sampleRate);

      final analysis = controller.loadWavBytes(
        'A',
        wavA,
        title: 'Test Minor Pad',
        artist: 'Tunner Lab',
      );

      expect(analysis.deckId, equals('A'));
      expect(analysis.sampleRate, equals(sampleRate));
      expect(analysis.durationMs, closeTo(2000, 20));
      expect(analysis.camelotKey.code, equals('8A'));
      expect(controller.deckA.trackTitle, equals('Test Minor Pad'));

      // Control crossfader, EQ, trim, and loops
      controller.setCrossfaderPosition(-0.5);
      controller.setCrossfaderCurve(CrossfaderCurve.equalPower);
      controller.setTrim('A', 1.25);
      controller.setEqGains('A', low: 0.8, mid: 1.1, high: 0.9);
      controller.engageAutoLoop('A', 4.0);

      expect(controller.crossfader.position, closeTo(-0.5, 1e-6));
      expect(controller.deckA.trim, closeTo(1.25, 1e-6));
      expect(controller.deckA.gainLow, closeTo(0.8, 1e-6));
      expect(controller.deckA.isLoopActive, isTrue);
      expect(controller.deckA.loopBeats, equals(4.0));

      final snapshot = controller.toJson();
      expect(snapshot['deckA']['title'], equals('Test Minor Pad'));
      expect(snapshot['deckA']['loop']['isActive'], isTrue);
    });

    test('renderAutomixTransitionWav produces valid stereo WAV transitioning Deck A to Deck B', () {
      const sampleRate = 22050;
      final controller = DjConsoleHeadlessController(defaultSampleRate: sampleRate);

      // Deck A: 220 Hz sine, Deck B: 660 Hz sine (both 4 seconds)
      final samplesA = _generateChordSamples(
        freqsHz: [220.0],
        sampleRate: sampleRate,
        durationSeconds: 4.0,
        amplitude: 0.6,
      );
      final samplesB = _generateChordSamples(
        freqsHz: [660.0],
        sampleRate: sampleRate,
        durationSeconds: 4.0,
        amplitude: 0.6,
      );

      controller.loadWavBytes('A', _encodeMonoWav(samplesA, sampleRate: sampleRate), autoAnalyze: false);
      controller.loadWavBytes('B', _encodeMonoWav(samplesB, sampleRate: sampleRate), autoAnalyze: false);

      // 1 bar at 120 BPM = 2.0 seconds
      final wavBytes = controller.renderAutomixTransitionWav(
        direction: AutomixDirection.deckAToDeckB,
        durationBars: 1,
        referenceBpm: 120.0,
        enableBassSwap: true,
        sampleRate: sampleRate,
      );

      final decoded = OfflineWavDecoder.decode(wavBytes);
      expect(decoded.channels, equals(2));
      expect(decoded.sampleRate, equals(sampleRate));
      expect(decoded.bitsPerSample, equals(16));
      expect(decoded.durationSeconds, closeTo(2.0, 0.05));

      // Verify non-silent audio throughout the transition
      double rms = 0.0;
      for (final s in decoded.samples) {
        rms += s * s;
      }
      rms = math.sqrt(rms / decoded.samples.length);
      expect(rms, greaterThan(0.1));
    });
  });
}
