import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_pitch_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_multitone_detector.dart';

void main() {
  group('DetectedPolyphonicVoice & Result Domain Tests', () {
    test('DetectedPolyphonicVoice formats cents and frequencies cleanly', () {
      const voiceA = DetectedPolyphonicVoice(
        noteName: 'Do',
        noteNameInternational: 'C',
        octave: 4,
        pitchClassIndex: 0,
        frequencyHz: 261.63,
        midiNumber: 60,
        centsDeviation: 2.4,
        salience: 0.95,
        harmonicRole: 'Fundamental (Raíz)',
      );

      expect(voiceA.fullNoteName, 'Do4');
      expect(voiceA.fullNoteNameInternational, 'C4');
      expect(voiceA.formattedCents, '+2 cents');
      expect(voiceA.formattedFrequency, '261.6 Hz');

      const voiceB = DetectedPolyphonicVoice(
        noteName: 'Sol',
        noteNameInternational: 'G',
        octave: 4,
        pitchClassIndex: 7,
        frequencyHz: 391.2,
        midiNumber: 67,
        centsDeviation: -3.8,
        salience: 0.80,
        harmonicRole: 'Quinta Justa',
      );

      expect(voiceB.formattedCents, '-4 cents');
      expect(voiceB.fullNoteName, 'Sol4');
    });

    test('PolyphonicMultiToneAnalysisResult identifies bass and soprano voices', () {
      const bass = DetectedPolyphonicVoice(
        noteName: 'Mi',
        noteNameInternational: 'E',
        octave: 2,
        pitchClassIndex: 4,
        frequencyHz: 82.4,
        midiNumber: 40,
        centsDeviation: 0.0,
        salience: 1.0,
        harmonicRole: 'Fundamental (Raíz)',
      );

      const soprano = DetectedPolyphonicVoice(
        noteName: 'Mi',
        noteNameInternational: 'E',
        octave: 4,
        pitchClassIndex: 4,
        frequencyHz: 329.6,
        midiNumber: 64,
        centsDeviation: 1.0,
        salience: 0.7,
        harmonicRole: 'Fundamental (Raíz)',
      );

      final result = PolyphonicMultiToneAnalysisResult(
        voices: [bass, soprano],
        chord: ChordEntity.none,
        voicingName: 'Octavas Abiertas',
        isSilence: false,
      );

      expect(result.polyphonyCount, 2);
      expect(result.hasVoices, isTrue);
      expect(result.bassVoice?.fullNoteNameInternational, 'E2');
      expect(result.sopranoVoice?.fullNoteNameInternational, 'E4');
    });
  });

  group('PolyphonicMultiToneDetector DSP Tests', () {
    final detector = PolyphonicMultiToneDetector();
    const sampleRate = 44100.0;

    List<double> generateTone(double freq, int numSamples, {double amplitude = 0.5}) {
      return List<double>.generate(numSamples, (i) {
        final t = i / sampleRate;
        return amplitude * math.sin(2.0 * math.pi * freq * t);
      });
    }

    test('detectFromSamples rejects silence below noise gate threshold', () {
      final silence = List<double>.filled(1024, 0.0);
      final result = detector.detectFromSamples(samples: silence);
      expect(result.isSilence, isTrue);
      expect(result.polyphonyCount, 0);
    });

    test('detectFromSamples accurately identifies single monophonic A4 note', () {
      // 440 Hz = A4 (MIDI 69)
      final samples = generateTone(440.0, 2048, amplitude: 0.6);
      final result = detector.detectFromSamples(samples: samples);

      expect(result.isSilence, isFalse);
      expect(result.polyphonyCount, greaterThanOrEqualTo(1));
      final voice = result.voices.firstWhere((v) => v.midiNumber == 69);
      expect(voice.noteNameInternational, 'A');
      expect(voice.octave, 4);
      expect(voice.frequencyHz, closeTo(440.0, 3.0));
    });

    test('detectFromSamples decomposes simultaneous C4-E4-G4 triad chord', () {
      // C4 = 261.63 Hz, E4 = 329.63 Hz, G4 = 392.00 Hz
      const numSamples = 2048;
      final samples = List<double>.filled(numSamples, 0.0);

      final cSamples = generateTone(261.63, numSamples, amplitude: 0.28);
      final eSamples = generateTone(329.63, numSamples, amplitude: 0.25);
      final gSamples = generateTone(392.00, numSamples, amplitude: 0.22);

      for (int i = 0; i < numSamples; i++) {
        samples[i] = cSamples[i] + eSamples[i] + gSamples[i];
      }

      final result = detector.detectFromSamples(samples: samples);

      expect(result.isSilence, isFalse);
      expect(result.polyphonyCount, greaterThanOrEqualTo(2));

      // Verificar que C4 (MIDI 60) y G4 (MIDI 67) están entre las voces detectadas
      final midiNumbers = result.voices.map((v) => v.midiNumber).toList();
      expect(midiNumbers.contains(60), isTrue, reason: 'Debe contener C4 (MIDI 60)');
      expect(midiNumbers.contains(67), isTrue, reason: 'Debe contener G4 (MIDI 67)');
    });
  });
}
