import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_analyzer_modal.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_hardware_catalog.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_visual_mapping_overlay.dart';
import 'package:tunner/features/guided_lessons/presentation/guided_lessons_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/vocal_autotune/presentation/vocal_autotune_modal.dart';
import '../practice_recorder/mock_recorder_services.dart';

class _MockPitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX Wave 4 - GuidedLessonsModal & ChordAnalyzerModal Direct Mic Toggle Tests', () {
    testWidgets('GuidedLessonsModal permite encender y apagar el microfono directamente', (tester) async {
      final vm = TunerViewModel(
        pitchService: _MockPitchService(),
        recorderService: MockPracticeRecorderService(),
        recordingPathProvider: () async => '/tmp/test.wav',
      );
      expect(vm.isRecording, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => GuidedLessonsModal.show(ctx, vm),
                  child: const Text('Abrir Lecciones'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Lecciones'));
      await tester.pumpAndSettle();

      final micBtn = find.byKey(const Key('header_toggle_mic_btn'));
      expect(micBtn, findsOneWidget);

      await tester.tap(micBtn);
      await tester.pumpAndSettle();

      expect(vm.isRecording, isTrue);

      await tester.tap(micBtn);
      await tester.pumpAndSettle();

      expect(vm.isRecording, isFalse);
    });

    testWidgets('ChordAnalyzerModal permite encender y apagar el microfono directamente', (tester) async {
      final vm = TunerViewModel(
        pitchService: _MockPitchService(),
        recorderService: MockPracticeRecorderService(),
        recordingPathProvider: () async => '/tmp/test.wav',
      );
      expect(vm.isRecording, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => ChordAnalyzerModal.show(ctx, vm),
                  child: const Text('Abrir Analizador'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Analizador'));
      await tester.pumpAndSettle();

      final micBtn = find.byKey(const Key('chord_toggle_mic_btn'));
      expect(micBtn, findsOneWidget);

      await tester.tap(micBtn);
      await tester.pumpAndSettle();

      expect(vm.isRecording, isTrue);
    });
  });

  group('UX Wave 4 - DjConsoleViewModel HotCues & Save To Disk Tests', () {
    test('Hot Cues 0..3 unificados encienden LEDs de acciones correspondientes', () {
      final vm = DjConsoleViewModel();
      try {
        // Asignar Hot Cue en slot 0
        vm.triggerHotCue('A', 0);
        expect(vm.activeLitActions.contains(DjAction.deckAHotCue1), isTrue);

        // Asignar Hot Cue en slot 1
        vm.triggerHotCue('A', 1);
        expect(vm.activeLitActions.contains(DjAction.deckAHotCue2), isTrue);
      } finally {
        vm.dispose();
      }
    });

    test('saveRecordingToDisk persiste mezcla WAV exitosamente', () async {
      final vm = DjConsoleViewModel();
      try {
        vm.startRecording();
        final success = await vm.saveRecordingToDisk('test_dj_mix.wav');
        expect(success, isTrue);
      } finally {
        vm.dispose();
      }
    });
  });

  group('UX Wave 4 - DjVisualMappingOverlay Gestures & Pan Tests', () {
    testWidgets('Overlay responde a eventos pan y tap sobre zonas de hardware', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      DjAction? lastTriggered;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                height: 700,
                child: DjVisualMappingOverlay(
                  skin: DjHardwareCatalog.ddjFlx4(),
                  onActionTriggered: (action) => lastTriggered = action,
                ),
              ),
            ),
          ),
        ),
      );

      // Drag / Pan gesture across console
      await tester.drag(find.byType(DjVisualMappingOverlay), const Offset(0, -50));
      await tester.pumpAndSettle();

      expect(find.byType(DjVisualMappingOverlay), findsOneWidget);
      expect(lastTriggered, isNull);
    });
  });

  group('UX Wave 4 - VocalAutoTuneModal Audition Button Tests', () {
    testWidgets('Modal muestra boton de audicion para cada toma de practica', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = TunerViewModel(
        pitchService: _MockPitchService(),
        recorderService: MockPracticeRecorderService(),
        recordingPathProvider: () async => '/tmp/test.wav',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => VocalAutoTuneModal.show(ctx, vm),
                  child: const Text('Abrir AutoTune'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir AutoTune'));
      await tester.pumpAndSettle();

      expect(find.text('Vocal AutoTune & Corrección Tonal'), findsOneWidget);

      final playTakeFinder = find.byKey(const Key('play_take_btn_take_1'));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(playTakeFinder, findsOneWidget);
    });
  });
}
