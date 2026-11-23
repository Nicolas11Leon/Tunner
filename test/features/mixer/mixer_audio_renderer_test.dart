import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/offline_wav_decoder.dart';
import 'package:tunner/features/mixer/domain/mixer_audio_renderer.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';

Float64List _constantSignal(int length, double value) {
  final buf = Float64List(length);
  for (int i = 0; i < length; i++) {
    buf[i] = value;
  }
  return buf;
}

void main() {
  group('MixerConsoleEntity extended mutations', () {
    test('copyWithTrackPan updates target track and clamps to [-1.0, 1.0]', () {
      final console = MixerConsoleEntity.defaultSetup();
      final panned = console
          .copyWithTrackPan('voice', -0.75)
          .copyWithTrackPan('metronome', 2.5);

      expect(panned.stems.firstWhere((t) => t.id == 'voice').pan, closeTo(-0.75, 1e-9));
      expect(panned.metronomeTrack.pan, equals(1.0));
    });

    test('addStem, removeStem, and resetAll behave deterministically', () {
      final console = MixerConsoleEntity.defaultSetup()
          .addStem(const AudioTrack(id: 'bass', title: 'Bajo', instrumentIcon: 'bass', volume: 0.9, pan: -0.5))
          .toggleMute('voice')
          .toggleSolo('piano');

      expect(console.stems.any((t) => t.id == 'bass'), isTrue);
      expect(console.hasAnySolo, isTrue);

      final removed = console.removeStem('bass');
      expect(removed.stems.any((t) => t.id == 'bass'), isFalse);

      final reset = console.resetAll();
      expect(reset.hasAnySolo, isFalse);
      expect(reset.stems.every((t) => !t.isMuted && !t.isSolo && t.pan == 0.0), isTrue);
    });
  });

  group('MixerAudioRenderer', () {
    const renderer = MixerAudioRenderer();

    test('applies constant-power pan law accurately (hard left, center, hard right)', () {
      final leftGains = MixerAudioRenderer.computeConstantPowerPanGains(-1.0);
      final centerGains = MixerAudioRenderer.computeConstantPowerPanGains(0.0);
      final rightGains = MixerAudioRenderer.computeConstantPowerPanGains(1.0);

      expect(leftGains.left, closeTo(1.0, 1e-6));
      expect(leftGains.right, closeTo(0.0, 1e-6));

      expect(centerGains.left, closeTo(math.sqrt1_2, 1e-6));
      expect(centerGains.right, closeTo(math.sqrt1_2, 1e-6));
      expect(
        (centerGains.left * centerGains.left) + (centerGains.right * centerGains.right),
        closeTo(1.0, 1e-6),
      );

      expect(rightGains.left, closeTo(0.0, 1e-6));
      expect(rightGains.right, closeTo(1.0, 1e-6));
    });

    test('mixes hard-left and hard-right tracks into separate stereo WAV channels', () {
      final console = const MixerConsoleEntity(
        metronomeTrack: AudioTrack(id: 'metronome', title: 'Metro', instrumentIcon: 'timer', volume: 0.0),
        stems: [
          AudioTrack(id: 'left_stem', title: 'Left', instrumentIcon: 'guitar', volume: 0.5, pan: -1.0),
          AudioTrack(id: 'right_stem', title: 'Right', instrumentIcon: 'piano', volume: 0.25, pan: 1.0),
        ],
      );

      final result = renderer.render(
        console: console,
        trackSamples: {
          'left_stem': _constantSignal(512, 1.0),
          'right_stem': _constantSignal(512, 1.0),
        },
        sampleRate: 44100,
      );

      final decoded = OfflineWavDecoder.decode(result.wavBytes);
      expect(decoded.channels, equals(2));
      expect(decoded.frameCount, equals(512));
      expect(decoded.channelSamples[0][100], closeTo(0.5, 1e-3));
      expect(decoded.channelSamples[1][100], closeTo(0.25, 1e-3));
    });

    test('respects mute and solo exclusivity when rendering', () {
      final base = const MixerConsoleEntity(
        metronomeTrack: AudioTrack(id: 'metronome', title: 'Metro', instrumentIcon: 'timer', volume: 0.5),
        stems: [
          AudioTrack(id: 'track_a', title: 'A', instrumentIcon: 'mic', volume: 0.5, pan: -1.0),
          AudioTrack(id: 'track_b', title: 'B', instrumentIcon: 'piano', volume: 0.5, pan: 1.0),
        ],
      );

      // Mute track_a -> left channel must be silent, right channel has track_b
      final mutedConsole = base.setTrackMute('track_a', true).setTrackMute('metronome', true);
      final mutedRes = renderer.render(
        console: mutedConsole,
        trackSamples: {
          'track_a': _constantSignal(256, 1.0),
          'track_b': _constantSignal(256, 1.0),
        },
      );
      final decodedMuted = OfflineWavDecoder.decode(mutedRes.wavBytes);
      expect(decodedMuted.channelSamples[0][10], closeTo(0.0, 1e-4));
      expect(decodedMuted.channelSamples[1][10], closeTo(0.5, 1e-3));

      // Solo track_a -> right channel must be silent, left channel has track_a
      final soloConsole = base.toggleSolo('track_a');
      final soloRes = renderer.render(
        console: soloConsole,
        trackSamples: {
          'track_a': _constantSignal(256, 1.0),
          'track_b': _constantSignal(256, 1.0),
        },
      );
      final decodedSolo = OfflineWavDecoder.decode(soloRes.wavBytes);
      expect(decodedSolo.channelSamples[0][10], closeTo(0.5, 1e-3));
      expect(decodedSolo.channelSamples[1][10], closeTo(0.0, 1e-4));
    });

    test('renderWavTracks decodes input WAV buffers via OfflineWavDecoder and mixes cleanly', () {
      final console = const MixerConsoleEntity(
        metronomeTrack: AudioTrack(id: 'metronome', title: 'Metro', instrumentIcon: 'timer', volume: 0.0),
        stems: [
          AudioTrack(id: 'stem1', title: 'Stem 1', instrumentIcon: 'mic', volume: 0.8, pan: 0.0),
        ],
      );

      final wav1 = MixerAudioRenderer.encodeStereoPcm16Wav(
        interleavedStereo: Float32List.fromList(List.filled(512, 0.5)),
        sampleRate: 44100,
      );

      final result = renderer.renderWavTracks(
        console: console,
        trackWavBytes: {'stem1': wav1},
        sampleRate: 44100,
      );

      expect(result.frameCount, equals(256));
      expect(result.peakAmplitude, greaterThan(0.25));
      expect(result.peakAmplitude, lessThanOrEqualTo(1.0));
    });
  });
}
