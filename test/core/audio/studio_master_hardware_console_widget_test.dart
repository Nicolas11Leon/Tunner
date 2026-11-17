import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/studio_master_clock_service.dart';
import 'package:tunner/core/audio/domain/studio_transport_status.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/presentation/studio_master_hardware_console_widget.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioMasterHardwareConsoleWidget Widget Tests (UC-102 & UC-103)', () {
    late MemoryStudioAudioEngine outEngine;
    late MemoryStudioAudioInputEngine inEngine;
    late StudioAudioDeviceMatrixService matrixService;
    late StudioMasterClockService clockService;
    late StudioThemeController themeController;

    setUp(() {
      outEngine = MemoryStudioAudioEngine();
      inEngine = MemoryStudioAudioInputEngine();
      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: outEngine,
        inputEngine: inEngine,
      );
      clockService = StudioMasterClockService(initialBpm: 120.0);
      themeController = StudioThemeController();
    });

    tearDown(() {
      matrixService.dispose();
      clockService.dispose();
      themeController.dispose();
    });

    Widget createTestApp() {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: StudioThemeScope(
          controller: themeController,
          child: Scaffold(
            body: StudioMasterHardwareConsoleWidget(
              matrixService: matrixService,
              clockService: clockService,
            ),
          ),
        ),
      );
    }

    testWidgets('renders all console sections, headers and DSP badge', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('CONSOLA MAESTRA DE E/S & RELOJ GLOBAL'), findsOneWidget);
      expect(find.text('Tartini DSP 2.1'), findsOneWidget);
      expect(find.text('TRANSDUCTORES FÍSICOS DE HARDWARE'), findsOneWidget);
      expect(find.text('RELOJ MAESTRO DE TRANSPORTE'), findsOneWidget);
      expect(find.text('VÚMETRO MASTER'), findsOneWidget);
      expect(find.text('GANANCIA MAESTRA (MASTER GAIN):'), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('STOP ALL'), findsOneWidget);
    });

    testWidgets('taps buffer size chips and updates matrix buffer size', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(matrixService.matrix.bufferSize, 512);

      // Tap 256 sample buffer
      final chip256 = find.text('256');
      expect(chip256, findsOneWidget);
      await tester.tap(chip256);
      await tester.pump();

      expect(matrixService.matrix.bufferSize, 256);

      // Tap 128 sample buffer
      final chip128 = find.text('128');
      expect(chip128, findsOneWidget);
      await tester.tap(chip128);
      await tester.pump();

      expect(matrixService.matrix.bufferSize, 128);
    });

    testWidgets('toggles transport PLAY ALL and STOP ALL', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(clockService.status, StudioTransportStatus.stopped);

      // Tap PLAY ALL
      await tester.tap(find.text('PLAY ALL'));
      await tester.pump();

      expect(clockService.status, StudioTransportStatus.playing);
      expect(find.text('PAUSE ALL'), findsOneWidget);

      // Tap STOP ALL
      await tester.tap(find.text('STOP ALL'));
      await tester.pump();

      expect(clockService.status, StudioTransportStatus.stopped);
      expect(find.text('PLAY ALL'), findsOneWidget);
    });

    testWidgets('increments and decrements BPM via transport buttons', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(clockService.bpm, 120.0);

      // Tap Arrow Drop Up
      await tester.tap(find.byKey(const Key('bpm_increment_btn')));
      await tester.pump();

      expect(clockService.bpm, 121.0);

      // Tap Arrow Drop Down
      await tester.tap(find.byKey(const Key('bpm_decrement_btn')));
      await tester.pump();

      expect(clockService.bpm, 120.0);
    });

    testWidgets('toggles MUTE, DIM, and MONO buttons', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(matrixService.matrix.isMuted, isFalse);
      expect(matrixService.matrix.isDimmed, isFalse);
      expect(matrixService.matrix.isMono, isFalse);

      // Tap MUTE
      await tester.tap(find.byKey(const Key('master_mute_btn')));
      await tester.pump();
      expect(matrixService.matrix.isMuted, isTrue);

      // Tap DIM (-20dB)
      await tester.tap(find.byKey(const Key('master_dim_btn')));
      await tester.pump();
      expect(matrixService.matrix.isDimmed, isTrue);

      // Tap MONO
      await tester.tap(find.byKey(const Key('master_mono_btn')));
      await tester.pump();
      expect(matrixService.matrix.isMono, isTrue);
    });

    testWidgets('taps patchbay routing chips and updates matrix channel routing', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('MATRIZ UNIVERSAL DE ENRUTAMIENTO DE BUSES (PATCHBAY)'), findsOneWidget);
      expect(matrixService.matrix.channelRoutings['dj_deck_b'], 'master');

      // Route DJ Deck B to CUE
      final cueBtn = find.byKey(const Key('routing_dj_deck_b_cue'));
      expect(cueBtn, findsOneWidget);
      await tester.ensureVisible(cueBtn);
      await tester.tap(cueBtn);
      await tester.pump();

      expect(matrixService.matrix.channelRoutings['dj_deck_b'], 'cue');

      // Mute Metronome
      final muteMetroBtn = find.byKey(const Key('routing_metronome_click_mute'));
      expect(muteMetroBtn, findsOneWidget);
      await tester.ensureVisible(muteMetroBtn);
      await tester.tap(muteMetroBtn);
      await tester.pump();

      expect(matrixService.matrix.channelRoutings['metronome_click'], 'mute');
    });

    testWidgets('modal show launches dialog successfully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StudioThemeScope(
            controller: themeController,
            child: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => StudioMasterHardwareConsoleWidget.show(
                    ctx,
                    matrixService: matrixService,
                    clockService: clockService,
                  ),
                  child: const Text('OPEN_CONSOLE'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_CONSOLE'));
      await tester.pumpAndSettle();

      expect(find.text('CONSOLA MAESTRA DE E/S & RELOJ GLOBAL'), findsOneWidget);
    });
  });
}
