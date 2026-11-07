import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/per_note_detuning_profile.dart';
import 'package:tunner/features/instrument/domain/instrument_customization_profile.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/domain/musical_phrase_entity.dart';
import 'package:tunner/features/instrument/data/procedural_instrument_synthesizer.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';

void main() {
  group('PerNoteDetuningProfile & Microtonal Acoustic Tests', () {
    test('calculateDetunedFrequency applies exponential cents formula accurately', () {
      const profile = PerNoteDetuningProfile.standard;
      // 0 cents offset
      expect(profile.calculateDetunedFrequency(440.0), 440.0);

      // +1200 cents (exactamente una octava arriba = 880 Hz)
      final octaveUp = profile.withNoteOffset(69, 1200.0);
      expect(octaveUp.calculateDetunedFrequency(440.0, midiNote: 69), closeTo(880.0, 0.001));

      // -1200 cents (exactamente una octava abajo = 220 Hz)
      final octaveDown = profile.withNoteOffset(69, -1200.0);
      expect(octaveDown.calculateDetunedFrequency(440.0, midiNote: 69), closeTo(220.0, 0.001));

      // +100 cents (un semitono arriba: 440 * 2^(1/12) ≈ 466.1637 Hz)
      final semitoneUp = profile.withNoteOffset(69, 100.0);
      expect(semitoneUp.calculateDetunedFrequency(440.0, midiNote: 69), closeTo(466.164, 0.001));
    });

    test('per-string detuning alters individual strings independently', () {
      var profile = PerNoteDetuningProfile.standard;
      // Desafinar 1ª cuerda Mi (+15 cents) y 2ª cuerda Si (-10 cents)
      profile = profile.withStringOffset(0, 15.0).withStringOffset(1, -10.0);

      expect(profile.getCentsOffsetForString(0), 15.0);
      expect(profile.getCentsOffsetForString(1), -10.0);
      expect(profile.getCentsOffsetForString(2), 0.0); // Cuerda 3 intacta

      final freqCuerda1 = profile.calculateDetunedFrequency(329.63, stringIndex: 0);
      expect(freqCuerda1, greaterThan(329.63));

      final freqCuerda2 = profile.calculateDetunedFrequency(246.94, stringIndex: 1);
      expect(freqCuerda2, lessThan(246.94));
    });

    test('canonical detuning presets have valid acoustical configurations', () {
      final honky = PerNoteDetuningProfile.honkyTonk;
      expect(honky.getCentsOffsetForNote(60), closeTo(7.5, 0.001));
      expect(honky.getCentsOffsetForNote(61), closeTo(-8.0, 0.001));

      final maqam = PerNoteDetuningProfile.quarterToneMaqam;
      // E4 (MIDI 64) y B4 (MIDI 71) deben tener -50 cents
      expect(maqam.getCentsOffsetForNote(64), -50.0);
      expect(maqam.getCentsOffsetForNote(71), -50.0);
      expect(maqam.getCentsOffsetForNote(60), 0.0); // C4 intacto

      final stretch = PerNoteDetuningProfile.railsbackStretch;
      expect(stretch.getCentsOffsetForNote(21), lessThan(0.0)); // A0 en graves estirado hacia abajo
      expect(stretch.getCentsOffsetForNote(108), greaterThan(0.0)); // C8 en agudos estirado hacia arriba
    });

    test('InstrumentCustomizationProfile integrates A4, temperament and micro-offsets', () {
      final guitar = UniversalInstrumentDefinition.classicalGuitar;
      final custom = InstrumentCustomizationProfile(
        instrument: guitar,
        referencePitchA4: 442.0, // Afinación sinfónica europea
        temperament: TemperamentEngine.allTemperaments.firstWhere((t) => t.id == 'pythagorean'),
        detuningProfile: PerNoteDetuningProfile.standard.withStringOffset(0, 5.0),
      );

      // Calcular frecuencia para la 1ª cuerda con A4 = 442 Hz y offset de 5 cents (suena E3 ≈ 166.8 Hz por transposición de -12 semitones)
      final freq = custom.calculateFrequencyForMidiNote(64, stringIndex: 0);
      expect(freq, greaterThan(160.0));
      expect(custom.referencePitchA4, 442.0);
    });

    test('ProceduralInstrumentSynthesizer synthesizes a complete musical phrase (stanza)', () {
      final piano = UniversalInstrumentDefinition.grandPiano;
      final custom = InstrumentCustomizationProfile.defaultFor(piano);
      final phrase = MusicalPhraseEntity.majorConcertArpeggio;

      final phraseBuffer = ProceduralInstrumentSynthesizer.synthesizePhrase(
        customization: custom,
        phrase: phrase,
        bpmOverride: 120,
      );

      expect(phraseBuffer.isNotEmpty, isTrue);
      // Duración calculada: 36 ticks * (60 / 480) = 4.5 segundos -> ~198450 muestras a 44.1kHz
      expect(phraseBuffer.length, greaterThan(100000));

      // Verificar que las muestras estén acotadas en [-1.0, 1.0]
      for (final sample in phraseBuffer) {
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }
    });
  });
}
