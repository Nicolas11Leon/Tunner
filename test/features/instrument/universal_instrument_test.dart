import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_taxonomy.dart';
import 'package:tunner/features/instrument/domain/visual_interface_profile.dart';

void main() {
  group('Universal Instrument Catalog & Taxonomy Tests', () {
    test('master catalog contains all major acoustic & modern instrument families', () {
      final catalog = UniversalInstrumentDefinition.masterCatalog;
      expect(catalog.isNotEmpty, isTrue);

      // Debe contener al menos 20 instrumentos canónicos
      expect(catalog.length, greaterThanOrEqualTo(20));

      // Verificar que contenga instrumentos de todas las categorías Hornbostel-Sachs
      final categories = catalog.map((i) => i.category).toSet();
      expect(categories.contains(HornbostelSachsCategory.aerophone), isTrue);
      expect(categories.contains(HornbostelSachsCategory.chordophone), isTrue);
      expect(categories.contains(HornbostelSachsCategory.idiophone), isTrue);
      expect(categories.contains(HornbostelSachsCategory.membranophone), isTrue);
      expect(categories.contains(HornbostelSachsCategory.vocal), isTrue);
      expect(categories.contains(HornbostelSachsCategory.electrophone), isTrue);
    });

    test('hierarchical universal IDs follow the formal structure [HS.subfamily.code]', () {
      for (final inst in UniversalInstrumentDefinition.masterCatalog) {
        final parts = inst.universalId.split('.');
        expect(parts.length, greaterThanOrEqualTo(3),
            reason: 'El ID ${inst.universalId} debe tener al menos 3 partes separadas por punto');

        // La primera parte debe coincidir con el código de la categoría Hornbostel-Sachs
        expect(parts[0], inst.category.code);
        // La segunda parte debe coincidir con el código de la subfamilia
        expect(parts[1], inst.subfamily.code);
      }
    });

    test('search query finds instruments by name, keyword or universal ID', () {
      // Búsqueda por instrumento de percusión
      final drumResults = UniversalInstrumentDefinition.search('bateria');
      expect(drumResults.any((i) => i.universalId.contains('standard_kit')), isTrue);

      // Búsqueda por instrumento de viento
      final fluteResults = UniversalInstrumentDefinition.search('flauta');
      expect(fluteResults.any((i) => i.universalId.contains('flute_concert_c')), isTrue);

      // Búsqueda por instrumento de cuerda frotada
      final violinResults = UniversalInstrumentDefinition.search('violin');
      expect(violinResults.any((i) => i.universalId.contains('violin_acoustic')), isTrue);

      // Búsqueda por prefijo taxonómico
      final plucked = UniversalInstrumentDefinition.search('chordophone.plucked_strings');
      expect(plucked.length, greaterThanOrEqualTo(3));
    });

    test('acoustic range validates boundaries and tuning notes properly', () {
      final guitar = UniversalInstrumentDefinition.classicalGuitar;
      expect(guitar.acousticRange.containsFrequency(82.41), isTrue); // E2
      expect(guitar.acousticRange.containsFrequency(10.0), isFalse); // Fuera de rango
      expect(guitar.acousticRange.standardTuningFrequencies.length, 6);
      expect(guitar.acousticRange.standardTuningNoteNames.first, 'E2');
      expect(guitar.acousticRange.standardTuningNoteNames.last, 'E4');
    });

    test('visual interface profiles assign appropriate renderers per instrument', () {
      final guitar = UniversalInstrumentDefinition.classicalGuitar;
      expect(guitar.visualProfile.rendererType, VisualRendererType.fretboard);

      final violin = UniversalInstrumentDefinition.violin;
      expect(violin.visualProfile.rendererType, VisualRendererType.fingerboard);

      final piano = UniversalInstrumentDefinition.grandPiano;
      expect(piano.visualProfile.rendererType, VisualRendererType.keybed);

      final drums = UniversalInstrumentDefinition.acousticDrumKit;
      expect(drums.visualProfile.rendererType, VisualRendererType.drumPads);

      final marimba = UniversalInstrumentDefinition.concertMarimba;
      expect(marimba.visualProfile.rendererType, VisualRendererType.malletBars);

      final trumpet = UniversalInstrumentDefinition.trumpetBb;
      expect(trumpet.visualProfile.rendererType, VisualRendererType.valvesPads);

      final voice = UniversalInstrumentDefinition.voiceSoprano;
      expect(voice.visualProfile.rendererType, VisualRendererType.vocalFormants);
    });

    test('timbral ADSR envelopes are acoustically coherent', () {
      for (final inst in UniversalInstrumentDefinition.masterCatalog) {
        final adsr = inst.timbralProfile.adsr;
        expect(adsr.attackMs, greaterThanOrEqualTo(0.0));
        expect(adsr.decayMs, greaterThanOrEqualTo(0.0));
        expect(adsr.sustainLevel, inInclusiveRange(0.0, 1.0));
        expect(adsr.releaseMs, greaterThanOrEqualTo(0.0));
        expect(inst.timbralProfile.harmonicOvertoneAmplitudes.length, 8);
      }
    });
  });
}
