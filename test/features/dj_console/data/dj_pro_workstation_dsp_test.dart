import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_audio_processor.dart';
import 'package:tunner/features/dj_console/data/dj_transition_sfx_synthesizer.dart';
import 'package:tunner/features/dj_console/domain/dj_sampler_bank_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_stem_isolation_entity.dart';

void main() {
  group('DjAudioProcessor Pro Workstation DSP Tests', () {
    late DjAudioProcessor processor;

    setUp(() {
      processor = DjAudioProcessor(sampleRate: 44100);
    });

    test('applyStemIsolation attenuates low frequency when Bass stem is muted', () {
      const len = 4096;
      final lowSine = Float32List(len);
      for (int i = 0; i < len; i++) {
        lowSine[i] = 0.8 * math.sin(2.0 * math.pi * 60.0 * (i / 44100)); // 60 Hz sub-bass
      }

      final bypassOut = processor.applyStemIsolation(lowSine, const DjStemIsolationEntity());
      final mutedBassOut = processor.applyStemIsolation(
        lowSine,
        const DjStemIsolationEntity(isBassMuted: true),
      );

      double rms(Float32List buf) {
        double sum = 0.0;
        for (final s in buf) {
          sum += s * s;
        }
        return math.sqrt(sum / buf.length);
      }

      expect(rms(mutedBassOut), lessThan(rms(bypassOut) * 0.25));
    });

    test('encodeSplitCueStereo maps Master to Left (even) and Cue to Right (odd)', () {
      final master = Float32List.fromList([0.5, -0.5, 0.25]);
      final cue = Float32List.fromList([-0.8, 0.8, -0.4]);

      final stereo = processor.encodeSplitCueStereo(masterMono: master, cueMono: cue);
      expect(stereo.length, equals(6));
      expect(stereo[0], closeTo(0.5, 1e-4));  // L0 = Master[0]
      expect(stereo[1], closeTo(-0.8, 1e-4)); // R0 = Cue[0]
      expect(stereo[2], closeTo(-0.5, 1e-4)); // L1 = Master[1]
      expect(stereo[3], closeTo(0.8, 1e-4));  // R1 = Cue[1]
    });
  });

  group('DjTransitionSfxSynthesizer Tests', () {
    test('Synthesizes all 8 sampler pads with valid non-clipping PCM samples', () {
      for (final pad in DjSamplerPadType.values) {
        final buf = DjTransitionSfxSynthesizer.generatePadBuffer(pad, sampleRate: 44100);
        expect(buf.isNotEmpty, isTrue);
        for (final s in buf) {
          expect(s, inInclusiveRange(-1.0, 1.0));
        }
      }
    });

    test('computeSpectralWaveformSummary extracts RGB energy buckets', () {
      final groove = DjAudioProcessor().generateDemoGroove(
        bpm: 128.0,
        frequencyHz: 60.0,
        durationMs: 1000,
      );
      final summary = DjTransitionSfxSynthesizer.computeSpectralWaveformSummary(
        groove,
        buckets: 64,
      );
      expect(summary.length, equals(64));
      final maxPeak = summary.map((b) => b.peakAmplitude).reduce(math.max);
      expect(maxPeak, greaterThan(0.1));
    });
  });
}
