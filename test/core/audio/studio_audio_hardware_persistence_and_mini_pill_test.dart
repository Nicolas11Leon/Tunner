import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/presentation/studio_master_meter_mini_pill_widget.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_audio_persist_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StudioAudioHardwarePersistenceService Tests', () {
    test('returns defaultConfiguration when no file exists', () async {
      final service = StudioAudioHardwarePersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'non_existent_matrix.json',
      );

      final matrix = await service.loadMatrix();
      expect(matrix.bufferSize, 512);
      expect(matrix.masterGain, 1.0);
      expect(matrix.isMuted, isFalse);
    });

    test('persists and reloads AudioDeviceMatrixEntity correctly', () async {
      final service = StudioAudioHardwarePersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'test_matrix.json',
      );

      final modifiedMatrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        bufferSize: 256,
        masterGain: 0.75,
        isMuted: true,
        isDimmed: true,
        isMono: true,
        channelRoutings: {'dj_deck_a': 'cue', 'metronome_click': 'mute'},
      );

      await service.saveMatrix(modifiedMatrix);

      final loadedMatrix = await service.loadMatrix();
      expect(loadedMatrix.bufferSize, 256);
      expect(loadedMatrix.masterGain, 0.75);
      expect(loadedMatrix.isMuted, isTrue);
      expect(loadedMatrix.isDimmed, isTrue);
      expect(loadedMatrix.isMono, isTrue);
      expect(loadedMatrix.channelRoutings['dj_deck_a'], 'cue');
      expect(loadedMatrix.channelRoutings['metronome_click'], 'mute');
    });

    test('clear deletes the persisted file', () async {
      final service = StudioAudioHardwarePersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'clear_matrix.json',
      );

      await service.saveMatrix(AudioDeviceMatrixEntity.defaultConfiguration());
      final file = File('${tempDir.path}/clear_matrix.json');
      expect(await file.exists(), isTrue);

      await service.clear();
      expect(await file.exists(), isFalse);
    });

    test('returns defaultConfiguration when persisted file is corrupted', () async {
      final file = File('${tempDir.path}/corrupt_matrix.json');
      await file.writeAsString('{ invalid_json_syntax: 123 }');

      final service = StudioAudioHardwarePersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'corrupt_matrix.json',
      );

      final loaded = await service.loadMatrix();
      expect(loaded.bufferSize, 512);
      expect(loaded.masterGain, 1.0);
    });
  });

  group('MemoryAudioHardwarePersistenceService Tests', () {
    test('saves and loads in memory without disk IO', () async {
      final memService = MemoryAudioHardwarePersistenceService();
      final matrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(bufferSize: 128);

      await memService.saveMatrix(matrix);
      final loaded = await memService.loadMatrix();
      expect(loaded.bufferSize, 128);

      await memService.clear();
      final reset = await memService.loadMatrix();
      expect(reset.bufferSize, 512);
    });
  });

  group('StudioAudioDeviceMatrixService Persistence Integration', () {
    test('loads saved settings from persistence on initialization', () async {
      final savedMatrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        bufferSize: 1024,
        masterGain: 0.5,
        isMuted: true,
      );
      final persistence = MemoryAudioHardwarePersistenceService(savedMatrix);

      final matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: persistence,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(matrixService.matrix.bufferSize, 1024);
      expect(matrixService.matrix.masterGain, 0.5);
      expect(matrixService.matrix.isMuted, isTrue);

      matrixService.dispose();
    });

    test('updates persistence when matrix properties change', () async {
      final persistence = MemoryAudioHardwarePersistenceService();
      final matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: persistence,
      );

      matrixService.setBufferSize(256);
      expect((await persistence.loadMatrix()).bufferSize, 256);

      matrixService.setMasterGain(0.8);
      expect((await persistence.loadMatrix()).masterGain, 0.8);

      matrixService.toggleMute();
      expect((await persistence.loadMatrix()).isMuted, isTrue);

      matrixService.setChannelRouting('dj_deck_a', 'cue');
      expect((await persistence.loadMatrix()).channelRoutings['dj_deck_a'], 'cue');

      matrixService.dispose();
    });
  });

  group('StudioMasterMeterMiniPillWidget Tests', () {
    late StudioThemeController themeController;
    late StudioAudioDeviceMatrixService matrixService;

    setUp(() {
      themeController = StudioThemeController();
      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        captureService: MemoryStudioMasterCaptureService(),
      );
    });

    tearDown(() {
      matrixService.dispose();
      themeController.dispose();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        home: StudioThemeScope(
          controller: themeController,
          child: Scaffold(
            body: Center(child: child),
          ),
        ),
      );
    }

    testWidgets('renders initial normal state with dB and latency', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          StudioMasterMeterMiniPillWidget(
            matrixService: matrixService,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('master_meter_mini_pill')), findsOneWidget);
      expect(find.text('MTR:'), findsOneWidget);
      expect(find.text('0.0 dB'), findsOneWidget);
      expect(find.textContaining('512 smp'), findsOneWidget);
    });

    testWidgets('renders MUTED state in red when muted', (tester) async {
      matrixService.toggleMute();

      await tester.pumpWidget(
        createTestApp(
          StudioMasterMeterMiniPillWidget(
            matrixService: matrixService,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MUTED'), findsOneWidget);
      expect(find.text('0.0 dB'), findsNothing);
    });

    testWidgets('renders DIM -20dB state when dimmed', (tester) async {
      matrixService.toggleDim();

      await tester.pumpWidget(
        createTestApp(
          StudioMasterMeterMiniPillWidget(
            matrixService: matrixService,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('DIM -20dB'), findsOneWidget);
    });

    testWidgets('renders REC badge when isMasterRecording is active', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          StudioMasterMeterMiniPillWidget(
            matrixService: matrixService,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('REC'), findsNothing);

      await matrixService.startMasterRecording('/tmp/dummy.wav');
      await tester.pump();
      expect(find.text('REC'), findsOneWidget);

      await matrixService.stopMasterRecording();
      await tester.pump();
      expect(find.text('REC'), findsNothing);
    });

    testWidgets('triggers onTap callback when clicked', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          StudioMasterMeterMiniPillWidget(
            matrixService: matrixService,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('master_meter_mini_pill')));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
