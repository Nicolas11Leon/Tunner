import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/sf2_parser.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/sf2_wavetable_oscillator.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/tunner_acoustic_soundfont_bank.dart';
import 'package:tunner/features/audio_synthesizer/data/soundfont_synthesizer_service.dart';

void main() {
  group('Sf2EnvelopeParams and Math Conversion Tests', () {
    test('timecents to seconds conversion complies with SF2 spec', () {
      expect(Sf2EnvelopeParams.timecentsToSeconds(0), closeTo(1.0, 0.001));
      expect(Sf2EnvelopeParams.timecentsToSeconds(1200), closeTo(2.0, 0.001));
      expect(Sf2EnvelopeParams.timecentsToSeconds(-1200), closeTo(0.5, 0.001));
      expect(Sf2EnvelopeParams.timecentsToSeconds(-32768), equals(0.001));
    });

    test('centibels to gain conversion complies with logarithmic attenuation', () {
      expect(Sf2EnvelopeParams.centibelsToGain(0), closeTo(1.0, 0.001));
      expect(Sf2EnvelopeParams.centibelsToGain(200), closeTo(0.1, 0.001));
      expect(Sf2EnvelopeParams.centibelsToGain(1000), equals(0.0));
    });

    test('VolEG evaluation respects Attack, Decay, Sustain and Release stages', () {
      const env = Sf2EnvelopeParams(
        delaySeconds: 0.0,
        attackSeconds: 0.010,
        holdSeconds: 0.010,
        decaySeconds: 0.100,
        sustainLevel: 0.50,
        releaseSeconds: 0.050,
      );

      // Attack midpoint (t = 0.005s) -> 0.5
      expect(Sf2WavetableOscillator.evaluateVolEg(0.005, 1.0, env), closeTo(0.5, 0.02));
      // Hold phase (t = 0.015s) -> 1.0
      expect(Sf2WavetableOscillator.evaluateVolEg(0.015, 1.0, env), closeTo(1.0, 0.01));
      // Sustain phase (t = 0.500s) -> 0.5
      expect(Sf2WavetableOscillator.evaluateVolEg(0.500, 1.0, env), closeTo(0.5, 0.01));
      // Release phase (note duration = 1.0s, t = 1.025s) -> 0.5 * 0.5 = 0.25
      expect(Sf2WavetableOscillator.evaluateVolEg(1.025, 1.0, env), closeTo(0.25, 0.05));
      // Post-release (t = 1.060s) -> 0.0
      expect(Sf2WavetableOscillator.evaluateVolEg(1.060, 1.0, env), equals(0.0));
    });
  });

  group('Hermite 4-Point Cubic Spline Interpolation Tests', () {
    test('interpolates flat signal with zero variance', () {
      final val = Sf2WavetableOscillator.interpolateHermite4(10.0, 10.0, 10.0, 10.0, 0.5);
      expect(val, closeTo(10.0, 0.0001));
    });

    test('interpolates linear ramp accurately at midpoint', () {
      final val = Sf2WavetableOscillator.interpolateHermite4(0.0, 10.0, 20.0, 30.0, 0.5);
      expect(val, closeTo(15.0, 0.0001));
    });

    test('interpolates boundary points t=0 and t=1 smoothly', () {
      final valAt0 = Sf2WavetableOscillator.interpolateHermite4(2.0, 5.0, 12.0, 18.0, 0.0);
      expect(valAt0, closeTo(5.0, 0.0001));

      final valAt1 = Sf2WavetableOscillator.interpolateHermite4(2.0, 5.0, 12.0, 18.0, 1.0);
      expect(valAt1, closeTo(12.0, 0.0001));
    });
  });

  group('TunnerAcousticSoundFontBank & Presets Tests', () {
    test('builds acoustic essentials bank with 5 core instruments', () {
      final bank = TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();

      expect(bank.soundFontName, equals('Tunner Acoustic Essentials'));
      expect(bank.presets.length, equals(8));
      expect(bank.sampleHeaders.length, equals(8));
      expect(bank.sampleData.isNotEmpty, isTrue);

      final presetNames = bank.presets.map((p) => p.name).toList();
      expect(presetNames, containsAll([
        'Grand Piano',
        'Concert Flute',
        'Violin',
        'Cello',
        'Classical Guitar',
        'Steel String Guitar',
        'Electric Guitar Clean',
        'Electric Bass (Finger)',
      ]));

      final patches = bank.presets.map((p) => p.patch).toList();
      expect(patches, containsAll([0, 73, 40, 42, 24, 25, 27, 33]));
    });

    test('findPreset locates requested patch and falls back gracefully', () {
      final bank = TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();
      final flute = bank.findPreset(73);
      expect(flute, isNotNull);
      expect(flute!.name, equals('Concert Flute'));

      final steelGuitar = bank.findPreset(25);
      expect(steelGuitar, isNotNull);
      expect(steelGuitar!.name, equals('Steel String Guitar'));

      final electricBass = bank.findPreset(33);
      expect(electricBass, isNotNull);
      expect(electricBass!.name, equals('Electric Bass (Finger)'));

      final nonExistent = bank.findPreset(999);
      expect(nonExistent, isNotNull); // Fallback al primer preset disponible
      expect(nonExistent!.patch, equals(0));
    });
  });

  group('SoundFontSynthesizerService Rendering Tests', () {
    test('synthesizes valid canonical WAV PCM byte buffer for Middle C (MIDI 60)', () {
      final service = SoundFontSynthesizerService();
      service.selectPatch(0); // Grand Piano

      final wavBytes = service.synthesizeNoteWav(
        midiPitch: 60,
        durationSeconds: 0.5,
        velocity: 100,
        sampleRate: 44100,
      );

      expect(wavBytes.length, greaterThan(44)); // Contiene cabecera RIFF de 44B + PCM data

      // Validar cabecera canónica RIFF/WAVE
      final riffTag = String.fromCharCodes(wavBytes.sublist(0, 4));
      expect(riffTag, equals('RIFF'));

      final waveTag = String.fromCharCodes(wavBytes.sublist(8, 12));
      expect(waveTag, equals('WAVE'));

      final fmtTag = String.fromCharCodes(wavBytes.sublist(12, 16));
      expect(fmtTag, equals('fmt '));

      final dataTag = String.fromCharCodes(wavBytes.sublist(36, 40));
      expect(dataTag, equals('data'));
    });

    test('synthesizes notes across multiple acoustic presets seamlessly', () {
      final service = SoundFontSynthesizerService();

      for (final patch in [0, 73, 40, 42, 24, 25, 27, 33]) {
        service.selectPatch(patch);
        expect(service.activePatch, equals(patch));

        final wav = service.synthesizeNoteWav(
          midiPitch: 69, // A4
          durationSeconds: 0.2,
          velocity: 90,
        );

        expect(wav.isNotEmpty, isTrue);
        expect(wav.length, greaterThan(1000));
      }
    });

    test('synthesizes contemporary guitar and electric bass tones accurately', () {
      final service = SoundFontSynthesizerService();

      // Steel String Guitar (Patch 25)
      service.selectPatch(25);
      final steelWav = service.synthesizeNoteWav(midiPitch: 64, durationSeconds: 0.3); // E4
      expect(steelWav.length, greaterThan(1500));

      // Electric Guitar Clean (Patch 27)
      service.selectPatch(27);
      final electricWav = service.synthesizeNoteWav(midiPitch: 57, durationSeconds: 0.3); // A3
      expect(electricWav.length, greaterThan(1500));

      // Electric Bass Finger (Patch 33) en registro sub-grave
      service.selectPatch(33);
      final bassWav = service.synthesizeNoteWav(midiPitch: 40, durationSeconds: 0.4); // E2
      expect(bassWav.length, greaterThan(2000));
    });

    test('Sf2Parser throws informative error on truncated or invalid data', () {
      const parser = Sf2Parser();
      expect(
        () => parser.parse(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );

      final fakeRiff = Uint8List(16);
      fakeRiff[0] = 0x52; // R
      fakeRiff[1] = 0x49; // I
      fakeRiff[2] = 0x46; // F
      fakeRiff[3] = 0x46; // F
      // sfTag diferente a sfbk
      expect(
        () => parser.parse(fakeRiff),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
