import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_taxonomy.dart';
import 'package:tunner/features/instrument/domain/visual_interface_profile.dart';

void main() {
  group('Ethnic & Traditional Instruments Hornbostel-Sachs Catalog Tests', () {
    test('all 5 ethnic instruments are present in masterCatalog with valid HS taxonomy', () {
      final catalog = UniversalInstrumentDefinition.masterCatalog;

      final expectedIds = [
        'chordophone.plucked_strings.kora_west_african',
        'chordophone.plucked_strings.sitar_indian',
        'aerophone.woodwind.shakuhachi_japan',
        'chordophone.plucked_strings.charango_andean',
        'chordophone.plucked_strings.cuatro_venezuelan',
      ];

      for (final id in expectedIds) {
        final inst = UniversalInstrumentDefinition.findById(id);
        expect(inst, isNotNull, reason: 'Instrument $id must exist in catalog');
        expect(catalog.contains(inst), isTrue);

        // Validar jerarquía taxonómica Hornbostel-Sachs
        final parts = inst!.universalId.split('.');
        expect(parts.length, 3);
        expect(parts[0], inst.category.code);
        expect(parts[1], inst.subfamily.code);
      }
    });

    test('Kora de África Occidental has 20+ canonical tuning pitches covering F2 to G5', () {
      final kora = UniversalInstrumentDefinition.koraWestAfrican;
      expect(kora.category, HornbostelSachsCategory.chordophone);
      expect(kora.subfamily, InstrumentSubfamily.pluckedStrings);

      // Rango de tesitura
      expect(kora.acousticRange.minFrequencyHz, closeTo(87.31, 0.01)); // F2
      expect(kora.acousticRange.maxFrequencyHz, closeTo(783.99, 0.01)); // G5
      expect(kora.acousticRange.minMidiNote, 41);
      expect(kora.acousticRange.maxMidiNote, 79);

      // Afinación Tomora Ba / Sawuta
      expect(kora.acousticRange.standardTuningFrequencies.length, 20);
      expect(kora.acousticRange.standardTuningNoteNames.first, 'F2');
      expect(kora.acousticRange.standardTuningNoteNames.last, 'G5');
    });

    test('Sitar Clásico de la India has baaj & chikari strings and General MIDI 104', () {
      final sitar = UniversalInstrumentDefinition.sitarIndian;
      expect(sitar.category, HornbostelSachsCategory.chordophone);
      expect(sitar.subfamily, InstrumentSubfamily.pluckedStrings);
      expect(sitar.generalMidiNumber, 104);

      expect(sitar.acousticRange.minFrequencyHz, closeTo(65.41, 0.01)); // C2
      expect(sitar.acousticRange.maxFrequencyHz, closeTo(1046.50, 0.01)); // C6
      expect(sitar.acousticRange.standardTuningNoteNames, containsAll(['C2', 'G2', 'C3', 'F3', 'G3', 'C4', 'C5']));
    });

    test('Shakuhachi Tradicional Japonés has pentatonic tuning D4-C5 and General MIDI 77', () {
      final shakuhachi = UniversalInstrumentDefinition.shakuhachiJapanese;
      expect(shakuhachi.category, HornbostelSachsCategory.aerophone);
      expect(shakuhachi.subfamily, InstrumentSubfamily.woodwind);
      expect(shakuhachi.generalMidiNumber, 77);

      expect(shakuhachi.isTransposing, isTrue);
      expect(shakuhachi.transpositionSemitones, 2); // D

      expect(shakuhachi.acousticRange.standardTuningNoteNames, ['D4', 'F4', 'G4', 'A4', 'C5']);
      expect(shakuhachi.acousticRange.minFrequencyHz, closeTo(293.66, 0.01)); // D4
      expect(shakuhachi.acousticRange.maxFrequencyHz, closeTo(2349.32, 0.01)); // D7
      expect(shakuhachi.visualProfile.rendererType, VisualRendererType.valvesPads);
    });

    test('Charango Andino has reentrant 5 double courses tuning with center octave', () {
      final charango = UniversalInstrumentDefinition.charangoAndean;
      expect(charango.category, HornbostelSachsCategory.chordophone);
      expect(charango.subfamily, InstrumentSubfamily.pluckedStrings);

      // Temple natural: E5, A4, E4/E5, C5, G4
      expect(charango.acousticRange.standardTuningNoteNames, ['E5', 'A4', 'E4', 'C5', 'G4']);
      expect(charango.acousticRange.standardTuningFrequencies[0], closeTo(659.25, 0.01)); // E5
      expect(charango.acousticRange.standardTuningFrequencies[1], closeTo(440.00, 0.01)); // A4
      expect(charango.acousticRange.standardTuningFrequencies[2], closeTo(329.63, 0.01)); // E4
      expect(charango.acousticRange.standardTuningFrequencies[3], closeTo(523.25, 0.01)); // C5
      expect(charango.acousticRange.standardTuningFrequencies[4], closeTo(392.00, 0.01)); // G4
    });

    test('Cuatro Tradicional Venezolano implements Cambur Pintón reentrant tuning B3-F#4-D4-A3', () {
      final cuatro = UniversalInstrumentDefinition.cuatroVenezuelan;
      expect(cuatro.category, HornbostelSachsCategory.chordophone);
      expect(cuatro.subfamily, InstrumentSubfamily.pluckedStrings);

      expect(cuatro.acousticRange.standardTuningNoteNames, ['B3', 'F#4', 'D4', 'A3']);
      expect(cuatro.acousticRange.standardTuningFrequencies[0], closeTo(246.94, 0.01)); // B3
      expect(cuatro.acousticRange.standardTuningFrequencies[1], closeTo(369.99, 0.01)); // F#4
      expect(cuatro.acousticRange.standardTuningFrequencies[2], closeTo(293.66, 0.01)); // D4
      expect(cuatro.acousticRange.standardTuningFrequencies[3], closeTo(220.00, 0.01)); // A3
    });

    test('search finds ethnic instruments by localized and vernacular terms', () {
      // Búsqueda por término vernáculo africano
      final koraResults = UniversalInstrumentDefinition.search('ngoni');
      expect(koraResults.any((i) => i.universalId.contains('kora')), isTrue);

      // Búsqueda por raga / sitar
      final sitarResults = UniversalInstrumentDefinition.search('raga');
      expect(sitarResults.any((i) => i.universalId.contains('sitar')), isTrue);

      // Búsqueda por bambú / flauta zen
      final shakuResults = UniversalInstrumentDefinition.search('flauta zen');
      expect(shakuResults.any((i) => i.universalId.contains('shakuhachi')), isTrue);

      // Búsqueda por folclore andino
      final charangoResults = UniversalInstrumentDefinition.search('temple natural');
      expect(charangoResults.any((i) => i.universalId.contains('charango')), isTrue);

      // Búsqueda por frase venezolana
      final cuatroResults = UniversalInstrumentDefinition.search('cambur pinton');
      expect(cuatroResults.any((i) => i.universalId.contains('cuatro_venezuelan')), isTrue);
    });
  });
}
