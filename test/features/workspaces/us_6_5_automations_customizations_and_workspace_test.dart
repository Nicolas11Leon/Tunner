import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/navigation/presentation/modals/studio_automations_modal.dart';
import 'package:tunner/features/navigation/presentation/modals/studio_customizations_modal.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/presentation/strobe_tuner_widget.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';
import 'package:tunner/features/workspaces/presentation/learning_practice_workspace_view.dart';

class _FakePitchService extends IPitchDetectorService {
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

class _FakeRecorderService implements IPracticeRecorderService {
  bool isRecordingFlag = false;
  int startCalls = 0;

  @override
  Stream<double> get amplitudeStream => const Stream<double>.empty();

  @override
  bool get isRecording => isRecordingFlag;

  @override
  Future<void> startRecording({required String destinationPath}) async {
    isRecordingFlag = true;
    startCalls++;
  }

  @override
  Future<String?> stopRecording() async {
    isRecordingFlag = false;
    return null;
  }

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-6.5: Automatizaciones, Customización DSP y Persistencia de Workspaces', () {
    testWidgets('StudioAutomationsModal muestra SnackBar correcto (no invertido) al activar y detener Rampa BPM',
        (tester) async {
      final vm = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(initialTokens: StudioDesignTokens.studioDark),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => StudioAutomationsModal.show(context, vm),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Activar Rampa'));
      await tester.pumpAndSettle();

      expect(vm.isBpmRampActive, isTrue);
      expect(
        find.text('Rampa progresiva de metrónomo inicializada (+2 BPM cada 4 compases).'),
        findsOneWidget,
      );

      // Esperar que expire el primer SnackBar y luego detener
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detener Rampa'));
      await tester.pumpAndSettle();

      expect(vm.isBpmRampActive, isFalse);
      expect(find.text('Rampa progresiva de metrónomo detenida.'), findsOneWidget);
    });

    test('Auto-Grabación armada espera umbral RMS y dispara startPracticeRecording', () async {
      final pitchService = _FakePitchService();
      final recorder = _FakeRecorderService();
      final vm = TunerViewModel(
        pitchService: pitchService,
        metronomeService: _FakeMetroService(),
        recorderService: recorder,
      );
      addTearDown(vm.dispose);

      vm.armAutoRecord();
      expect(vm.isAutoRecordArmed, isTrue);
      expect(recorder.startCalls, 0);

      // Ruido ambiental bajo umbral: no debe disparar grabación
      pitchService.onRmsLevelChanged?.call(0.01);
      await Future<void>.delayed(Duration.zero);
      expect(vm.isAutoRecordArmed, isTrue);
      expect(recorder.startCalls, 0);

      // Señal por encima del umbral: debe desarmar e iniciar grabación
      pitchService.onRmsLevelChanged?.call(0.05);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(vm.isAutoRecordArmed, isFalse);
      expect(recorder.startCalls, 1);
    });

    test('Calentamiento guiado configura 5 minutos en círculo de quintas y se detiene limpio', () {
      final vm = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
      addTearDown(vm.dispose);

      vm.startGuidedWarmupRoutine();
      expect(vm.isWarmupActive, isTrue);
      expect(vm.warmupRemainingSeconds, 300);
      expect(vm.warmupStepIndex, 0);
      expect(vm.droneConfig.rootNoteIndex, 0);
      expect(vm.droneConfig.includeFifth, isTrue);

      vm.stopGuidedWarmupRoutine();
      expect(vm.isWarmupActive, isFalse);
      expect(vm.warmupRemainingSeconds, 0);
    });

    testWidgets('StudioCustomizationsModal persiste motor DSP, FPS y precisión en AppUserSettingsEntity',
        (tester) async {
      final persistence = MemoryPersistenceService();
      final vm1 = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
        persistenceService: persistence,
      );
      addTearDown(vm1.dispose);

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(initialTokens: StudioDesignTokens.studioDark),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => StudioCustomizationsModal.show(context, vm1),
                  child: const Text('Config'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Config'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('120 FPS Ultra Fluid'));
      await tester.pump();
      await tester.tap(find.text('Aplicar Cambios'));
      await tester.pumpAndSettle();

      expect(vm1.targetRenderFps, 120);

      final vm2 = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
        persistenceService: persistence,
      );
      addTearDown(vm2.dispose);
      await vm2.loadPersistedState();

      expect(vm2.targetRenderFps, 120);
      expect(vm2.dspEngineName, 'Tartini DSP 2.1');
    });

    testWidgets('WorkspaceConfigurationEntity persiste y controla visibilidad de paneles en LearningPracticeWorkspaceView',
        (tester) async {
      final persistence = MemoryPersistenceService();
      final vm1 = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
        persistenceService: persistence,
      );
      addTearDown(vm1.dispose);

      vm1.updateWorkspaceConfiguration(
        const WorkspaceConfigurationEntity(
          type: WorkspaceType.learning,
          showMetronome: false,
          showStrobeTuner: false,
        ),
      );

      final vm2 = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
        persistenceService: persistence,
      );
      addTearDown(vm2.dispose);
      await vm2.loadPersistedState();

      expect(vm2.workspaceConfiguration.showStrobeTuner, isFalse);
      expect(vm2.workspaceConfiguration.showMetronome, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm2,
          child: MaterialApp(
            home: Scaffold(
              body: LearningPracticeWorkspaceView(
                viewModel: vm2,
                palette: TunnerThemePalette.obsidianStudio,
                onOpenInstrumentModal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(StrobeTunerWidget), findsNothing);
    });
  });
}
