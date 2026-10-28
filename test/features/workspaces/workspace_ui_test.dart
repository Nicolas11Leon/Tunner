import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';

class _FakePitchService implements IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;

  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workspace Hub UI & Mode Switching Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
    });

    Widget createTestApp() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: TunerScreen(),
        ),
      );
    }

    testWidgets('TunerScreen displays WorkspaceSwitchBar with all three tabs', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('workspace_tab_learning')), findsOneWidget);
      expect(find.byKey(const Key('workspace_tab_composition')), findsOneWidget);
      expect(find.byKey(const Key('workspace_tab_production')), findsOneWidget);

      expect(find.text('Aprender'), findsWidgets);
      expect(find.text('Componer'), findsWidgets);
      expect(find.text('Producir'), findsWidgets);
    });

    testWidgets('Tapping Componer switches to CompositionNotationWorkspaceView', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Estado inicial es Learning
      expect(viewModel.activeWorkspace, equals(WorkspaceType.learning));

      // Conmutar a Componer
      await tester.tap(find.byKey(const Key('workspace_tab_composition')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewModel.activeWorkspace, equals(WorkspaceType.composition));
      expect(find.text('Editor de Partituras'), findsOneWidget);
      expect(find.text('Descomponer Audio'), findsOneWidget);
      expect(find.text('Transcripción de Audio en Pentagrama'), findsOneWidget);
    });

    testWidgets('Tapping Producir switches to ProductionAcousticLabWorkspaceView', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Conmutar a Producir
      await tester.tap(find.byKey(const Key('workspace_tab_production')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewModel.activeWorkspace, equals(WorkspaceType.production));
      expect(find.text('CALIBRACIÓN ACÚSTICA DE CÁMARA'), findsOneWidget);
      expect(find.text('Espectrograma Armónico en Cascada'), findsOneWidget);
      expect(find.text('ANALIZADOR POLIFÓNICO DE ACORDES'), findsOneWidget);
      expect(find.text('Comparador Espectral'), findsOneWidget);
    });

    testWidgets('Tapping Aprender returns to LearningPracticeWorkspaceView', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Cambiar a Producir primero
      viewModel.setWorkspace(WorkspaceType.production);
      await tester.pump(const Duration(milliseconds: 300));
      expect(viewModel.activeWorkspace, equals(WorkspaceType.production));

      // Regresar a Aprender
      await tester.tap(find.byKey(const Key('workspace_tab_learning')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewModel.activeWorkspace, equals(WorkspaceType.learning));
      expect(find.byKey(const Key('essential_note_display')), findsOneWidget);
      expect(find.byKey(const Key('essential_mic_toggle_btn')), findsOneWidget);
      expect(find.text('Generar Ejercicios'), findsOneWidget);
      expect(find.text('Informe PDF'), findsOneWidget);
    });
  });
}
