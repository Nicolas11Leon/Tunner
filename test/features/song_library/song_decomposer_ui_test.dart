import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/song_library/presentation/song_decomposer_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

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

  testWidgets('SongDecomposerModal renders form fields, quick note keypad and preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongDecomposerModal(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Estudio de Descomposición"), findsOneWidget);
    expect(find.text("Editor"), findsOneWidget);
    expect(find.text("Plantillas"), findsOneWidget);
    expect(find.text("Importar (.xml / .mid)"), findsOneWidget);

    // Keypad notes
    expect(find.text("Do"), findsOneWidget);
    expect(find.text("Re"), findsOneWidget);
    expect(find.text("Mi"), findsOneWidget);
    expect(find.text("Silencio"), findsOneWidget);
    expect(find.text("| Compás"), findsOneWidget);

    // Stats
    expect(find.text("Compases"), findsOneWidget);
    expect(find.text("Notas Melódicas"), findsOneWidget);
  });

  testWidgets('SongDecomposerModal appends notes on keypad button taps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongDecomposerModal(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap note Do
    final doButton = find.widgetWithText(ElevatedButton, "Do");
    await tester.ensureVisible(doButton);
    await tester.tap(doButton);
    await tester.pumpAndSettle();

    // Verify it was appended to the text
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('SongDecomposerModal switches to templates tab and allows loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongDecomposerModal(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Plantillas tab
    await tester.tap(find.text("Plantillas"));
    await tester.pumpAndSettle();

    expect(find.textContaining("Estrellita"), findsOneWidget);
    expect(find.textContaining("Bach"), findsOneWidget);

    // Tap first Cargar button
    final cargarButtons = find.text("Cargar");
    expect(cargarButtons, findsWidgets);
    await tester.tap(cargarButtons.first);
    await tester.pumpAndSettle();

    // Should switch back to Editor tab with loaded title
    expect(find.text("Estrellita, ¿Dónde Estás?"), findsOneWidget);
  });

  testWidgets('SongDecomposerModal executes decomposition and adds song to library', (tester) async {
    final initialCount = viewModel.curatedLibrary.length;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongDecomposerModal(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap decompose button
    final decomposeBtn = find.textContaining("Descomponer y Cargar al Estudio");
    expect(decomposeBtn, findsOneWidget);

    await tester.tap(decomposeBtn);
    await tester.pumpAndSettle();

    // Verify song was added and active package updated
    expect(viewModel.curatedLibrary.length, initialCount + 1);
    expect(viewModel.activePackage.title, contains("Mi Composición"));
  });
}
