import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-UX-02 Unified Tuner & Pro Acoustic Lab Flow Tests', () {
    late _FakePitchService pitchService;
    late TunerViewModel viewModel;

    setUp(() {
      pitchService = _FakePitchService();
      viewModel = TunerViewModel(
        pitchService: pitchService,
        metronomeService: _FakeMetroService(),
      );
      addTearDown(viewModel.dispose);
    });

    Widget createTestApp() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: TunerScreen(),
        ),
      );
    }

    testWidgets(
      'Persistent tuner bar and mic control remain visible across all Pro sub-views',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(viewModel.isEssentialMode, isFalse);
        expect(
          find.byKey(const Key('pro_persistent_tuner_readout_bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pro_persistent_mic_toggle_btn')),
          findsOneWidget,
        );

        // Cambiar a Componer (WorkspaceType.composition)
        await tester.tap(find.byKey(const Key('workspace_tab_composition')));
        await tester.pump(const Duration(milliseconds: 250));
        expect(viewModel.activeWorkspace, equals(WorkspaceType.composition));
        expect(
          find.byKey(const Key('pro_persistent_tuner_readout_bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pro_persistent_mic_toggle_btn')),
          findsOneWidget,
        );

        // Cambiar a Producir / Lab Acústico (WorkspaceType.production)
        await tester.tap(find.byKey(const Key('workspace_tab_production')));
        await tester.pump(const Duration(milliseconds: 250));
        expect(viewModel.activeWorkspace, equals(WorkspaceType.production));
        expect(
          find.byKey(const Key('pro_persistent_tuner_readout_bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('pro_persistent_mic_toggle_btn')),
          findsOneWidget,
        );

        // Regresar a Aprender (WorkspaceType.learning)
        await tester.tap(find.byKey(const Key('workspace_tab_learning')));
        await tester.pump(const Duration(milliseconds: 250));
        expect(viewModel.activeWorkspace, equals(WorkspaceType.learning));
        expect(
          find.byKey(const Key('pro_persistent_tuner_readout_bar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping persistent mic button activates capture and reflects detected La4 440.0 Hz',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(viewModel.isRecording, isFalse);
        expect(find.text('ACTIVAR MIC'), findsOneWidget);

        await tester.tap(find.byKey(const Key('pro_persistent_mic_toggle_btn')));
        await tester.pump();

        expect(viewModel.isRecording, isTrue);
        expect(find.text('MIC ACTIVO'), findsOneWidget);

        // Simular detección de La4 (440.0 Hz)
        pitchService.onPitchDetected?.call(440.0);
        await tester.pump();

        final noteText = tester.widget<Text>(
          find.byKey(const Key('pro_persistent_note_display')),
        );
        final freqText = tester.widget<Text>(
          find.byKey(const Key('pro_persistent_freq_display')),
        );
        expect(noteText.data, equals('La4'));
        expect(freqText.data, equals('440.0 Hz'));
        expect(
          find.descendant(
            of: find.byKey(const Key('pro_persistent_tuning_status')),
            matching: find.text('AFINADO'),
          ),
          findsOneWidget,
        );

        // Esperar a que culmine el temporizador de silencio (350ms)
        await tester.pump(const Duration(milliseconds: 360));
      },
    );

    testWidgets(
      'Quick focus chips switch to Pro Acoustic Lab and full-screen Essential Strobe',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(viewModel.activeWorkspace, equals(WorkspaceType.learning));
        expect(viewModel.isEssentialMode, isFalse);

        // 1-clic a Lab Acústico Pro
        await tester.tap(find.byKey(const Key('tuner_quick_focus_pro_lab_btn')));
        await tester.pump(const Duration(milliseconds: 250));

        expect(viewModel.activeWorkspace, equals(WorkspaceType.production));
        expect(find.text('CALIBRACIÓN ACÚSTICA DE CÁMARA'), findsOneWidget);
        expect(
          find.byKey(const Key('pro_persistent_tuner_readout_bar')),
          findsOneWidget,
        );

        // 1-clic a Estroboscopio (Modo Esencial a pantalla completa)
        await tester.tap(find.byKey(const Key('tuner_quick_focus_strobe_btn')));
        await tester.pump(const Duration(milliseconds: 250));

        expect(viewModel.isEssentialMode, isTrue);
        expect(viewModel.displayMode, equals(AppDisplayMode.essential));
        expect(find.byKey(const Key('essential_note_display')), findsOneWidget);
        expect(
          find.byKey(const Key('pro_persistent_tuner_readout_bar')),
          findsNothing,
        );
      },
    );
  });
}
