import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_workspace_seed_provider.dart';
import 'package:tunner/core/file_system/data/local_disk_studio_file_system_repository.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/dj_console/data/memory_dj_deck_audio_player.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal High-Performance Interactive Suite Tests', () {
    late MemoryDjDeckAudioPlayer memoryPlayer;
    late MemoryAudioSynthesizerService memorySynthesizer;
    late DjPerformanceOrchestrator orchestrator;
    late DjConsoleViewModel viewModel;

    setUp(() {
      memoryPlayer = MemoryDjDeckAudioPlayer();
      memorySynthesizer = MemoryAudioSynthesizerService();
      orchestrator = DjPerformanceOrchestrator();
      viewModel = DjConsoleViewModel(
        deckAudioPlayer: memoryPlayer,
        audioSynthesizer: memorySynthesizer,
        orchestrator: orchestrator,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('1. LocalDiskFileSystem seeds physical playable WAV files in disk with complete RIFF headers', () async {
      final tempDir = Directory.systemTemp.createTempSync('tunner_seed_test_');
      final repo = LocalDiskStudioFileSystemRepository(
        customRootPath: tempDir.path,
        seedProvider: const StudioWorkspaceSeedProvider(),
      );

      final rootFolder = await repo.loadRootWorkspace();
      expect(rootFolder.children.isNotEmpty, isTrue);

      final audioDir = Directory('${tempDir.path}/Tomas de Audio & WAV');
      expect(await audioDir.exists(), isTrue);

      // Verify A4 Concert Flute WAV
      final a4File = File('${audioDir.path}/Toma_Acustica_440Hz.wav');
      expect(await a4File.exists(), isTrue);
      final a4Bytes = await a4File.readAsBytes();
      // Must be full audio (> 1000 bytes) with RIFF/WAVE header
      expect(a4Bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(a4Bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(a4Bytes.sublist(8, 12)), 'WAVE');

      // Verify Club Groove 124 BPM WAV
      final grooveFile = File('${audioDir.path}/Loop_Club_Groove_124BPM.wav');
      expect(await grooveFile.exists(), isTrue);
      final grooveBytes = await grooveFile.readAsBytes();
      expect(grooveBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(grooveBytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(grooveBytes.sublist(8, 12)), 'WAVE');

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    test('2. Showcase 15s Routine executes multi-subsystem choreography and cancels cleanly', () async {
      expect(viewModel.isShowcaseRunning, isFalse);
      expect(viewModel.showcaseStep, 0);

      // Start showcase
      viewModel.runShowcaseRoutine();
      expect(viewModel.isShowcaseRunning, isTrue);
      expect(viewModel.crossfader.position, -1.0); // Full Deck A
      expect(viewModel.deckA.isPlaying, isTrue);

      // Cancel showcase
      viewModel.cancelShowcaseRoutine();
      expect(viewModel.isShowcaseRunning, isFalse);
      expect(viewModel.showcaseStep, 0);
    });

    testWidgets('3. DjStudioWorkstationView renders Live HUD Bar and Quick Genre selector buttons', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DjStudioWorkstationView(viewModel: viewModel),
          ),
        ),
      );
      await tester.pump();

      // Check Live HUD Bar exists
      expect(find.text('HUD EN VIVO:'), findsOneWidget);
      expect(find.text('Play/Pause A'), findsOneWidget);
      expect(find.text('Play/Pause B'), findsOneWidget);
      expect(find.text('Hot Cues A'), findsOneWidget);
      expect(find.text('Hot Cues B'), findsOneWidget);

      // Check Showcase button exists in header
      expect(find.byKey(const Key('dj_showcase_routine_btn')), findsOneWidget);
      expect(find.text('SHOWCASE DEMO (15S)'), findsOneWidget);

      // Check Quick Genre selector icons exist on both decks
      expect(find.byKey(const Key('quick_genre_selector_A')), findsOneWidget);
      expect(find.byKey(const Key('quick_genre_selector_B')), findsOneWidget);

      // Tap Quick Genre button on Deck A and verify preset choices open
      await tester.tap(find.byKey(const Key('quick_genre_selector_A')));
      await tester.pumpAndSettle();

      expect(find.text('Midnight Cyber Synthwave'), findsOneWidget);
      expect(find.text('Deep Horizon House & Groove'), findsOneWidget);
      expect(find.text('Acoustic Soul & Funk Fusion'), findsOneWidget);

      // Select Synthwave
      await tester.tap(find.text('Midnight Cyber Synthwave'));
      await tester.pumpAndSettle();

      expect(viewModel.deckA.trackTitle, 'Midnight Cyber Synthwave');
      expect(viewModel.deckA.bpm, greaterThan(60.0));
    });
  });
}
