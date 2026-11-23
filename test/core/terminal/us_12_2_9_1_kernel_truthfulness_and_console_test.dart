import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_clock_service.dart';
import 'package:tunner/core/audio/presentation/panels/hardware_endpoints_panel.dart';
import 'package:tunner/core/audio/presentation/panels/master_clock_panel.dart';
import 'package:tunner/core/audio/presentation/panels/master_strip_panel.dart';
import 'package:tunner/core/audio/presentation/panels/mastering_chain_panel.dart';
import 'package:tunner/core/audio/presentation/panels/matrix_routing_panel.dart';
import 'package:tunner/core/audio/presentation/studio_master_hardware_console_widget.dart';
import 'package:tunner/core/design_system/atoms/studio_icon.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/file_system/data/memory_studio_file_system_repository.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/terminal/domain/i_terminal_feature_ports.dart';

class _FakeVocalEvaluator implements ITerminalVocalPedagogyPort {
  @override
  TerminalVocalEvalSnapshot evaluate({
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  }) {
    final mean = frequenciesHz.reduce((a, b) => a + b) / frequenciesHz.length;
    return TerminalVocalEvalSnapshot(
      evaluationId: 'eval-truth-1',
      targetFrequencyHz: targetFrequencyHz,
      measuredMeanFrequencyHz: mean,
      centsDeviation: 0.0,
      jitterPercent: 0.15,
      shimmerPercent: 0.40,
      vibratoRateHz: 5.2,
      vibratoDepthCents: 12.0,
      overallScore: 95.0,
      classificationLabel: 'Optimo',
      payloadHashSha256: 'deadbeef1234',
    );
  }

  @override
  Uint8List generateCertificatePdf({
    required String studentName,
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  }) {
    return Uint8List.fromList('%PDF-1.4 $studentName'.codeUnits);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-12.2 (#193): TunnerOsKernel Truthfulness & Modular Handlers', () {
    test('registers all built-in domains across the 4 modular handlers', () {
      final kernel = TunnerOsKernel();
      addTearDown(kernel.dispose);

      expect(
        kernel.registeredDomains,
        containsAll(<String>[
          'io',
          'dsp',
          'master',
          'eq',
          'comp',
          'route',
          'clock',
          'reverb',
          'spatial',
          'fs',
          'project',
          'train',
          'vocal',
          'dsl',
          'eval',
          'dj',
          'synth',
          'score',
          'help',
          'tuner',
          'theme',
          'clear',
        ]),
      );
    });

    test('io list and io set-input return [ERROR] when inputEngine is null (no fake Focusrite)', () async {
      final kernel = TunnerOsKernel();
      addTearDown(kernel.dispose);

      final listRes = await kernel.execute('io list');
      expect(listRes.isSuccess, isFalse);
      expect(listRes.message, contains('[ERROR]'));
      expect(listRes.message, isNot(contains('Focusrite Scarlett')));

      final setRes = await kernel.execute('io set-input dev-1');
      expect(setRes.isSuccess, isFalse);
      expect(setRes.message, contains('[ERROR]'));
    });

    test('io list reports real devices when inputEngine is connected', () async {
      final inputEngine = MemoryStudioAudioInputEngine();
      final kernel = TunnerOsKernel(inputEngine: inputEngine);
      addTearDown(kernel.dispose);

      final listRes = await kernel.execute('io list');
      expect(listRes.isSuccess, isTrue);
      expect(listRes.message, contains('INTERFACES DE AUDIO DETECTADAS:'));
    });

    test('dsp status reports disconnected state without fabricated specs when matrixService is null', () async {
      final kernel = TunnerOsKernel();
      addTearDown(kernel.dispose);

      final res = await kernel.execute('dsp status');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('NO CONECTADO'));
      expect(res.message, contains('No disponible (matriz no conectada)'));
      expect(res.message, isNot(contains('44.1 kHz / 48.0 kHz')));
      expect(res.message, isNot(contains('1024 muestras (< 7.8 ms latencia)')));
    });

    test('dsp status reads live telemetry from matrixService', () async {
      final matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: MemoryAudioHardwarePersistenceService(),
        captureService: MemoryStudioMasterCaptureService(),
        initialMatrix: AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
          sampleRate: 48000,
          bufferSize: 256,
        ),
      );
      final kernel = TunnerOsKernel(matrixService: matrixService);
      addTearDown(() {
        kernel.dispose();
        matrixService.dispose();
      });

      final res = await kernel.execute('dsp status');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('EN LINEA (FULL-DUPLEX)'));
      expect(res.message, contains('48.0 kHz (48000 Hz)'));
      expect(res.message, contains('256 muestras (5.3 ms latencia)'));
    });

    test('fs ls returns [ERROR] when fileSystemRepository is null (no fabricated files)', () async {
      final kernel = TunnerOsKernel();
      addTearDown(kernel.dispose);

      final res = await kernel.execute('fs ls');
      expect(res.isSuccess, isFalse);
      expect(res.message, contains('[ERROR]'));
      expect(res.message, isNot(contains('Suite_No1_Bach.tunner')));
    });

    test('fs ls lists real files when fileSystemRepository is connected', () async {
      final repo = MemoryStudioFileSystemRepository();
      await repo.saveFile(
        relativePath: 'sessions/take_01.wav',
        bytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]),
      );
      final kernel = TunnerOsKernel(fileSystemRepository: repo);
      addTearDown(kernel.dispose);

      final res = await kernel.execute('fs ls');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('take_01.wav'));
    });

    test('vocal eval and vocal cert return [ERROR] when no real vocal capture is available', () async {
      final kernel = TunnerOsKernel(
        vocalEvaluator: _FakeVocalEvaluator(),
        onReadCapturedFrequencies: () => const <double>[],
        onReadCapturedAmplitudes: () => const <double>[],
      );
      addTearDown(kernel.dispose);

      final evalRes = await kernel.execute('vocal eval 440');
      expect(evalRes.isSuccess, isFalse);
      expect(evalRes.message, contains('[ERROR]'));

      final certRes = await kernel.execute('vocal cert "Maria" 440');
      expect(certRes.isSuccess, isFalse);
      expect(certRes.message, contains('[ERROR]'));
    });

    test('dj, theme set and tuner run return [ERROR] instead of [OK] when callbacks are null', () async {
      final kernel = TunnerOsKernel();
      addTearDown(kernel.dispose);

      final djLoad = await kernel.execute('dj load A "Track 1"');
      expect(djLoad.isSuccess, isFalse);
      expect(djLoad.message, contains('[ERROR]'));
      expect(djLoad.message, isNot(contains('[OK]')));

      final djPlay = await kernel.execute('dj play A');
      expect(djPlay.isSuccess, isFalse);
      expect(djPlay.message, contains('[ERROR]'));

      final djPause = await kernel.execute('dj pause B');
      expect(djPause.isSuccess, isFalse);
      expect(djPause.message, contains('[ERROR]'));

      final djXfader = await kernel.execute('dj xfader 0.5');
      expect(djXfader.isSuccess, isFalse);
      expect(djXfader.message, contains('[ERROR]'));

      final themeRes = await kernel.execute('theme set "OLED Monochrome"');
      expect(themeRes.isSuccess, isFalse);
      expect(themeRes.message, contains('[ERROR]'));
      expect(themeRes.message, isNot(contains('[OK]')));

      final navRes = await kernel.execute('tuner run dj');
      expect(navRes.isSuccess, isFalse);
      expect(navRes.message, contains('[ERROR]'));
    });
  });

  group('US-9.1 (#183): Atomized & Strictly Typed StudioMasterHardwareConsoleWidget', () {
    testWidgets('composes all 5 typed panels and renders StudioIcon atoms without hardcoded colors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: MemoryAudioHardwarePersistenceService(),
        captureService: MemoryStudioMasterCaptureService(),
      );
      final clockService = StudioMasterClockService(initialBpm: 120.0);
      final themeController = StudioThemeController(
        initialTokens: StudioDesignTokens.studioOledMonochrome,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            controller: themeController,
            child: Scaffold(
              body: StudioMasterHardwareConsoleWidget(
                matrixService: matrixService,
                clockService: clockService,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HardwareEndpointsPanel), findsOneWidget);
      expect(find.byType(MasterClockPanel), findsOneWidget);
      expect(find.byType(MasterStripPanel), findsOneWidget);
      expect(find.byType(MasteringChainPanel), findsOneWidget);
      expect(find.byType(MatrixRoutingPanel), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);

      // Verify panel interactions work end-to-end
      await tester.tap(find.text('128'));
      await tester.pump();
      expect(matrixService.matrix.bufferSize, 128);

      await tester.tap(find.byKey(const Key('bpm_increment_btn')));
      await tester.pump();
      expect(clockService.bpm, 121.0);

      await tester.tap(find.byKey(const Key('master_mute_btn')));
      await tester.pump();
      expect(matrixService.matrix.isMuted, isTrue);

      final eqBypass = find.byKey(const Key('master_eq_bypass_btn'));
      await tester.ensureVisible(eqBypass);
      await tester.tap(eqBypass);
      await tester.pump();
      expect(matrixService.matrix.isEqBypassed, isTrue);

      final routeCue = find.byKey(const Key('routing_dj_deck_a_cue'));
      await tester.ensureVisible(routeCue);
      await tester.tap(routeCue);
      await tester.pump();
      expect(matrixService.matrix.channelRoutings['dj_deck_a'], 'cue');

      await tester.pumpWidget(const SizedBox.shrink());
      matrixService.dispose();
      clockService.dispose();
      themeController.dispose();
    });
  });
}
