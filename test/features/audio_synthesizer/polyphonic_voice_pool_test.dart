import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/adsr_envelope_generator.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';

void main() {
  group('AdsrEnvelopeGenerator Tests', () {
    test('initial state is idle with zero amplitude', () {
      final adsr = AdsrEnvelopeGenerator(sampleRate: 1000.0);
      expect(adsr.stage, AdsrStage.idle);
      expect(adsr.currentAmplitude, 0.0);
      expect(adsr.isIdle, isTrue);
      expect(adsr.isActive, isFalse);
    });

    test('progresses through attack, decay, sustain, and release stages', () {
      final adsr = AdsrEnvelopeGenerator(
        attackSeconds: 0.01,  // 10 samples at 1000 Hz
        decaySeconds: 0.01,   // 10 samples
        sustainLevel: 0.5,
        releaseSeconds: 0.01, // 10 samples
        sampleRate: 1000.0,
      );

      adsr.noteOn();
      expect(adsr.stage, AdsrStage.attack);

      // Process attack
      for (int i = 0; i < 10; i++) {
        adsr.processSample();
      }
      expect(adsr.stage, AdsrStage.decay);

      // Process decay
      for (int i = 0; i < 10; i++) {
        adsr.processSample();
      }
      expect(adsr.stage, AdsrStage.sustain);
      expect(adsr.currentAmplitude, closeTo(0.5, 0.01));

      // Note off initiates release
      adsr.noteOff();
      expect(adsr.stage, AdsrStage.release);

      // Process release
      for (int i = 0; i < 11; i++) {
        adsr.processSample();
      }
      expect(adsr.stage, AdsrStage.idle);
      expect(adsr.currentAmplitude, 0.0);
    });

    test('reset forces generator immediately to idle', () {
      final adsr = AdsrEnvelopeGenerator();
      adsr.noteOn();
      adsr.processSample();
      expect(adsr.isActive, isTrue);

      adsr.reset();
      expect(adsr.stage, AdsrStage.idle);
      expect(adsr.currentAmplitude, 0.0);
    });
  });

  group('PolyphonicSynthVoice Tests', () {
    test('renders within [-1.0, 1.0] across all waveforms', () {
      for (final wf in SynthWaveform.values) {
        final voice = PolyphonicSynthVoice(id: 0, sampleRate: 1000.0);
        voice.startNote(
          noteNumber: 69,
          frequency: 440.0,
          velocity: 1.0,
          waveform: wf,
        );

        for (int i = 0; i < 50; i++) {
          final sample = voice.renderNextSample(1000.0);
          expect(sample.abs(), lessThanOrEqualTo(1.0), reason: 'Waveform $wf exceeded 1.0');
          expect(sample.isNaN, isFalse);
        }
      }
    });

    test('kill cancels voice immediately', () {
      final voice = PolyphonicSynthVoice(id: 0);
      voice.startNote(noteNumber: 60, frequency: 261.63, velocity: 0.8);
      expect(voice.isActive, isTrue);

      voice.kill();
      expect(voice.isActive, isFalse);
      expect(voice.noteNumber, -1);
    });
  });

  group('PolyphonicVoicePool Tests', () {
    test('midiToFrequency calculates accurate standard pitch', () {
      // A4 = MIDI 69 -> 440 Hz
      expect(PolyphonicVoicePool.midiToFrequency(69), closeTo(440.0, 0.001));
      // A5 = MIDI 81 -> 880 Hz
      expect(PolyphonicVoicePool.midiToFrequency(81), closeTo(880.0, 0.001));
      // C4 = MIDI 60 -> ~261.625 Hz
      expect(PolyphonicVoicePool.midiToFrequency(60), closeTo(261.625, 0.01));
    });

    test('allocates independent voices for chords and handles release', () {
      final pool = PolyphonicVoicePool(maxPolyphony: 8);
      expect(pool.activeVoiceCount, 0);

      // Play C Major Chord: C4 (60), E4 (64), G4 (67)
      pool.noteOn(60, 0.8);
      pool.noteOn(64, 0.8);
      pool.noteOn(67, 0.8);

      expect(pool.activeVoiceCount, 3);

      // Release E4
      pool.noteOff(64);
      // Voice is still active in release stage
      expect(pool.activeVoiceCount, 3);

      // All notes off
      pool.allNotesOff();
      // Panic terminates all instantly
      pool.panic();
      expect(pool.activeVoiceCount, 0);
    });

    test('applies voice stealing gracefully when polyphony limit is reached', () {
      final pool = PolyphonicVoicePool(maxPolyphony: 4);

      // Trigger 4 notes
      pool.noteOn(60, 0.8);
      pool.noteOn(62, 0.8);
      pool.noteOn(64, 0.8);
      pool.noteOn(65, 0.8);
      expect(pool.activeVoiceCount, 4);

      // Put note 60 into release
      pool.noteOff(60);

      // Trigger 5th note, stealing the voice in release
      pool.noteOn(67, 0.8);
      expect(pool.activeVoiceCount, 4);
    });

    test('renderBlock generates smooth limited stereo audio without clipping or NaN', () {
      final pool = PolyphonicVoicePool(maxPolyphony: 8);
      pool.noteOn(60, 1.0);
      pool.noteOn(64, 1.0);
      pool.noteOn(67, 1.0);
      pool.noteOn(71, 1.0); // 4-note chord

      final left = Float64List(256);
      final right = Float64List(256);

      pool.renderBlock(leftOut: left, rightOut: right, numSamples: 256);

      for (int i = 0; i < 256; i++) {
        expect(left[i].isNaN, isFalse);
        expect(right[i].isNaN, isFalse);
        expect(left[i].abs(), lessThan(1.0));
        expect(right[i].abs(), lessThan(1.0));
      }
    });
  });
}
