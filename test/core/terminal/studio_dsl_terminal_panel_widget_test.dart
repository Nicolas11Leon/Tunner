import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_entity.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_clock_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_engine.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/terminal/presentation/studio_dsl_terminal_panel_widget.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';

void main() {
  group('StudioDslTerminalPanelWidget Tests', () {
    late TunnerOsKernel kernel;
    late StudioAudioDeviceMatrixService matrixService;
    late PolyphonicVoicePool synthVoicePool;
    late StudioMasterClockService clockService;

    setUp(() {
      final initialMatrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        availableInputs: [AudioDeviceEntity.systemDefault()],
        availableOutputs: [AudioDeviceEntity.defaultOutput()],
      );

      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: StudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        initialMatrix: initialMatrix,
      );

      synthVoicePool = PolyphonicVoicePool(
        maxPolyphony: 8,
        defaultWaveform: SynthWaveform.triangle,
      );

      clockService = StudioMasterClockService(initialBpm: 120.0);

      kernel = TunnerOsKernel(
        matrixService: matrixService,
        synthVoicePool: synthVoicePool,
        clockService: clockService,
      );
    });

    tearDown(() {
      clockService.stopTransport();
      matrixService.dispose();
      clockService.dispose();
      kernel.audioKernel?.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 800,
            child: StudioDslTerminalPanelWidget(
              kernel: kernel,
            ),
          ),
        ),
      );
    }

    testWidgets('renders title, templates and action buttons', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('TUNNER DSL STUDIO REPL'), findsOneWidget);
      expect(find.text('Quick Jam'), findsOneWidget);
      expect(find.text('Mastering Chain'), findsOneWidget);
      expect(find.text('Ejecutar (Ctrl+Enter)'), findsOneWidget);
      expect(find.textContaining('[TUNNER STUDIO REPL READY]'), findsOneWidget);
    });

    testWidgets('switching templates updates code in editor', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Pulsar 'Mastering Chain'
      await tester.tap(find.text('Mastering Chain'));
      await tester.pumpAndSettle();

      expect(find.textContaining('set @comp.threshold'), findsOneWidget);

      // Pulsar 'Quick Jam'
      await tester.tap(find.text('Quick Jam'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tempo 128;'), findsOneWidget);
    });

    testWidgets('executing script updates output log and adjusts audio parameters', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Ejecutar Quick Jam que esta precargado
      await tester.tap(find.text('Ejecutar (Ctrl+Enter)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('EVALUACION'), findsOneWidget);
      expect(find.textContaining('[TUNNER DSL EXECUTION REPORT]'), findsOneWidget);
      expect(clockService.bpm, 128.0);

      // Despejar timers de liberacion acustica y detener el reloj
      await tester.pump(const Duration(seconds: 2));
      clockService.stopTransport();
      await tester.pumpAndSettle();
    });

    testWidgets('clearing output removes previous evaluation logs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Limpiar salida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('[CONSOLA LIMPIADA]'), findsOneWidget);
      expect(find.textContaining('[TUNNER STUDIO REPL READY]'), findsNothing);
    });

    testWidgets('executing syntax error displays error diagnosis in red text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Modificar texto con error de sintaxis
      await tester.enterText(find.byType(TextField), 'tempo;');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ejecutar (Ctrl+Enter)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error de sintaxis en script Tunner DSL'), findsOneWidget);
    });
  });
}
