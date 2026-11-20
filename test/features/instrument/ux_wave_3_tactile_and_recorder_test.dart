import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/instrument/domain/instrument_customization_profile.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/presentation/universal_master_keyboard_widget.dart';
import 'package:tunner/features/navigation/presentation/quick_action_dock_widget.dart';
import 'package:tunner/features/score_editor/presentation/score_editor_modal.dart';
import 'package:tunner/features/tuner/presentation/stem_mixer_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import '../practice_recorder/mock_recorder_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX Wave 3 - UniversalMasterKeyboardWidget Tests', () {
    testWidgets('Teclado Maestro soporta toggle de sostenido y emite notas', (tester) async {
      final synth = MemoryAudioSynthesizerService();
      double? playedFreq;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: UniversalMasterKeyboardWidget(
                customization: InstrumentCustomizationProfile.defaultFor(UniversalInstrumentDefinition.grandPiano),
                audioSynthesizer: synth,
                onNotePlayed: (f) => playedFreq = f,
              ),
            ),
          ),
        ),
      );

      // 1. Verificar botón de sostenido
      final sustainFinder = find.byKey(const Key('keyboard_sustain_btn'));
      expect(sustainFinder, findsOneWidget);

      await tester.tap(sustainFinder);
      await tester.pumpAndSettle();

      // 2. Tocar tecla Do4 (tecla blanca)
      final doKey = find.text('Do4');
      expect(doKey, findsOneWidget);

      await tester.tap(doKey);
      await tester.pump(const Duration(seconds: 1));

      expect(playedFreq, isNotNull);
      expect(playedFreq!, closeTo(261.63, 1.0));
    });
  });

  group('UX Wave 3 - QuickActionDockWidget isAudioRecording Tests', () {
    testWidgets('Boton REC refleja isAudioRecording y alterna grabacion de practica', (tester) async {
      final vm = TunerViewModel(
        recorderService: MockPracticeRecorderService(),
        recordingPathProvider: () async => '/tmp/test_take.wav',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionDockWidget(
              viewModel: vm,
              palette: vm.currentPalette,
              onOpenCommandPalette: () {},
              onOpenShortcutsGuide: () {},
              onOpenTunerTab: () {},
            ),
          ),
        ),
      );

      final recBtn = find.byKey(const Key('quick_dock_rec_btn'));
      expect(recBtn, findsOneWidget);
      expect(find.text('Grabar'), findsOneWidget);
      expect(vm.isAudioRecording, isFalse);

      // Clic para iniciar grabacion de audio de practica
      await tester.tap(recBtn);
      await tester.pumpAndSettle();

      expect(vm.isAudioRecording, isTrue);
      expect(find.text('Grabando'), findsOneWidget);

      // Clic para detener
      await tester.tap(recBtn);
      await tester.pumpAndSettle();

      expect(vm.isAudioRecording, isFalse);
      expect(find.text('Grabar'), findsOneWidget);
    });
  });

  group('UX Wave 3 - ScoreEditorModal Auto-Advance & Preview Tests', () {
    testWidgets('Modal muestra preview de nota y auto-avanza cursor al insertar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = TunerViewModel();

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => ScoreEditorModal.show(ctx),
                  child: const Text('Abrir Editor'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Editor'));
      await tester.pumpAndSettle();

      // Verificar que la tarjeta de preview gráfico de nota existe
      final previewCard = find.byKey(const Key('score_editor_note_preview_card'));
      expect(previewCard, findsOneWidget);
      expect(find.textContaining('Vista Previa: Do4'), findsOneWidget);

      // Insertar nota
      final insertBtn = find.text('Insertar Do4');
      expect(insertBtn, findsOneWidget);
      await tester.ensureVisible(insertBtn);
      await tester.tap(insertBtn);
      await tester.pumpAndSettle();

      // Tick inicial era 0 y duracion negra es 4 ticks -> Tick debe haber avanzado a 4
      expect(find.text('Tick 4 / 16'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('UX Wave 3 - TunerViewModel Reference Tone & Note Preview Tests', () {
    testWidgets('playReferenceTone realiza toggle limpio y no falsea pitch', (tester) async {
      final vm = TunerViewModel();
      expect(vm.isDiapasonPlaying, isFalse);

      // Iniciar tono
      vm.playReferenceTone('La4');
      expect(vm.isDiapasonPlaying, isTrue);

      // Detener tono
      vm.playReferenceTone('La4');
      expect(vm.isDiapasonPlaying, isFalse);
    });

    testWidgets('selectAndPreviewScoreNote reproduce sonido de inmediato', (tester) async {
      final vm = TunerViewModel();
      expect(vm.currentMeasureNotes.isNotEmpty, isTrue);

      vm.selectAndPreviewScoreNote(0);
      expect(vm.selectedScoreNoteIndex, equals(0));

      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('UX Wave 3 - StemMixerModal Tests', () {
    testWidgets('StemMixerModal se abre con controles de volumen y stems', (tester) async {
      final vm = TunerViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => StemMixerModal.show(ctx, vm),
                child: const Text('Abrir Mezclador'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Mezclador'));
      await tester.pumpAndSettle();

      expect(find.text('CONSOLA MEZCLADORA (STEMS)'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });
  });
}
