import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/guided_lessons/domain/curated_guided_lessons.dart';
import 'package:tunner/features/guided_lessons/domain/instrument_pedagogy_adapter_engine.dart';
import 'package:tunner/features/song_library/data/song_decomposer_service.dart';

void main() {
  group('InstrumentPedagogyAdapterEngine Unit Tests', () {
    const adapter = InstrumentPedagogyAdapterEngine();

    test('noteNameToMidi converts standard solfege and scientific pitches accurately', () {
      expect(adapter.noteNameToMidi('La4'), equals(69));
      expect(adapter.noteNameToMidi('A4'), equals(69));
      expect(adapter.noteNameToMidi('Do4'), equals(60));
      expect(adapter.noteNameToMidi('C4'), equals(60));
      expect(adapter.noteNameToMidi('Sol4'), equals(67));
      expect(adapter.noteNameToMidi('G4'), equals(67));
      expect(adapter.noteNameToMidi('Do#5'), equals(73));
      expect(adapter.noteNameToMidi('Mib4'), equals(63));
    });

    test('midiToFrequency calculates A4=440 Hz and C4=261.63 Hz within sub-cent margin', () {
      expect(adapter.midiToFrequency(69), closeTo(440.0, 0.001));
      expect(adapter.midiToFrequency(60), closeTo(261.625, 0.01));
      expect(adapter.midiToFrequency(57), closeTo(220.0, 0.001));
    });

    test('shiftMidiToInstrumentRange transposes notes to comfortable range of Guitar', () {
      final guitar = InstrumentProfileEntity.guitar;
      // Nota original Sol5 (MIDI 79) es muy aguda para principiante de guitarra; se desplaza al registro medio
      final shifted = adapter.shiftMidiToInstrumentRange(79, guitar);
      final freq = adapter.midiToFrequency(shifted);

      expect(freq >= guitar.minFrequencyHz, isTrue);
      expect(freq <= guitar.maxFrequencyHz, isTrue);
      expect((79 - shifted) % 12, equals(0)); // Salto exacto de octavas
    });

    test('shiftMidiToInstrumentRange transposes high flute notes down to Bass range', () {
      final doubleBass = InstrumentProfileEntity.doubleBass;
      // Nota original Mi5 (MIDI 76) no existe en contrabajo acústico; debe descender
      final shifted = adapter.shiftMidiToInstrumentRange(76, doubleBass);
      final freq = adapter.midiToFrequency(shifted);

      expect(freq >= doubleBass.minFrequencyHz, isTrue);
      expect(freq <= doubleBass.maxFrequencyHz, isTrue);
      expect((76 - shifted) % 12, equals(0));
    });

    test('shiftMidiToInstrumentRange transposes low notes up to Piccolo range', () {
      final piccolo = InstrumentProfileEntity.piccolo;
      // Nota Do4 (MIDI 60) no existe físicamente en flautín (min es Do5 / 523 Hz)
      final shifted = adapter.shiftMidiToInstrumentRange(60, piccolo);
      final freq = adapter.midiToFrequency(shifted);

      expect(freq >= piccolo.minFrequencyHz, isTrue);
      expect((shifted - 60) % 12, equals(0));
    });

    test('calculates correct written note for transposing Bb Trumpet', () {
      final trumpet = InstrumentProfileEntity.bbTrumpet;
      final step = CuratedGuidedLessons.all.first.steps.first; // Sol4 (Concierto)
      final adapted = adapter.adaptStep(step, trumpet);

      // En trompeta Bb (-2 semitonos de transposición), para sonar Sol4 debe leer La4
      expect(adapted.writtenNoteName, equals('La4'));
      expect(adapted.targetNoteName, equals('Sol4'));
      expect(adapted.instruction, contains('Toca la nota escrita La4'));
    });

    test('calculates correct written note for transposing Eb Alto Sax', () {
      final sax = InstrumentProfileEntity.ebAltoSax; // -9 semitonos
      final step = CuratedGuidedLessons.all[1].steps.first; // Do4 (Concierto)
      final adapted = adapter.adaptStep(step, sax);

      // Para sonar Do4, debe leer La4 (60 - (-9) = 69 = La4)
      expect(adapted.writtenNoteName, equals('La4'));
    });

    test('generates family-specific biomechanical feedback tips', () {
      // 1. Guitarra
      final guitarTip = adapter.generateFamilyBiomechanicsTip(
        instrument: InstrumentProfileEntity.guitar,
        stepIndex: 0,
        isHighRegister: false,
        isLowRegister: false,
      );
      expect(guitarTip, contains('traste'));

      // 2. Violín
      final violinTip = adapter.generateFamilyBiomechanicsTip(
        instrument: InstrumentProfileEntity.violin,
        stepIndex: 0,
        isHighRegister: false,
        isLowRegister: false,
      );
      expect(violinTip, contains('arco'));

      // 3. Trompeta
      final brassTip = adapter.generateFamilyBiomechanicsTip(
        instrument: InstrumentProfileEntity.bbTrumpet,
        stepIndex: 0,
        isHighRegister: false,
        isLowRegister: false,
      );
      expect(brassTip.contains('vibración labial') || brassTip.contains('ataque'), isTrue);

      // 4. Canto / Voz
      final vocalTip = adapter.generateFamilyBiomechanicsTip(
        instrument: InstrumentProfileEntity.voice,
        stepIndex: 0,
        isHighRegister: false,
        isLowRegister: false,
      );
      expect(vocalTip.contains('resonancia') || vocalTip.contains('costal'), isTrue);
    });

    test('SongDecomposerService adapts song package and tracks to active instrument', () {
      final original = SongDecomposerService.getCuratedLibrary()[1]; // Para Elisa
      final adapted = SongDecomposerService.adaptSongPackageToInstrument(
        original,
        InstrumentProfileEntity.guitar,
      );

      expect(adapted.tracks.any((t) => t.title.contains('Guitarra')), isTrue);
      expect(adapted.score.measures.isNotEmpty, isTrue);
    });
  });
}
