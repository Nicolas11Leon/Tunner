import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/mcleod_pitch_method.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';
import 'package:tunner/features/tuner/domain/note_entity.dart';

void main() {
  group('McleodPitchMethod MPM Hardening Tests', () {
    const mpm = McleodPitchMethod(minClarity: 0.60);

    Float64List generateSineWave({
      required double frequency,
      required int sampleRate,
      required int sampleCount,
    }) {
      final buffer = Float64List(sampleCount);
      for (int i = 0; i < sampleCount; i++) {
        buffer[i] = math.sin(2.0 * math.pi * frequency * i / sampleRate);
      }
      return buffer;
    }

    test('Accurately detects concert pitch A4 (440 Hz) with high clarity', () {
      final samples = generateSineWave(frequency: 440.0, sampleRate: 44100, sampleCount: 2048);
      final result = mpm.estimatePitch(samples, sampleRate: 44100);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(440.0, 0.5));
      expect(result.clarity, greaterThan(0.90));
    });

    test('Accurately detects contrabass lowest note A0 (27.5 Hz) with 4096-sample buffer', () {
      final samples = generateSineWave(frequency: 27.5, sampleRate: 44100, sampleCount: 4096);
      final result = mpm.estimatePitch(samples, sampleRate: 44100);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(27.5, 0.5));
      expect(result.clarity, greaterThan(0.85));
    });

    test('Accurately detects high piccolo note C8 (4186 Hz)', () {
      final samples = generateSineWave(frequency: 4186.0, sampleRate: 44100, sampleCount: 2048);
      final result = mpm.estimatePitch(samples, sampleRate: 44100);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(4186.0, 15.0));
      expect(result.clarity, greaterThan(0.80));
    });

    test('Dynamic sample rate: operates accurately at 48000 Hz hardware audio rate', () {
      final samples = generateSineWave(frequency: 440.0, sampleRate: 48000, sampleCount: 2048);
      final result = mpm.estimatePitch(samples, sampleRate: 48000);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(440.0, 0.5));
    });

    test('Zero crossing check eliminates main-lobe false positives and octave jump', () {
      // Onda con armónico fuerte que podría inducir salto de octava
      final buffer = Float64List(4096);
      for (int i = 0; i < 4096; i++) {
        // Fundamental 110 Hz (A2) + segundo armónico 220 Hz
        buffer[i] = 0.7 * math.sin(2.0 * math.pi * 110.0 * i / 44100) +
            0.5 * math.sin(2.0 * math.pi * 220.0 * i / 44100);
      }
      final result = mpm.estimatePitch(buffer, sampleRate: 44100);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(110.0, 1.0));
    });
  });

  group('TemperamentEngine Anchor A4 & Historical Getters Hardening', () {
    const engine = TemperamentEngine();

    test('Canonical getters for Werckmeister III, Vallotti, and Young II return valid entities', () {
      final werck3 = TemperamentEngine.werckmeisterIII;
      final vallotti = TemperamentEngine.vallotti;
      final young2 = TemperamentEngine.youngII;

      expect(werck3.id, equals('werckmeister_iii'));
      expect(vallotti.id, equals('vallotti'));
      expect(young2.id, equals('young_ii'));
    });

    test('anchorA4 = true anchors A4 (MIDI 69) to exactly 440.0 Hz in Just Intonation', () {
      final just = TemperamentEngine.justIntonation;

      // Sin anclaje, en Just Intonation basada en C, A4 está desviado -15.64 cents
      final freqDefault = engine.getTargetFrequency(
        midiNumber: 69,
        temperament: just,
        a4Ref: 440.0,
        rootKey: 0,
        anchorA4: false,
      );
      expect(freqDefault, closeTo(436.04, 0.05));

      // Con anchorA4 = true, A4 es exactamente 440.0 Hz para calibración con oboe/diapasón
      final freqAnchored = engine.getTargetFrequency(
        midiNumber: 69,
        temperament: just,
        a4Ref: 440.0,
        rootKey: 0,
        anchorA4: true,
      );
      expect(freqAnchored, closeTo(440.0, 0.001));
    });

    test('anchorA4 = true preserves internal intervals while locking A4 reference', () {
      final just = TemperamentEngine.justIntonation;

      final c4 = engine.getTargetFrequency(midiNumber: 60, temperament: just, anchorA4: true);
      final e4 = engine.getTargetFrequency(midiNumber: 64, temperament: just, anchorA4: true);

      // El intervalo de tercera mayor pura 5:4 (1.25) se mantiene idéntico
      expect(e4 / c4, closeTo(1.25, 0.001));
    });
  });

  group('NoteEntity Enhancements: English Names, Flats, and Roundtrips', () {
    test('frequencyForNote parses English note names and sharps', () {
      expect(NoteEntity.frequencyForNote('A4'), closeTo(440.0, 0.01));
      expect(NoteEntity.frequencyForNote('C4'), closeTo(261.63, 0.01));
      expect(NoteEntity.frequencyForNote('F#3'), closeTo(185.00, 0.01));
    });

    test('frequencyForNote parses flats (b) in English and Solfege', () {
      expect(NoteEntity.frequencyForNote('Bb3'), closeTo(233.08, 0.01));
      expect(NoteEntity.frequencyForNote('Eb4'), closeTo(311.13, 0.01));
      expect(NoteEntity.frequencyForNote('Sib3'), closeTo(233.08, 0.01));
      expect(NoteEntity.frequencyForNote('Mib4'), closeTo(311.13, 0.01));
    });

    test('toEnglishName and toSolfegeName convert representations accurately', () {
      final noteA = NoteEntity(name: 'La4', frequency: 440.0, cents: 0.0, midiNumber: 69);
      expect(noteA.toEnglishName(), equals('A4'));
      expect(noteA.toSolfegeName(), equals('La4'));

      final noteBb = NoteEntity(name: 'Bb3', frequency: 233.08, cents: 0.0, midiNumber: 58);
      expect(noteBb.toEnglishName(), equals('Bb3'));
      expect(noteBb.toSolfegeName(), equals('Sib3'));
    });
  });
}
