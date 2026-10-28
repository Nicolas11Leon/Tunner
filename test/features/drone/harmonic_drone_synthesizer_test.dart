import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/drone/domain/drone_timbre.dart';
import 'package:tunner/features/drone/domain/harmonic_drone_config.dart';
import 'package:tunner/features/drone/domain/harmonic_drone_synthesizer.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';

void main() {
  group('HarmonicDroneConfig Domain Tests', () {
    test('Default constructor sets canonical conservatory practice parameters', () {
      const config = HarmonicDroneConfig();

      expect(config.rootNoteIndex, equals(0)); // Do
      expect(config.octave, equals(3));
      expect(config.includeFifth, isTrue);
      expect(config.includeOctave, isFalse);
      expect(config.timbre, equals(DroneTimbre.warmFlute));
      expect(config.volume, equals(0.7));
      expect(config.harmonicBalance, equals(0.35));

      expect(config.rootDisplayName, equals('Do3'));
      expect(config.fifthDisplayName, equals('Sol3'));
      expect(config.octaveDisplayName, equals('Do4'));
      expect(config.rootMidiNumber, equals(48)); // C3 = (3 + 1) * 12 + 0 = 48
    });

    test('Computes correct MIDI number and display names across octaves and notes', () {
      const configA4 = HarmonicDroneConfig(
        rootNoteIndex: 9, // La
        octave: 4,
        includeFifth: true,
        includeOctave: true,
      );

      expect(configA4.rootDisplayName, equals('La4'));
      expect(configA4.fifthDisplayName, equals('Mi5'));
      expect(configA4.octaveDisplayName, equals('La5'));
      expect(configA4.rootMidiNumber, equals(69)); // A4 = (4 + 1) * 12 + 9 = 69
    });

    test('copyWith and value equality work immutably', () {
      const original = HarmonicDroneConfig();
      final updated = original.copyWith(
        rootNoteIndex: 2, // Re
        timbre: DroneTimbre.richCello,
      );

      expect(updated.rootNoteIndex, equals(2));
      expect(updated.rootDisplayName, equals('Re3'));
      expect(updated.timbre, equals(DroneTimbre.richCello));
      expect(updated.octave, equals(3));
      expect(updated, isNot(equals(original)));

      final restored = updated.copyWith(
        rootNoteIndex: 0,
        timbre: DroneTimbre.warmFlute,
      );
      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
    });

    test('DroneTimbre extension provides human-readable labels and descriptions', () {
      for (final timbre in DroneTimbre.values) {
        expect(timbre.displayName.isNotEmpty, isTrue);
        expect(timbre.description.isNotEmpty, isTrue);
      }
    });
  });

  group('HarmonicDroneSynthesizer Domain Math Tests', () {
    const synth = HarmonicDroneSynthesizer();

    test('calculateFrequencies calculates accurate Hz in 440 Hz Equal Temperament', () {
      const configA3 = HarmonicDroneConfig(
        rootNoteIndex: 9, // La
        octave: 3,
        includeFifth: true,
        includeOctave: true,
      );

      final freqs = synth.calculateFrequencies(config: configA3, a4Ref: 440.0);

      // A3 (MIDI 57) is exactly one octave below A4 (440 / 2 = 220 Hz)
      expect(freqs['fundamental']!, closeTo(220.0, 0.01));
      // Fifth E4 (MIDI 64) in Equal Temperament: 220 * 2^(7/12) = 329.627... Hz
      expect(freqs['fifth']!, closeTo(329.63, 0.05));
      // Octave A4 (MIDI 69) is 440 Hz
      expect(freqs['octave']!, closeTo(440.0, 0.01));
    });

    test('calculateFrequencies respects Baroque 415 Hz pitch calibration', () {
      const configA4 = HarmonicDroneConfig(
        rootNoteIndex: 9, // La
        octave: 4,
        includeFifth: false,
      );

      final freqs = synth.calculateFrequencies(config: configA4, a4Ref: 415.0);
      expect(freqs['fundamental']!, closeTo(415.0, 0.001));
      expect(freqs['fifth']!, equals(0.0));
    });

    test('calculateFrequencies respects historical Just Intonation temperament', () {
      const configC3 = HarmonicDroneConfig(
        rootNoteIndex: 0, // Do
        octave: 3,
        includeFifth: true,
      );

      final justTemperament = TemperamentEngine.justIntonation;
      final freqs = synth.calculateFrequencies(
        config: configC3,
        a4Ref: 440.0,
        temperament: justTemperament,
        temperamentRootKey: 0, // Root C
      );

      final fFund = freqs['fundamental']!;
      final fFifth = freqs['fifth']!;
      // In Just Intonation with root C, Sol (fifth) is a pure 3:2 ratio (+1.96 cents)
      final ratio = fFifth / fFund;
      expect(ratio, closeTo(1.5, 0.002));
    });

    test('synthesizeVoiceSample produces clamped bounded waveforms across all timbres', () {
      for (final timbre in DroneTimbre.values) {
        for (int i = 0; i < 100; i++) {
          final t = i * 0.0001;
          final sample = HarmonicDroneSynthesizer.synthesizeVoiceSample(440.0, t, timbre);
          expect(sample.abs(), lessThanOrEqualTo(1.5));
        }
      }
    });

    test('generateDroneWavBuffer generates valid RIFF/WAVE header and PCM byte structure', () {
      const config = HarmonicDroneConfig(
        rootNoteIndex: 0,
        octave: 3,
        includeFifth: true,
        includeOctave: true,
        timbre: DroneTimbre.warmFlute,
      );

      final wavBytes = synth.generateDroneWavBuffer(
        config: config,
        a4Ref: 440.0,
        sampleRate: 44100,
        durationSeconds: 1.0,
      );

      expect(wavBytes.length, greaterThan(44));

      // Verify "RIFF"
      final riffSignature = utf8.decode(wavBytes.sublist(0, 4));
      expect(riffSignature, equals('RIFF'));

      // Verify "WAVE"
      final waveSignature = utf8.decode(wavBytes.sublist(8, 12));
      expect(waveSignature, equals('WAVE'));

      // Verify PCM format: 1.0 sec * 44100 samples * 2 bytes = 88200 bytes PCM data + 44 bytes header = 88244 bytes
      expect(wavBytes.length, equals(44 + 88200));

      // Verify little-endian 16-bit PCM values are within valid signed range
      final byteData = ByteData.sublistView(wavBytes, 44);
      for (int i = 0; i < 88200 ~/ 2; i++) {
        final val = byteData.getInt16(i * 2, Endian.little);
        expect(val, greaterThanOrEqualTo(-32768));
        expect(val, lessThanOrEqualTo(32767));
      }
    });
  });
}
