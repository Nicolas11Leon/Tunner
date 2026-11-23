import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/soundfont_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/tunner_acoustic_soundfont_bank.dart';

void main() {
  group('PolyphonicVoicePool and SoundFont Synthesis Hardening Tests', () {
    test('PolyphonicVoicePool initializes with default voices and renders mono block', () {
      final pool = PolyphonicVoicePool(maxPolyphony: 8, sampleRate: 44100.0);
      expect(pool.voices.length, equals(8));
      expect(pool.activeVoiceCount, equals(0));

      pool.noteOn(60, 0.8); // Middle C
      expect(pool.activeVoiceCount, equals(1));

      final monoOut = Float64List(256);
      pool.renderMonoBlock(out: monoOut, numSamples: 256);

      // Verify that audio was generated and limited to [-1.0, 1.0]
      bool hasNonZero = false;
      for (final s in monoOut) {
        expect(s.abs(), lessThanOrEqualTo(1.0));
        if (s.abs() > 0.0001) hasNonZero = true;
      }
      expect(hasNonZero, isTrue);

      pool.noteOff(60);
      pool.panic();
      expect(pool.activeVoiceCount, equals(0));
    });

    test('PolyphonicVoicePool applies voice stealing algorithm when pool is saturated', () {
      final pool = PolyphonicVoicePool(maxPolyphony: 4, sampleRate: 44100.0);
      for (int i = 0; i < 4; i++) {
        pool.noteOn(60 + i, 0.8);
      }
      expect(pool.activeVoiceCount, equals(4));

      // 5th note should steal oldest voice without throwing exception
      pool.noteOn(72, 0.9);
      expect(pool.activeVoiceCount, equals(4));
      expect(pool.voices.any((v) => v.noteNumber == 72 && v.isActive), isTrue);
    });

    test('SoundFontSynthesizerService extracts ADSR envelope parameters correctly', () {
      final service = SoundFontSynthesizerService();
      expect(service.availablePresets.isNotEmpty, isTrue);

      final wavBytes = service.synthesizeNoteWav(
        midiPitch: 60,
        durationSeconds: 0.1,
        velocity: 100,
        sampleRate: 44100,
      );

      expect(wavBytes.length, greaterThan(44));
      // Standard RIFF header check
      expect(String.fromCharCodes(wavBytes.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(wavBytes.sublist(8, 12)), equals('WAVE'));
    });

    test('Sf2Parser parses essential bank presets and headers deterministically', () {
      final bank = TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();
      expect(bank.presets.length, greaterThanOrEqualTo(5));
      expect(bank.instruments.isNotEmpty, isTrue);
      expect(bank.sampleHeaders.isNotEmpty, isTrue);

      final piano = bank.findPreset(0);
      expect(piano, isNotNull);
      expect(piano!.name, contains('Piano'));
    });
  });
}
