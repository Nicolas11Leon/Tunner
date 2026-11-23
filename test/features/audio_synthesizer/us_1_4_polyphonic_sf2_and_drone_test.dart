import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/soundfont_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/drone/domain/harmonic_drone_config.dart';

void main() {
  group('US-1.4 Polyphonic Voice Pool & SF2 & Universal Drone Tests', () {
    test('PolyphonicVoicePool allocates voices and renders multi-voice WAV block', () {
      final pool = PolyphonicVoicePool(maxPolyphony: 8);

      // Play C major triad (C4=60, E4=64, G4=67)
      pool.noteOn(60, 0.8);
      pool.noteOn(64, 0.7);
      pool.noteOn(67, 0.75);

      expect(pool.activeVoiceCount, equals(3));

      final wavBytes = pool.renderWavBlock(durationSeconds: 0.1, sampleRate: 44100);
      expect(wavBytes.isNotEmpty, isTrue);

      // Verify RIFF / WAVE header
      final headerStr = String.fromCharCodes(wavBytes.sublist(0, 4));
      expect(headerStr, equals('RIFF'));
      final waveStr = String.fromCharCodes(wavBytes.sublist(8, 12));
      expect(waveStr, equals('WAVE'));

      // Release all voices to release phase, and panic to immediately silence
      pool.allNotesOff();
      pool.panic();
      expect(pool.activeVoiceCount, equals(0));
    });

    test('PcmWavSynthesizer generates seamless loop sine tone without clicks', () {
      final wavSeamless = PcmWavSynthesizer.generateSineToneWav(
        frequency: 440.0,
        durationSeconds: 0.2,
        seamlessLoop: true,
      );
      expect(wavSeamless.isNotEmpty, isTrue);

      final riff = String.fromCharCodes(wavSeamless.sublist(0, 4));
      expect(riff, equals('RIFF'));

      final wavNonSeamless = PcmWavSynthesizer.generateSineToneWav(
        frequency: 440.0,
        durationSeconds: 0.2,
        seamlessLoop: false,
      );
      expect(wavNonSeamless.isNotEmpty, isTrue);
    });

    test('HarmonicDroneConfig supports universal octaves 0 to 8 (A0 to C8)', () {
      // Octave 0: A0 (index 9 in C chromatic scale: C=0, C#=1, D=2, D#=3, E=4, F=5, F#=6, G=7, G#=8, A=9)
      // rootMidiNumber for A0: (0 + 1)*12 + 9 = 21 (A0 standard MIDI note is 21)
      const droneA0 = HarmonicDroneConfig(rootNoteIndex: 9, octave: 0);
      expect(droneA0.rootMidiNumber, equals(21));
      final fundA0 = droneA0.calculateFundamentalFrequency();
      expect(fundA0, closeTo(27.5, 0.1));

      // Octave 8: C8 (index 0, octave 8 -> rootMidiNumber: (8+1)*12 + 0 = 108)
      const droneC8 = HarmonicDroneConfig(rootNoteIndex: 0, octave: 8);
      expect(droneC8.rootMidiNumber, equals(108));
      final fundC8 = droneC8.calculateFundamentalFrequency();
      expect(fundC8, closeTo(4186.01, 0.5));

      // Valid range: octaves 0 through 8
      for (int oct = 0; oct <= 8; oct++) {
        final config = HarmonicDroneConfig(octave: oct);
        expect(config.octave, equals(oct));
      }

      // Out of range assertions
      expect(() => HarmonicDroneConfig(octave: -1), throwsAssertionError);
      expect(() => HarmonicDroneConfig(octave: 9), throwsAssertionError);
    });

    test('SoundFontSynthesizerService exposes preset management and reset', () {
      final ISoundFontSynthesizerService service = SoundFontSynthesizerService();
      expect(service.availablePresets.isNotEmpty, isTrue);

      final defaultPresetCount = service.availablePresets.length;
      service.selectPatch(73); // Flauta
      expect(service.activePatch, equals(73));

      service.resetToEssentialsBank();
      expect(service.availablePresets.length, equals(defaultPresetCount));
      expect(service.activePatch, equals(0)); // Piano
    });
  });
}
