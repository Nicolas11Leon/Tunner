import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/domain/mixer_track_entity.dart';

void main() {
  group('MixerConsoleEntity Domain Tests', () {
    test('Default setup initializes metronome and multiple stems independently', () {
      final mixer = MixerConsoleEntity.defaultSetup();
      expect(mixer.metronomeTrack.id, equals('metronome'));
      expect(mixer.metronomeTrack.volume, equals(0.75));
      expect(mixer.stems.length, equals(3));
      expect(mixer.hasAnySolo, isFalse);
    });

    test('Updating track volume updates specific track without altering others', () {
      var mixer = MixerConsoleEntity.defaultSetup();
      mixer = mixer.copyWithTrackVolume('metronome', 0.9);
      mixer = mixer.copyWithTrackVolume('voice', 0.1);

      expect(mixer.metronomeTrack.volume, equals(0.9));
      expect(mixer.stems.firstWhere((t) => t.id == 'voice').volume, equals(0.1));
      expect(mixer.stems.firstWhere((t) => t.id == 'piano').volume, equals(0.80)); // Inalterado
    });

    test('Muting a track sets its effective gain to 0.0', () {
      var mixer = MixerConsoleEntity.defaultSetup();
      mixer = mixer.toggleMute('voice');

      final voiceTrack = mixer.stems.firstWhere((t) => t.id == 'voice');
      expect(voiceTrack.isMuted, isTrue);
      expect(voiceTrack.getEffectiveGain(hasAnySolo: false), equals(0.0));

      final pianoTrack = mixer.stems.firstWhere((t) => t.id == 'piano');
      expect(pianoTrack.getEffectiveGain(hasAnySolo: false), equals(0.80));
    });

    test('Activating solo on a track silences non-solo tracks', () {
      var mixer = MixerConsoleEntity.defaultSetup();
      mixer = mixer.toggleSolo('piano');

      expect(mixer.hasAnySolo, isTrue);

      final voiceTrack = mixer.stems.firstWhere((t) => t.id == 'voice');
      final pianoTrack = mixer.stems.firstWhere((t) => t.id == 'piano');
      final metronomeTrack = mixer.metronomeTrack;

      expect(voiceTrack.getEffectiveGain(hasAnySolo: mixer.hasAnySolo), equals(0.0));
      expect(metronomeTrack.getEffectiveGain(hasAnySolo: mixer.hasAnySolo), equals(0.0));
      expect(pianoTrack.getEffectiveGain(hasAnySolo: mixer.hasAnySolo), equals(0.80));
    });
  });
}
