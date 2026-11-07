import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/instrument_customization_profile.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/presentation/instrument_customization_modal.dart';
import 'package:tunner/features/instrument/presentation/universal_master_keyboard_widget.dart';

void main() {
  group('Instrument Customization & Master Keyboard Widget Tests', () {
    testWidgets('renders InstrumentCustomizationModal with all tabs and sliders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      final guitar = UniversalInstrumentDefinition.classicalGuitar;
      final profile = InstrumentCustomizationProfile.defaultFor(guitar);
      InstrumentCustomizationProfile? updatedProfile;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentCustomizationModal(
              initialProfile: profile,
              onProfileUpdated: (p) => updatedProfile = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar pestañas
      expect(find.text('Timbre & ADSR'), findsOneWidget);
      expect(find.text('A4 & Temperamento'), findsOneWidget);
      expect(find.text('Desafinación Microtonal'), findsOneWidget);

      // Cambiar a pestaña 2 (A4 & Temperamento)
      await tester.tap(find.text('A4 & Temperamento'));
      await tester.pumpAndSettle();

      expect(find.textContaining('TONO DE REFERENCIA A4'), findsOneWidget);
      expect(find.text('442 Hz'), findsOneWidget);

      // Tocar chip de 442 Hz
      await tester.tap(find.text('442 Hz'));
      await tester.pumpAndSettle();

      expect(updatedProfile, isNotNull);
      expect(updatedProfile!.referencePitchA4, 442.0);

      // Cambiar a pestaña 3 (Desafinación Microtonal)
      await tester.tap(find.text('Desafinación Microtonal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('DESAFINACIÓN INDIVIDUAL POR CUERDA'), findsOneWidget);
      expect(find.text('Guitarra 12 Cuerdas (Chorus Shimmer)'), findsOneWidget);
    });

    testWidgets('renders UniversalMasterKeyboardWidget and plays notes and phrases', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));

      final piano = UniversalInstrumentDefinition.grandPiano;
      final profile = InstrumentCustomizationProfile.defaultFor(piano);
      double? playedFreq;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalMasterKeyboardWidget(
              customization: profile,
              onNotePlayed: (f) => playedFreq = f,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar cabecera
      expect(find.textContaining('TECLADO MAESTRO'), findsOneWidget);
      expect(find.textContaining('OCTAVA: C4 - B5'), findsOneWidget);

      // Tocar la tecla Do4
      final do4 = find.text('Do4');
      expect(do4, findsOneWidget);
      await tester.tap(do4);
      await tester.pumpAndSettle();

      expect(playedFreq, isNotNull);
      expect(playedFreq!, closeTo(261.63, 1.0)); // C4 ≈ 261.63 Hz

      // Botón Reproducir Estrofa
      final playPhraseBtn = find.text('REPRODUCIR ESTROFA');
      expect(playPhraseBtn, findsOneWidget);
      await tester.tap(playPhraseBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Debe cambiar a estado PARAR
      expect(find.text('PARAR'), findsOneWidget);

      // Detener reproducción
      await tester.tap(find.text('PARAR'));
      await tester.pumpAndSettle();
      expect(find.text('REPRODUCIR ESTROFA'), findsOneWidget);
    });
  });
}
