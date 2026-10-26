import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/customization/presentation/theme_customization_modal.dart';
import 'package:tunner/features/customization/presentation/theme_editor_dialog.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';

class FakePitchService implements IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;

  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;

  setUp(() {
    viewModel = TunerViewModel(
      pitchService: FakePitchService(),
      metronomeService: FakeMetroService(),
    );
  });

  testWidgets('ThemeCustomizationModal renders presets and allows palette selection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeCustomizationModal(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("PERSONALIZACIÓN DE ESTUDIO"), findsOneWidget);
    expect(find.text("Crear Tema"), findsOneWidget);
    expect(find.text("Obsidian Studio"), findsOneWidget);

    // Scroll hasta encontrar Nordic Frost si no está en viewport inmediato
    final targetFinder = find.text("Nordic Frost (Light)");
    await tester.scrollUntilVisible(
      targetFinder,
      120.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(targetFinder, findsOneWidget);

    // Seleccionar Nordic Frost
    await tester.tap(targetFinder);
    await tester.pumpAndSettle();

    expect(viewModel.currentPalette.id, 'nordic_frost');
    expect(viewModel.currentPalette.brightness, Brightness.light);
  });

  testWidgets('ThemeEditorDialog allows customizing name, base, accents and saves custom palette', (tester) async {
    TunnerThemePalette? savedPalette;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                ThemeEditorDialog.show(
                  context: ctx,
                  onSave: (p) => savedPalette = p,
                );
              },
              child: const Text("Abrir Editor"),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Abrir Editor"));
    await tester.pumpAndSettle();

    expect(find.text("CREAR ESTÉTICA"), findsOneWidget);
    expect(find.text("Nombre del Tema"), findsOneWidget);
    expect(find.text("Previsualización en Vivo"), findsOneWidget);

    // Escribir un nuevo nombre
    await tester.enterText(find.byType(TextField), "Mi Conservatorio Mágico");
    await tester.pumpAndSettle();

    // Guardar
    await tester.tap(find.text("Guardar y Aplicar"));
    await tester.pumpAndSettle();

    expect(savedPalette, isNotNull);
    expect(savedPalette!.displayName, "Mi Conservatorio Mágico");
    expect(savedPalette!.isCustom, isTrue);
  });
}
